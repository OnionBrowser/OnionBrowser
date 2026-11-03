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
	 Checks the Tor status and, if Tor is not running, returns a view controller
	 to show instead of the browser UI.

	 Cibula always uses its built-in Tor. There is no Orbot choice anymore.
	 */
	@MainActor
	func checkStatus() async -> UIViewController? {
		OrbotKit.shared.removeStatusChangeListener(self)

		if !Settings.didWelcome {
			return WelcomeViewController()
		}

		if #available(iOS 17.0, *) {
			// Built-in Tor is the only option.
			Settings.useBuiltInTor = true

			if TorManager.shared.status == .started {
				return nil
			}

			// Tor is not running yet. Let the user start it!
			return StartTorViewController()
		}

		// Built-in Tor needs iOS 17 or newer.
		return InstallViewController()
	}

	func allowRequests() -> Bool {
		if #available(iOS 17.0, *) {
			return TorManager.shared.status == .started
		}

#if DEBUG
		if Self.simulatorIgnoreOrbot {
			return true
		}
#endif

		let status = lastInfo?.status
		return status == .starting || status == .started
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

	/**
	Cancel all connections and re-evalutate the Tor situation and show respective UI.
	*/
	@MainActor
	private func fullStop() {
		for tab in AppDelegate.shared?.allOpenTabs ?? [] {
			tab.stop()
		}
	}
}
