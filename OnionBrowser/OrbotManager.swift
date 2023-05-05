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

class OrbotManager : NSObject, OrbotStatusChangeListener {

	static let shared = OrbotManager()

#if DEBUG
	private static let simulatorIgnoreOrbot = true
#endif

	// MARK: OnionManager instance

	public private(set) var lastInfo: OrbotKit.Info?

	public private(set) var lastError: Error?


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

	 Starts a continuous Orbot status change check, if successful.

	 - returns: A view controller to show instead of the browser UI, if status is not good.
	 */
	func checkStatus() -> UIViewController? {
		OrbotKit.shared.removeStatusChangeListener(self)

		if !Settings.didWelcome {
			return WelcomeViewController()
		}

		if !OrbotKit.shared.installed {
			return InstallViewController()
		}

		if Settings.orbotApiToken?.isEmpty ?? true
			|| Settings.orbotApiToken == Settings.orbotAccessDenied
		{
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

#if DEBUG
		if Self.simulatorIgnoreOrbot {
			return nil
		}
#endif

		if lastInfo?.status == .stopped || lastInfo?.onionOnly ?? false {
			return StartViewController()
		}

		OrbotKit.shared.notifyOnStatusChanges(self)

		return nil
	}


	// MARK: OrbotStatusChangeListener

	func orbotStatusChanged(info: OrbotKit.Info) {
		guard lastInfo?.status != info.status || lastInfo?.onionOnly != info.onionOnly else {
			lastInfo = info

			return
		}

		lastInfo = info

		DispatchQueue.main.async {
			if info.status == .stopped || info.onionOnly {
				self.fullStop()

				AppDelegate.shared?.show(StartViewController())
			}
			else {
				AppDelegate.shared?.show()
			}
		}
	}

	func statusChangeListeningStopped(error: Error) {
		lastError = error

		DispatchQueue.main.async {
			self.fullStop()

			AppDelegate.shared?.show(self.checkStatus())
		}
	}


	// MARK: Private Methods

	/**
	Cancel all connections and re-evalutate Orbot situation and show respective UI.
	*/
	private func fullStop() {
		for tab in AppDelegate.shared?.browsingUi?.tabs ?? [] {
			tab.stop()
		}
	}
}
