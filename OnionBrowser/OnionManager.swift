//
//  OnionManager.swift
//  OnionBrowser2
//
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import Tor
import IPtProxyUI

protocol OnionManagerDelegate: AnyObject {

	func torConnProgress(_ progress: Int)

	func torConnFinished()

	func torConnDifficulties()
}

class OnionManager : NSObject {

	enum TorState {
		case none
		case started
		case connected
		case stopped
	}

	static let shared = OnionManager()

	// Show Tor log in iOS' app log.
	private static let TOR_LOGGING = false


	/**
	Basic Tor configuration.
	*/
	private static let torBaseConf: TorConfiguration = {
		let conf = TorConfiguration()
		conf.ignoreMissingTorrc = true
		conf.cookieAuthentication = true
		conf.autoControlPort = true
		conf.clientOnly = true
		conf.avoidDiskWrites = true
		conf.dataDirectory = FileManager.default.torDir
		conf.clientAuthDirectory = FileManager.default.authDir

		conf.geoipFile = Bundle.geoIp?.geoipFile
		conf.geoip6File = Bundle.geoIp?.geoip6File

		#if DEBUG
		let log_loc = "notice stdout"
		#else
		let log_loc = "notice file /dev/null"
		#endif

		conf.options["SocksPort"] = "127.0.0.1:\(AppDelegate.socksProxyPort)"
		conf.options["Log"] = log_loc

		return conf
	}()


	// MARK: OnionManager instance

	public var state = TorState.none

	public lazy var onionAuth: TorOnionAuth? = {
		guard let dir = FileManager.default.authDir else {
			return nil
		}

		return TorOnionAuth(withPrivateDir: dir, andPublicDir: nil)
	}()

	private var torController: TorController?

	private var torThread: TorThread?

	private var connectionGuard: DispatchSourceTimer?
	private var connectionTimeout = DispatchTime.now()

	private var transport = Transport.none
	private var customBridges: [String]?
	private var needsReconfiguration = false
	private var ipStatus = IpSupport.Status.unavailable


	override init() {
		super.init()

		IpSupport.shared.start({ [weak self] status in
			self?.ipStatus = status

			if !(self?.torThread?.isCancelled ?? true) {
				self?.torController?.setConfs(status.torConf(self?.transport ?? .none, Transport.asConf))
				{ success, error in
					if let error = error {
						print("[\(String(describing: type(of: self)))] error: \(error)")
					}

					self?.torReconnect()
				}
			}
		})
	}


	// MARK: Public Methods

	/**
	Set bridges configuration and evaluate, if the new configuration is actually different
	then the old one.

	- parameter transport: The selected transport.
	- parameter customBridges: a list of custom bridges the user configured.
	*/
	func setTransportConf(transport: Transport, customBridges: [String]?) {
		needsReconfiguration = transport != self.transport

		if !needsReconfiguration {
			if let oldVal = self.customBridges, let newVal = customBridges {
				needsReconfiguration = oldVal != newVal
			}
			else{
				needsReconfiguration = (self.customBridges == nil && customBridges != nil) ||
					(self.customBridges != nil && customBridges == nil)
			}
		}

		self.transport = transport
		self.customBridges = customBridges
	}

	func torReconnect(_ callback: ((_ success: Bool) -> Void)? = nil) {
		torController?.resetConnection(callback)
	}

	func closeCircuits(_ circuits: [TorCircuit], _ callback: @escaping ((_ success: Bool) -> Void)) {
		torController?.close(circuits, completion: callback)
	}

	/**
	Get all fully built circuits and detailed info about their nodes.

	- parameter callback: Called, when all info is available.
	- parameter circuits: A list of circuits and the nodes they consist of.
	*/
	func getCircuits(_ callback: @escaping ((_ circuits: [TorCircuit]) -> Void)) {
		torController?.getCircuits(callback)
	}

	func startTor(delegate: OnionManagerDelegate?) {
		// Avoid a retain cycle. Only use the weakDelegate in closures!
		weak var weakDelegate = delegate

		stopConnectionGuard()
		state = .started

		if torThread?.isCancelled ?? true {
			torThread = nil

			let conf = Self.torBaseConf

			// Add user-defined configuration.
			conf.arguments += Settings.advancedTorConf ?? []

			conf.arguments += transportConf(Transport.asArguments).joined()

			// configure ipv4/ipv6
			// Use Ipv6Tester. If we _think_ we're IPv6-only, tell Tor to prefer IPv6 ports.
			// (Tor doesn't always guess this properly due to some internal IPv4 addresses being used,
			// so "auto" sometimes fails to bootstrap.)
			conf.arguments += ipStatus.torConf(transport, Transport.asArguments).joined()

			#if DEBUG
			print("[\(String(describing: type(of: self)))] conf=\(conf.compile())")
			#endif

			torThread = TorThread(configuration: conf)
			needsReconfiguration = false

			torThread?.start()

			print("[\(String(describing: type(of: self)))] Starting Tor")
		}
		else {
			if needsReconfiguration {
				torController?.resetConf(forKey: "UseBridges")
				{ [weak self] success, error in
					if !success {
						return
					}

					self?.torController?.resetConf(forKey: "ClientTransportPlugin")
					{ [weak self] success, error in
						if !success {
							return
						}

						self?.torController?.resetConf(forKey: "Bridge")
						{ [weak self] success, error in
							if !success {
								return
							}

							self?.torController?.setConfs(
								self?.transportConf(Transport.asConf) ?? [])
						}
					}
				}
			}
		}

		// Wait long enough for Tor itself to have started. It's OK to wait for this
		// because Tor is already trying to connect; this is just the part that polls for
		// progress.
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
			if Self.TOR_LOGGING {
				// Show Tor log in iOS' app log.
				TORInstallTorLoggingCallback { severity, msg in
					let s: String

					switch severity {
					case .debug:
						s = "debug"

					case .error:
						s = "error"

					case .fault:
						s = "fault"

					case .info:
						s = "info"

					default:
						s = "default"
					}

					print("[Tor \(s)] \(String(cString: msg).trimmingCharacters(in: .whitespacesAndNewlines))")
				}
				TORInstallEventLoggingCallback { severity, msg in
					let s: String

					switch severity {
					case .debug:
						// Ignore libevent debug messages. Just too many of typically no importance.
						return

					case .error:
						s = "error"

					case .fault:
						s = "fault"

					case .info:
						s = "info"

					default:
						s = "default"
					}

					print("[libevent \(s)] \(String(cString: msg).trimmingCharacters(in: .whitespacesAndNewlines))")
				}
			}

			if self.torController == nil, let controlPortFile = Self.torBaseConf.controlPortFile {
				self.torController = TorController(controlPortFile: controlPortFile)
			}

			if !(self.torController?.isConnected ?? false) {
				do {
					try self.torController?.connect()
				} catch {
					print("[\(String(describing: Self.self))] error=\(error)")
				}
			}

			guard let cookie = Self.torBaseConf.cookie else {
				print("[\(String(describing: type(of: self)))] Could not connect to Tor - cookie unreadable!")

				return
			}

			#if DEBUG
			print("[\(String(describing: type(of: self)))] cookie=", cookie.base64EncodedString())
			#endif

			self.torController?.authenticate(with: cookie, completion: { success, error in
				if success {
					var completeObs: Any?
					completeObs = self.torController?.addObserver(forCircuitEstablished: { established in
						if established {
							self.state = .connected
							self.torController?.removeObserver(completeObs)
							self.stopConnectionGuard()
							#if DEBUG
							print("[\(String(describing: type(of: self)))] Connection established!")
							#endif

							weakDelegate?.torConnFinished()
						}
					}) // torController.addObserver

					var progressObs: Any?
					progressObs = self.torController?.addObserver(forStatusEvents: {
						(type: String, severity: String, action: String, arguments: [String : String]?) -> Bool in

						if type == "STATUS_CLIENT" && action == "BOOTSTRAP" {
							self.connectionAlive()

							let progress = Int(arguments!["PROGRESS"]!)!
							#if DEBUG
							print("[\(String(describing: Self.self))] progress=\(progress)")
							#endif

							weakDelegate?.torConnProgress(progress)

							if progress >= 100 {
								self.torController?.removeObserver(progressObs)
							}

							return true
						}

						return false
					}) // torController.addObserver
				} // if success (authenticate)
				else {
					print("[\(String(describing: type(of: self)))] Didn't connect to control port.")
				}
			}) // controller authenticate
		} //delay

		// Assume everything's fine for the next 15 seconds.
		connectionAlive()

		// Create new connection guard.
		connectionGuard = DispatchSource.makeTimerSource(queue: .global(qos: .background))
		connectionGuard?.schedule(deadline: .now() + 1, repeating: .seconds(1))

		// If Tor's progress doesn't move within 15 seconds,
		// HUP tor once in case we have partially bootstrapped but got stuck.
		// Also inform delegate about connection difficulties.
		connectionGuard?.setEventHandler { [weak self] in
			if DispatchTime.now() > self?.connectionTimeout ?? DispatchTime.now() {
				// Only do this, if we're not running over a bridge, it will close
				// the connection to the bridge client which will close or break the bridge client!
				if self?.transport == Transport.none {
					#if DEBUG
					print("[\(String(describing: type(of: self)))] Triggering Tor connection retry.")
					#endif

					self?.torController?.setConfForKey("DisableNetwork", withValue: "1")
					self?.torController?.setConfForKey("DisableNetwork", withValue: "0")
				}

				DispatchQueue.main.async {
					delegate?.torConnDifficulties()
				}

				self?.stopConnectionGuard()
			}
		}

		connectionGuard?.resume()
	}// startTor

	/**
	Shuts down Tor.
	*/
	func stopTor() {
		print("[\(String(describing: type(of: self)))] #stopTor")

		// Under the hood, TORController will SIGNAL SHUTDOWN and set it's channel to nil, so
		// we actually rely on that to stop Tor and reset the state of torController. (we can
		// SIGNAL SHUTDOWN here, but we can't reset the torController "isConnected" state.)
		torController?.disconnect()
		torController = nil

		// More cleanup
		torThread?.cancel()
		torThread = nil

		transport.stop()

		state = .stopped
	}

	/**
	 Will make Tor reload its configuration, if it's already running or start (again), if not.

	 This is needed, when bridge configuration changed, or when v3 onion service authentication keys
	 are added.

	 When such keys are removed, that's unfortunately not enough. Only a full stop and restart will do.
	 But still being able to access auhtenticated Onion services after removing the key doesn't seem
	 to be such a huge deal compared to not being able to access it despite having added the key.

	 So that should be good enough?
	 */
	func reloadTor(delegate: OnionManagerDelegate? = nil) {
		needsReconfiguration = true

		startTor(delegate: delegate)
	}


	// MARK: Private Methods

	private func transportConf<T>(_ cv: (String, String) -> T) -> [T] {

		switch transport {
		case .none:
			Transport.obfs4.stop()
			Transport.snowflake.stop()

		case .obfs4, .custom:
			Transport.snowflake.stop()

		case .snowflake, .snowflakeAmp:
			Transport.obfs4.stop()
		}

		transport.start()

		var arguments = transport.torConf(cv)

		if transport == .custom, let bridgeLines = customBridges {
			arguments += bridgeLines.map({ cv("Bridge", $0) })
		}

		arguments.append(cv("UseBridges", transport == .none ? "0" : "1"))

		return arguments
	}

	/**
	 Give connection guard another 15 seconds to assume everything's ok.
	 */
	private func connectionAlive() {
		connectionTimeout = .now() + 15
	}

	private func stopConnectionGuard() {
		connectionGuard?.cancel()
		connectionGuard = nil
	}
}
