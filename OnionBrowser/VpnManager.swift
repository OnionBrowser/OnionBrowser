//
//  VpnManager.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 29.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import NetworkExtension

protocol VpnManagerDelegate {

	func onError(_ error: Error)

	func onProgress(_ progress: Float)

	func onConnected()
}

class VpnManager {

	enum Errors: Error {
		case couldNotConnect
	}

	static let shared = VpnManager()

	private var delegate: VpnManagerDelegate?

	private var manager: NETunnelProviderManager?
	private var session: NETunnelProviderSession?

	private var poll = false

	init() {
		NSKeyedUnarchiver.setClass(ProgressMessage.self, forClassName:
			"TorVPN.\(String(describing: ProgressMessage.self))")

		NotificationCenter.default.addObserver(
			self, selector: #selector(statusDidChange),
			name: .NEVPNStatusDidChange, object: nil)
	}

	func start(delegate: VpnManagerDelegate?) {
		self.delegate = delegate
		manager = nil

		NETunnelProviderManager.loadAllFromPreferences { managers, error in
			if let error = error {
				DispatchQueue.main.async {
					self.delegate?.onError(error)
				}

				return
			}

			if let manager = managers?.first {
				self.manager = manager

				// Manager found and enabled. -> start right through.
				if manager.isEnabled {
					self.start2ndStage()

					return
				}
			}

			// No manager found. -> Create one.
			if self.manager == nil {
				let conf = NETunnelProviderProtocol()
				conf.providerBundleIdentifier = Config.extBundleId
				conf.serverAddress = "Tor" // Needs to be set to something, otherwise error.

				self.manager = NETunnelProviderManager()
				self.manager?.protocolConfiguration = conf
				self.manager?.localizedDescription = Bundle.main.displayName
			}

			// Manager found, but disabled. -> Enable.
			self.manager?.isEnabled = true

			// Add a "always connect" rule to avoid leakage after the network
			// extension got killed.
			if self.manager?.onDemandRules?.count ?? 0 < 1 {
				self.manager?.onDemandRules = [NEOnDemandRuleConnect()]
			}

			self.manager?.saveToPreferences { error in
				if let error = error {
					self.manager = nil

					DispatchQueue.main.async {
						self.delegate?.onError(error)
					}

					return
				}

				self.start2ndStage()
			}
		}
	}

	func getCircuits(_ callback: @escaping ((_ circuits: [TorCircuit]) -> Void)) {
		guard let request = try? NSKeyedArchiver.archivedData(
			withRootObject: GetCircuitsMessage(), requiringSecureCoding: true) else {

			print("[\(String(describing: type(of: self)))]#getCircuits error=Could not create request.")
			return callback([])
		}

		do {
			try session?.sendProviderMessage(request) { response in
				if let response = response,
					let circuits = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(response) as? [TorCircuit] {

					callback(circuits)
				}
				else {
					print("[\(String(describing: type(of: self)))]#getCircuits error=Could not decode response.")
					callback([])
				}
			}
		}
		catch let error {
			print("[\(String(describing: type(of: self)))]#getCircuits error=\(error)")
			callback([])
		}
	}

	func closeCircuits(_ circuits: [TorCircuit], _ callback: @escaping ((_ success: Bool) -> Void)) {
		guard let request = try? NSKeyedArchiver.archivedData(
			withRootObject: CloseCircuitsMessage(circuits), requiringSecureCoding: true) else {

			print("[\(String(describing: type(of: self)))]#closeCircuits error=Could not create request.")
			return callback(false)
		}

		do {
			try session?.sendProviderMessage(request) { response in
				if let response = response,
					let success = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(response) as? Bool {

					callback(success)
				}
				else {
					print("[\(String(describing: type(of: self)))]#closeCircuits error=Could not decode response.")
					callback(false)
				}
			}
		}
		catch let error {
			print("[\(String(describing: type(of: self)))]#closeCircuits error=\(error)")
			callback(false)
		}
	}


	// MARK: Private Methods

	private func start2ndStage() {
		DispatchQueue.main.async {
			self.session = self.manager?.connection as? NETunnelProviderSession

			do {
				try self.session?.startVPNTunnel()
			}
			catch let error {
				DispatchQueue.main.async {
					self.delegate?.onError(error)
				}
			}

			self.commTunnel()
		}
	}

	@objc
	private func statusDidChange(_ notification: Notification) {
		switch session?.status {
		case .invalid:
			// Provider not installed/enabled

			poll = false

			DispatchQueue.main.async {
				self.delegate?.onError(Errors.couldNotConnect)
			}

		case .connecting:
			poll = true
			commTunnel()

		case .connected:
			poll = false

			DispatchQueue.main.async {
				self.delegate?.onConnected()
			}

		case .reasserting:
			// Circuit reestablishing
			poll = true
			commTunnel()

		case .disconnecting:
			// Circuit disestablishing
			poll = false

		case .disconnected:
			// Circuit not established
			poll = false

		default:
			assert(session == nil)
        }
	}

	private func commTunnel() {
		if (session?.status ?? .invalid) != .invalid {
			do {
				try session?.sendProviderMessage(Data()) { response in
					if let response = response {
						if let response = NSKeyedUnarchiver.unarchiveObject(with: response) as? [Message] {

							for message in response {
								if let pm = message as? ProgressMessage {
									print("[\(String(describing: type(of: self)))] ProgressMessage=\(pm.progress)")

									DispatchQueue.main.async {
										self.delegate?.onProgress(pm.progress)
									}
								}
							}
						}
					}
				}
			}
			catch {
				print("[\(String(describing: type(of: self)))] "
					+ "Could not establish communications channel with extension. "
					+ "Error: \(error)")
			}

			if poll {
				DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: self.commTunnel)
			}
		}
		else {
			print("[\(String(describing: type(of: self)))] "
				+ "Could not establish communications channel with extension. "
				+ "VPN configuration does not exist or is not enabled. "
				+ "No further actions will be taken.")

			DispatchQueue.main.async {
				self.delegate?.onError(Errors.couldNotConnect)
			}
		}
	}
}
