//
//  OrbotManager.swift
//  OnionBrowser
//
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
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

	@discardableResult
	func closeCircuits(_ circuits: [OrbotKit.TorCircuit]) async -> Bool {
		var groupSuccess = false

		for circuit in circuits {
			var singleSuccess = false

			do {
				singleSuccess = try await OrbotKit.shared.closeCircuit(circuit: circuit)
			}
			catch {
				Log.error(for: Self.self, "#closeCircuits error=\(error)")
			}

			// If only one call succeeds, we count that as a success.
			if singleSuccess {
				groupSuccess = true
			}
		}

		return groupSuccess
	}

	/**
	Get all fully built circuits and detailed info about their nodes.

	- parameter callback: Called, when all info is available.
	- returns: A list of circuits and the nodes they consist of.
	*/
	func getCircuits(host: String?) async -> [OrbotKit.TorCircuit] {
		do {
			return try await OrbotKit.shared.circuits() ?? []
		}
		catch {
			Log.error(for: Self.self, "#getCircuits error=\(error)")

			return []
		}
	}

	/**
	 Check's Orbot's status, and if not working, returns a view controller to show instead of the browser UI.

	 Starts a continuous Orbot status change check, if successful.

	 - returns: A view controller to show instead of the browser UI, if status is not good.
	 */
	@MainActor
	func checkStatus() async -> UIViewController? {
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

						if await !hasOrbotPermission() {
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

		if await !hasOrbotPermission() {
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

		Task { @MainActor in
			if info.status == .stopped || info.onionOnly {
				fullStop()

				for delegate in AppDelegate.shared?.sceneDelegates ?? [] {
					delegate.show(await checkStatus())
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

		Task { @MainActor in
			fullStop()

			for delegate in AppDelegate.shared?.sceneDelegates ?? [] {
				delegate.show(await checkStatus())
			}
		}
	}


	// MARK: Private Methods

	private func hasOrbotPermission() async -> Bool {
		let token = Settings.orbotApiToken

		if token?.isEmpty ?? true || token == Settings.orbotAccessDenied {
			return false
		}

		OrbotKit.shared.apiToken = token

		do {
			lastInfo = try await OrbotKit.shared.info()
		}
		catch {
			lastError = error
		}

		return lastError == nil
	}

	/**
	Cancel all connections and re-evalutate Orbot situation and show respective UI.
	*/
	@MainActor
	private func fullStop() {
		for tab in AppDelegate.shared?.allOpenTabs ?? [] {
			tab.stop()
		}
	}
}
