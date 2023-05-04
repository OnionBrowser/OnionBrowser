//
//  OrbotManager.swift
//  OnionBrowser
//
//  Copyright © 2012 - 2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import OrbotKit

class OrbotManager : NSObject {

	static let shared = OrbotManager()

	// Show Tor log in iOS' app log.
	private static let TOR_LOGGING = false



	// MARK: OnionManager instance

	public private(set) var lastInfo: OrbotKit.Info?

	public private(set) var lastError: Error?

	private var initRetry: DispatchWorkItem?

	private var needsReconfiguration = false


	// MARK: Public Methods

	func closeCircuits(_ circuits: [OrbotKit.TorCircuit], _ callback: @escaping ((_ success: Bool) -> Void)) {
		let group = DispatchGroup()
		var suc = false

		for circuit in circuits {
			group.enter()

			OrbotKit.shared.closeCircuit(circuit: circuit) { success, error in
				if let error = error {
					print("[\(String(describing: type(of: self)))]#closeCircuits error=\(error)")
				}

				// If only one call succeeds, we count that as a success.
				if success {
					suc = true
				}

				group.leave()
			}
		}

		group.notify(queue: .main) {
			callback(suc)
		}
	}

	/**
	Get all fully built circuits and detailed info about their nodes.

	- parameter callback: Called, when all info is available.
	- parameter circuits: A list of circuits and the nodes they consist of.
	*/
	func getCircuits(host: String?, _ callback: @escaping ((_ circuits: [OrbotKit.TorCircuit]) -> Void)) {
		OrbotKit.shared.circuits(host: host) { circuits, error in
			if let error = error {
				print("[\(String(describing: type(of: self)))]#getCircuits error=\(error)")
			}

			callback(circuits ?? [])
		}
	}

	/**
	 Check's Orbot's status, and if not working, returns a view controller to show instead of the browser UI.

	 - returns: A view controller to show instead of the browser UI, if status is not good.
	 */
	func checkStatus() -> UIViewController? {
		if !Settings.didWelcome {
			return WelcomeViewController()
		}

		if !OrbotKit.shared.installed {
			return InstallViewController()
		}

		if Settings.orbotApiToken?.isEmpty ?? true {
			return PermissionViewController()
		}

		OrbotKit.shared.apiToken = Settings.orbotApiToken

		let group = DispatchGroup()
		group.enter()

		OrbotKit.shared.info { info, error in
			self.lastInfo = info
			self.lastError = error

			group.leave()
		}

		let result = group.wait(timeout: .now() + 1)

		if result == .timedOut || lastError != nil {
			let vc = PermissionViewController()
			vc.error = lastError

			return vc
		}

		if lastInfo?.status == .stopped {
			return StartViewController()
		}
		
		return nil
	}


	// MARK: Private Methods

	/**
	Cancel the connection retry and fail guard.
	*/
	private func cancelInitRetry() {
		initRetry?.cancel()
		initRetry = nil
	}
}
