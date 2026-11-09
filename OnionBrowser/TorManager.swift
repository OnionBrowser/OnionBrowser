//
//  TorManager.swift
//  Orbot
//
//  Created by Benjamin Erhart on 17.05.21.
//  Copyright © 2021 Guardian Project. All rights reserved.
//

import NetworkExtension
import CTor
import IPtProxyUI_iOS
import Network


class TorManager {

	enum Status: String, Codable {
		case stopped = "stopped"
		case starting = "starting"
		case started = "started"
	}

	enum Errors: Error, LocalizedError {
		case noTorController
		case cookieUnreadable
		case noSocksAddr
		case smartConnectFailed

		var errorDescription: String? {
			switch self {

			case .noTorController:
				return "No Tor controller"

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

	var status: Status {
		if !torRunning {
			return .stopped
		}

		if (torController?.isConnected ?? false) && torSocks5 != nil {
			return .started
		}

		return .starting
	}

	private(set) var torSocks5: Network.NWEndpoint? = nil

	private var torThread: Thread?

	private var torController: TorController?

	private var torConf: TorConfiguration?

	private var torRunning: Bool {
		 (torThread?.isExecuting ?? false) && (torConf?.isLocked ?? false)
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
						self?.log("error: \(error)")
					}

					self?.torController?.resetConnection()
				}
			}
		})
	}

	func start(_ transport: Transport,
			   _ progressCallback: @escaping (_ progress: Int?, _ summary: String?) -> Void) async throws
	{
		self.transport = transport

		if !torRunning {
			try startTransport()

			torConf = getTorConf()

//			if let debug = torConf?.compile().joined(separator: ", ") {
//				Log.debug(for: Self.self, debug)
//			}

			torThread = TorThread(configuration: torConf)

			torThread?.start()
		}
		else {
			await updateConfig(transport)
		}

		do {
			try await Task.sleep(nanoseconds: UInt64(0.65 * Double(NSEC_PER_SEC)))

			if torController == nil, let url = torConf?.controlPortFile {
				torController = TorController(controlPortFile: url)
			}

			guard let torController else {
				log("#startTunnel error=\(Errors.noTorController)")

				throw Errors.noTorController
			}

			if !torController.isConnected {
				var err: Error? = nil

				// Why did this become unstable?
				for _ in 0 ..< 3 {
					do {
						err = nil
						try torController.connect()
						break
					}
					catch let error {
						log("#startTunnel error=\(error)")
						err = error

						try? await Task.sleep(nanoseconds: UInt64(0.25 * Double(NSEC_PER_SEC)))
					}
				}

				if let err {
					throw err
				}
			}

			var cookie: Data? = nil

			// Why did this become unstable?
			for _ in 0 ..< 3 {
				cookie = torConf?.cookie

				if cookie != nil {
					break
				}

				try? await Task.sleep(nanoseconds: UInt64(0.25 * Double(NSEC_PER_SEC)))
			}

			guard let cookie = cookie else {
				self.log("#startTunnel cookie unreadable")

				throw Errors.cookieUnreadable
			}

			try await torController.authenticate(with: cookie)

			torController.removeObserver(progressObs)
			progressObs = nil

			progressObs = torController.addObserver(forStatusEvents: {
				(type, severity, action, arguments) -> Bool in

				if type == "STATUS_CLIENT" && action == "BOOTSTRAP" {
					self.log("#startTunnel arguments=\(arguments?.description ?? "(nil)")")

					var progress: Int? = nil

					if let p = arguments?["PROGRESS"] {
						progress = Int(p)
					}

					progressCallback(progress, arguments?["SUMMARY"])

					if progress ?? 0 >= 100 {
						torController.removeObserver(self.progressObs)
						self.progressObs = nil
					}

					return true
				}

				return false
			})

			torController.removeObserver(establishedObs)
			establishedObs = nil

			try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
				establishedObs = torController.addObserver(forCircuitEstablished: { established in
					guard established else {
						return
					}

					continuation.resume(returning: ())
				})
			}

			torController.removeObserver(establishedObs)
			establishedObs = nil
			torController.removeObserver(progressObs)
			progressObs = nil

			let response = await torController.info(forKeys: ["net/listeners/socks"])

			guard let parts = response.first?.split(separator: ":"),
				  let host = parts.first,
				  let host = IPv4Address(String(host)),
				  let port = parts.last,
				  let port = NWEndpoint.Port(String(port))
			else {
				throw Errors.noSocksAddr
			}

			torSocks5 = .hostPort(host: NWEndpoint.Host.ipv4(host), port: port)
		}
		catch {
			stop()

			throw error
		}
	}

	func updateConfig(_ transport: Transport) async {
		self.transport = transport

		do {
			try startTransport()
		}
		catch {
			return log("error=\(error)")
		}

		guard let torController = torController else {
			return
		}

		let resetKeys = ["UseBridges", "ClientTransportPlugin", "Bridge",
						 "EntryNodes", "ExitNodes", "ExcludeNodes", "StrictNodes"]

		for key in resetKeys {
			do {
				try await torController.resetConf(forKey: key)
			}
			catch {
				log("error=\(error)")
			}
		}

		do {
			try await torController.setConfs(transportConf(Transport.asConf))
		}
		catch {
			log("error=\(error)")
		}
	}

	func stop() {
		torSocks5 = nil

		torController?.removeObserver(self.establishedObs)
		torController?.removeObserver(self.progressObs)

		torController?.disconnect()
		torController = nil

		torThread?.cancel()
		torThread = nil

		torConf = nil

		transport.stop()
	}

	func getCircuits() async -> [TorCircuit] {
		await torController?.circuits() ?? []
	}

	func close(_ circuits: [TorCircuit]) async -> Bool {
		await torController?.close(circuits) ?? false
	}

	@discardableResult
	func close(_ ids: [String]) async -> Bool {
		await torController?.closeCircuits(byIds: ids) ?? false
	}

	func session(
		_ cookies: [HTTPCookie]? = nil, for url: URL? = nil,
		delegate: URLSessionDelegate? = nil, timeout: TimeInterval? = nil
	) -> URLSession
	{
		let conf = URLSessionConfiguration.ephemeral
		conf.waitsForConnectivity = true
		conf.allowsConstrainedNetworkAccess = true
		conf.allowsExpensiveNetworkAccess = true

		if let timeout {
			conf.timeoutIntervalForResource = timeout
		}

		if let cookies = cookies {
			conf.httpCookieStorage?.setCookies(cookies, for: url, mainDocumentURL: nil)
		}

		if #available(iOS 17.0, *), Settings.useBuiltInTor == true {
			// There should be a started Tor and the correct proxy configuration available.
			// If not, use an invalid one to make the request fail and not leak.
			let proxy = torSocks5 ?? NWEndpoint.hostPort(host: .ipv4(.loopback), port: .any)
			conf.proxyConfigurations.append(.init(socksv5Proxy: proxy))
		}

		return .init(configuration: conf, delegate: delegate, delegateQueue: .main)
	}


	// MARK: Private Methods

	private func log(_ message: String) {
		Log.log(for: Self.self, message)
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
		conf.geoipFile = Bundle.main.url(forResource: "geoip", withExtension: nil)
		conf.geoip6File = Bundle.main.url(forResource: "geoip6", withExtension: nil)

		var arguments = [String]()
		arguments.append(contentsOf: transportConf(Transport.asArguments).joined())
		arguments.append(contentsOf: ipStatus.torConf(transport, Transport.asArguments).joined())

		// Urgh. Transports and IP settings where ignored on first start.
		// Careful: `arguments as? NSMutableCopy == nil`
		conf.arguments.addObjects(from: arguments)

#if DEBUG
		let log = "notice stdout"
#else
		let log = "err file /dev/null"
#endif

		conf.options = [
			// Log
			"Log": log,
			"LogMessageDomains": "1",
			"SafeLogging": "1",

			// SOCKS5
			"SocksPort": "auto"]

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

	private func startTransport() throws {
		transport.stopAllOthers()

		try transport.start()
	}
}
