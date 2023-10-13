//
//  OrbotManager.swift
//  OnionBrowser
//
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import OrbotKit

class OrbotManager : NSObject, OrbotStatusChangeListener {

	static let shared = OrbotManager()

#if DEBUG
	static let simulatorIgnoreOrbot = false
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

		if #available(iOS 17.0, *) {
			if let useBuiltinTor = Settings.useBuiltInTor {
				if useBuiltinTor {
					// User wants to use built-in Tor.

					if OrbotKit.shared.installed {
						// But Orbot is installed.

						if !hasOrbotPermission() {
							// ...and we cannot access it. That needs to change.

							let vc = PermissionViewController()
							vc.error = lastError

							return vc
						}

						// NOTE: lastInfo should be filled as a side effect of `hasOrbotPermission()`!
						if lastInfo?.status != .stopped {
							if lastInfo?.onionOnly ?? false {
								// Uh-oh. No onion-only mode allowed.
								return StartOrbotViewController()
							}

							// User has a running Orbot. Just use that.
							Settings.useBuiltInTor = false

							OrbotKit.shared.notifyOnStatusChanges(self)

							return nil
						}
					}

					if TorManager.shared.status == .started {
						// No Orbot running, but built-in Tor. Also ok.
						return nil
					}

					// No Orbot running, no built-in Tor. Let the user start it!
					return StartTorViewController()
				}

				// User decided against built-in Tor.
				// Continue with Orbot flow.
			}
			else {
				// User did not decide, yet.

				return OrbotOrBuiltInViewController()
			}
		}

		if !OrbotKit.shared.installed {
			return InstallViewController()
		}

		if !hasOrbotPermission() {
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
			return StartOrbotViewController()
		}

		OrbotKit.shared.notifyOnStatusChanges(self)

		return nil
	}

	func allowRequests() -> Bool {
		if Settings.useBuiltInTor == true, #available(iOS 17.0, *) {
			return TorManager.shared.status == .started
		}
		else {
#if DEBUG
			if Self.simulatorIgnoreOrbot {
				return true
			}
#endif

			let status = lastInfo?.status
			return status == .starting || status == .started
		}
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

				for delegate in AppDelegate.shared?.sceneDelegates ?? [] {
					delegate.show(self.checkStatus())
				}
			}
			else {
				for delegate in AppDelegate.shared?.sceneDelegates ?? [] {
					delegate.show()
				}
			}
		}
	}

	func statusChangeListeningStopped(error: Error) {
		lastError = error

		DispatchQueue.main.async {
			self.fullStop()

			for delegate in AppDelegate.shared?.sceneDelegates ?? [] {
				delegate.show(self.checkStatus())
			}
		}
	}


	// MARK: Private Methods

	private func hasOrbotPermission() -> Bool {
		let token = Settings.orbotApiToken

		if token?.isEmpty ?? true || token == Settings.orbotAccessDenied {
			return false
		}

		OrbotKit.shared.apiToken = token

		let group = DispatchGroup()
		group.enter()

		OrbotKit.shared.info { info, error in
			self.lastInfo = info
			self.lastError = error

			group.leave()
		}

		let result = group.wait(timeout: .now() + 1)

		return result != .timedOut && lastError == nil
	}

	/**
	Cancel all connections and re-evalutate Orbot situation and show respective UI.
	*/
	private func fullStop() {
		DispatchQueue.main.async {
			for tab in AppDelegate.shared?.allOpenTabs ?? [] {
				tab.stop()
			}
		}
	}
}
