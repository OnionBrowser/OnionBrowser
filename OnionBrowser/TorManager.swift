//
//  TorManager.swift
//  Orbot
//
//  Created by Benjamin Erhart on 17.05.21.
//  Copyright © 2021 Guardian Project. All rights reserved.
//

import NetworkExtension
import Tor
import IPtProxyUI
import Network


class TorManager {

	enum Status: String, Codable {
		case stopped = "stopped"
		case starting = "starting"
		case started = "started"
	}

	enum Errors: Error, LocalizedError {
		case cookieUnreadable
		case noSocksAddr
		case smartConnectFailed

		var errorDescription: String? {
			switch self {

			case .cookieUnreadable:
				return "Tor cookie unreadable"

			case .noSocksAddr:
				return "No SOCKS port"

			case .smartConnectFailed:
				return "Smart Connect failed"
			}
		}
	}

	static let shared = TorManager()

	static let localhost = "127.0.0.1"

	var status = Status.stopped

	var torSocks5: Network.NWEndpoint? = nil

	private var torThread: Thread?

	private var torController: TorController?

	private var torConf: TorConfiguration?

	private var _torRunning = false
	private var torRunning: Bool {
		 ((torThread?.isExecuting ?? false) && (torConf?.isLocked ?? false)) || _torRunning
	}

	private lazy var controllerQueue = DispatchQueue.global(qos: .userInitiated)

	private var transport = Transport.none

	private var ipStatus = IpSupport.Status.unavailable

	private var progressObs: Any?
	private var establishedObs: Any?


	private init() {
		IpSupport.shared.start({ [weak self] status in
			self?.ipStatus = status

			if (self?.torRunning ?? false) && (self?.torController?.isConnected ?? false) {
				self?.torController?.setConfs(status.torConf(self?.transport ?? .none, Transport.asConf))
				{ success, error in
					if let error = error {
						print("[\(String(describing: type(of: self)))] error: \(error)")
					}

					self?.torController?.resetConnection()
				}
			}
		})
	}

	func start(_ transport: Transport,
			   _ progressCallback: @escaping (_ progress: Int?) -> Void,
			   _ completion: @escaping (Error?) -> Void)
	{
		status = .starting

		self.transport = transport

		if !torRunning {
			startTransport()

			torConf = getTorConf()

//			if let debug = torConf?.compile().joined(separator: ", ") {
//				Logger.log(debug, to: FileManager.default.torLogFile)
//			}

			torThread = TorThread(configuration: torConf)

			torThread?.start()
		}
		else {
			updateConfig(transport)
		}

		controllerQueue.asyncAfter(deadline: .now() + 0.65) {
			if self.torController == nil, let url = self.torConf?.controlPortFile {
				self.torController = TorController(controlPortFile: url)
			}

			if !(self.torController?.isConnected ?? false) {
				do {
					try self.torController?.connect()
				}
				catch let error {
					self.log("#startTunnel error=\(error)")

					self.status = .stopped

					return completion(error)
				}
			}

			guard let cookie = self.torConf?.cookie else {
				self.log("#startTunnel cookie unreadable")

				self.stop()

				return completion(Errors.cookieUnreadable)
			}

			self.torController?.authenticate(with: cookie) { success, error in
				if let error = error {
					self.log("#startTunnel error=\(error)")

					self.stop()

					return completion(error)
				}

				self.progressObs = self.torController?.addObserver(forStatusEvents: {
					[weak self] (type, severity, action, arguments) -> Bool in

					if type == "STATUS_CLIENT" && action == "BOOTSTRAP" {
						let progress: Int?

						if let p = arguments?["PROGRESS"] {
							progress = Int(p)
						}
						else {
							progress = nil
						}

						self?.log("#startTunnel progress=\(progress?.description ?? "(nil)")")

						progressCallback(progress)

						if progress ?? 0 >= 100 {
							self?.torController?.removeObserver(self?.progressObs)
						}

						return true
					}

					return false
				})

				self.establishedObs = self.torController?.addObserver(forCircuitEstablished: { [weak self] established in
					guard established else {
						return
					}

					self?.torController?.removeObserver(self?.establishedObs)
					self?.torController?.removeObserver(self?.progressObs)

					self?.torController?.getInfoForKeys(["net/listeners/socks"]) { response in
						guard let parts = response.first?.split(separator: ":"),
							  let host = parts.first,
							  let host = IPv4Address(String(host)),
							  let port = parts.last,
							  let port = NWEndpoint.Port(String(port))
						else {
							self?.stop()

							return completion(Errors.noSocksAddr)
						}

						self?.torSocks5 = .hostPort(host: NWEndpoint.Host.ipv4(host), port: port)

						self?.status = .started

						completion(nil)
					}
				})
			}
		}
	}

	func updateConfig(_ transport: Transport) {
		self.transport = transport

		startTransport()

		guard let torController = torController else {
			return
		}

		let group = DispatchGroup()

		let resetKeys = ["UseBridges", "ClientTransportPlugin", "Bridge",
						 "EntryNodes", "ExitNodes", "ExcludeNodes", "StrictNodes"]

		for key in resetKeys {
			group.enter()

			torController.resetConf(forKey: key) { _, error in
				if let error = error {
					debugPrint(error)
				}

				group.leave()
			}

			group.wait()
		}

		torController.setConfs(transportConf(Transport.asConf))
	}

	func stop() {
		status = .stopped

		torController?.removeObserver(self.establishedObs)
		torController?.removeObserver(self.progressObs)

		torController?.disconnect()
		torController = nil

		torThread?.cancel()
		torThread = nil

		torConf = nil

		transport.stop()
	}

	func getCircuits(_ completion: @escaping ([TorCircuit]) -> Void) {
		if let torController = torController {
			torController.getCircuits(completion)
		}
		else {
			completion([])
		}
	}

	func close(_ circuits: [TorCircuit], _ completion: ((Bool) -> Void)?) {
		if let torController = torController {
			torController.close(circuits, completion: completion)
		}
		else {
			completion?(false)
		}
	}

	func close(_ ids: [String], _ completion: ((Bool) -> Void)?) {
		if let torController = torController {
			torController.closeCircuits(byIds: ids, completion: completion)
		}
		else {
			completion?(false)
		}
	}


	// MARK: Private Methods

	private func log(_ message: String) {
		print("[\(String(describing: type(of: self)))] \(message)")
	}

	private func getTorConf() -> TorConfiguration {
		let conf = TorConfiguration()

		conf.ignoreMissingTorrc = true
		conf.cookieAuthentication = true
		conf.autoControlPort = true
		conf.clientOnly = true
		conf.avoidDiskWrites = true
		conf.dataDirectory = FileManager.default.torDir
		conf.clientAuthDirectory = FileManager.default.authDir

		// GeoIP files for circuit node country display.
		conf.geoipFile = Bundle.geoIp?.geoipFile
		conf.geoip6File = Bundle.geoIp?.geoip6File

		conf.arguments += transportConf(Transport.asArguments).joined()

		conf.arguments += ipStatus.torConf(transport, Transport.asArguments).joined()

		conf.options = [
			// Log
			"LogMessageDomains": "1",
			"SafeLogging": "1",

			// SOCKS5
			"SocksPort": "auto"]

#if DEBUG
		conf.options["Log"] = "notice stdout"
#else
		conf.options["Log"] = "err file /dev/null"
#endif

		return conf
	}

	private func transportConf<T>(_ cv: (String, String) -> T) -> [T] {

		var arguments = transport.torConf(cv)

		if transport == .custom, let bridgeLines = Settings.customBridges {
			arguments += bridgeLines.map({ cv("Bridge", $0) })
		}

		arguments.append(cv("UseBridges", transport == .none ? "0" : "1"))

		return arguments
	}

	private func startTransport() {
		switch transport {
		case .obfs4, .custom, .meekAzure:
			Transport.snowflake.stop()

		case .snowflake, .snowflakeAmp:
			Transport.obfs4.stop()

		default:
			Transport.obfs4.stop()
			Transport.snowflake.stop()
		}

		transport.start()
	}
}
