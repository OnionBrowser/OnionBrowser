//
//  PacketTunnelProvider.swift
//  TorVPN
//
//  Created by Benjamin Erhart on 28.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

	private enum Errors: Error {
		case cookieUnreadable
	}

	private static let ENABLE_LOGGING = true
	private static var messageQueue = [Message]()

	private static let torProxyPort: Int32 = 39050
	private static let torControlPort: UInt16 = 39060
	private static let localhost = "127.0.0.1"

	private var hostHandler: ((Data?) -> Void)?

	private let queue = DispatchQueue(label: "\(String(describing: Bundle.main.bundleIdentifier)).queue")

	private var torThread: TorThread?

	private lazy var torConf: TorConfiguration = {
		let conf = TorConfiguration()

		let dataDirectory = FileManager.default.groupFolder?.appendingPathComponent("tor")

		if let dataDirectory = dataDirectory {
			// Need to clean out, so data doesn't grow too big. Otherwise
			// we get killed by Jetsam because Tor will use too much memory.
			try? FileManager.default.removeItem(at: dataDirectory)
		}

		conf.options = ["DNSPort": "\(PacketTunnelProvider.localhost):53",
						"AutomapHostsOnResolve": "1",
						"ClientOnly": "1",
						"HTTPTunnelPort": "\(PacketTunnelProvider.localhost):\(PacketTunnelProvider.torProxyPort)",
//						"SocksPort": "\(PacketTunnelProvider.torProxyPort)",
						"ControlPort": "\(PacketTunnelProvider.localhost):\(PacketTunnelProvider.torControlPort)",
						"AvoidDiskWrites": "1",
						"MaxMemInQueues": "5MB" /* For reference, no impact seen so far */]

		conf.cookieAuthentication = true
		conf.dataDirectory = dataDirectory

		conf.arguments = [
			"--allow-missing-torrc",
			"--ignore-missing-torrc",
		]

		return conf
	}()

	private var torController: TorController?

	private lazy var controllerQueue = DispatchQueue.global(qos: .userInitiated)

	private var torRunning: Bool {
		self.log("#torRunning 0")

		guard torThread?.isExecuting ?? false else {
			self.log("#torRunning 1")

			return false
		}

		self.log("#torRunning 2")

		if let lock = torConf.dataDirectory?.appendingPathComponent("lock") {
			self.log("#torRunning 3")

			return FileManager.default.fileExists(atPath: lock.path)
		}

		self.log("#torRunning 4")

		return false
	}

	private var cookie: Data? {
		if let cookieUrl = torConf.dataDirectory?.appendingPathComponent("control_auth_cookie") {
			return try? Data(contentsOf: cookieUrl)
		}

		return nil
	}

	override init() {
		super.init()

		NSKeyedUnarchiver.setClass(CloseCircuitsMessage.self, forClassName:
			"OnionBrowser.\(String(describing: CloseCircuitsMessage.self))")

		NSKeyedUnarchiver.setClass(GetCircuitsMessage.self, forClassName:
			"OnionBrowser.\(String(describing: GetCircuitsMessage.self))")
	}


	override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
		log("#startTunnel")

		let ipv4 = NEIPv4Settings(addresses: ["192.0.2.4"], subnetMasks: ["255.255.255.0"])
		ipv4.includedRoutes = [NEIPv4Route.default()]

		let server = NEProxyServer(address: PacketTunnelProvider.localhost, port: Int(PacketTunnelProvider.torProxyPort))
		let proxy = NEProxySettings()
		proxy.autoProxyConfigurationEnabled = false
		proxy.httpEnabled = true
		proxy.httpServer = server
		proxy.httpsEnabled = true
		proxy.httpsServer = server
		proxy.excludeSimpleHostnames = false
		proxy.matchDomains = [""]

		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: PacketTunnelProvider.localhost)
		settings.ipv4Settings = ipv4
		settings.dnsSettings = NEDNSSettings(servers: [PacketTunnelProvider.localhost])
		settings.dnsSettings?.matchDomains = [""]
		settings.proxySettings = proxy

		log("#startTunnel before setTunnelNetworkSettings")

		setTunnelNetworkSettings(settings) { error in
			self.log("#startTunnel in setTunnelNetworkSettings callback")

			if let error = error {
				self.log("#startTunnel error=\(error)")
				return completionHandler(error)
			}

			self.log("#startTunnel before start Tor thread")

			if !self.torRunning {
				self.log("#startTunnel configure Tor thread")

				self.torThread = TorThread(configuration: self.torConf)

				self.log("#startTunnel start Tor thread")
				self.torThread?.start()
			}

			self.log("#startTunnel before dispatch")

			self.controllerQueue.asyncAfter(deadline: .now() + 0.75) {
				self.log("#startTunnel try to connect to Tor thread=\(String(describing: self.torThread))")

// Use this with a recent Tor.framework to tunnel logs from Tor to the app.
//				if PacketTunnelProvider.ENABLE_LOGGING {
//					TORInstallTorLoggingCallback { (type: OSLogType, message: UnsafePointer<Int8>) in
//						if type == .default || type == .error || type == .fault {
//							PacketTunnelProvider.log(String(cString: message))
//						}
//					}
//				}

				if self.torController == nil {
					self.torController = TorController(
						socketHost: PacketTunnelProvider.localhost,
						port: PacketTunnelProvider.torControlPort)
				}

				if !(self.torController?.isConnected ?? false) {
					do {
						try self.torController?.connect()
					}
					catch let error {
						self.log("#startTunnel error=\(error)")

						return completionHandler(error)
					}
				}

				guard let cookie = self.cookie else {
					self.log("#startTunnel cookie unreadable")

					return completionHandler(Errors.cookieUnreadable)
				}

				self.torController?.authenticate(with: cookie) { success, error in
					if let error = error {
						self.log("#startTunnel error=\(error)")

						return completionHandler(error)
					}

					var progressObs: Any?
					progressObs = self.torController?.addObserver(forStatusEvents: {
						(type, severity, action, arguments) -> Bool in

						if type == "STATUS_CLIENT" && action == "BOOTSTRAP" {
							let progress = Int(arguments!["PROGRESS"]!)!
							self.log("#startTunnel progress=\(progress)")

							PacketTunnelProvider.messageQueue.append(ProgressMessage(Float(progress) / 100))
							self.sendMessages()

							if progress >= 100 {
								self.torController?.removeObserver(progressObs)
							}

							return true
						}

						return false
					})

					var observer: Any?
					observer = self.torController?.addObserver(forCircuitEstablished: { established in
						guard established else {
							return
						}

						self.torController?.removeObserver(observer)

//						TunnelInterface.setup(with: self.packetFlow)
//						TunnelInterface.startTun2Socks(PacketTunnelProvider.torProxyPort,
//													   withUsername: "onionbrowser",
//													   andPassword: "onionbrowser");
//
//						DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//							TunnelInterface.processPackets()
//						}

						self.log("#startTunnel successful")

						completionHandler(nil)
					})
				}
			}
		}
	}

	override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
//		TunnelInterface.stop()

		torController?.disconnect()
		torController = nil

		torThread?.cancel()
		torThread = nil

		completionHandler()
	}

	override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		let request = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(messageData)

		log("#handleAppMessage messageData=\(messageData), request=\(String(describing: request))")

		if request is GetCircuitsMessage {
			torController?.getCircuits { circuits in
				let response = try? NSKeyedArchiver.archivedData(
					withRootObject: circuits, requiringSecureCoding: true)

				completionHandler?(response)
			}

			return
		}

		if let request = request as? CloseCircuitsMessage {
			torController?.close(request.circuits) { success in
				let response = try? NSKeyedArchiver.archivedData(
					withRootObject: success, requiringSecureCoding: true)

				completionHandler?(response)
			}

			return
		}

		// Wait for progress updates.
		hostHandler = completionHandler
	}


	// MARK: Private Methods

	@objc private func sendMessages() {
		DispatchQueue.main.async {
			if let handler = self.hostHandler {
				let response = try? NSKeyedArchiver.archivedData(
					withRootObject: PacketTunnelProvider.messageQueue,
					requiringSecureCoding: true)

				PacketTunnelProvider.messageQueue.removeAll()

				handler(response)

				self.hostHandler = nil
			}
		}
	}

	private func log(_ message: String) {
		PacketTunnelProvider.log(message)
	}

	private static var logfile: URL? = {
		let fm = FileManager.default

		if let url = fm.logfile {

			if fm.fileExists(atPath: url.path) {
				try? fm.removeItem(at: url)
			}

			fm.createFile(atPath: url.path, contents: nil)

			return url
		}

		return nil
	}()

	private static func log(_ message: String) {
		if ENABLE_LOGGING {
			let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)

			NSLog(msg)

			if let data = "\(msg)\n".data(using: .utf8),
				let url = logfile,
				let fh = try? FileHandle(forUpdating: url) {

				fh.seekToEndOfFile()
				fh.write(data)
				fh.closeFile()
			}
		}
	}
}
