//
//  BrowsingViewController+POEDelegate.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import POE

extension BrowsingViewController: POEDelegate {

	@objc func showBridgeSelection() {
		unfocusSearchField()

		let builtInBridges: [Int: String]

		if Ipv6Tester.ipv6_status() == TOR_IPV6_CONN_ONLY {
			builtInBridges = [USE_BRIDGES_OBFS4: "obfs4",
							  USE_BRIDGES_MEEKAMAZON: "meek-amazon",
							  USE_BRIDGES_MEEKAZURE: "meek-azure"]
		}
		else {
			builtInBridges = [USE_BRIDGES_OBFS4: "obfs4",
							  USE_BRIDGES_MEEKAZURE: "meek-azure"]
		}

		let ud = UserDefaults.standard

		let vc = BridgeSelectViewController.instantiate(
			currentId: ud.integer(forKey: USE_BRIDGES),
			noBridgeId: NSNumber(value: USE_BRIDGES_NONE),
			providedBridges: builtInBridges,
			customBridgeId: NSNumber(value: USE_BRIDGES_CUSTOM),
			customBridges: ud.stringArray(forKey: CUSTOM_BRIDGES),
			delegate: self)

		present(vc, torBt)
	}


	// MARK: POEDelegate

	func introFinished(_ useBridge: Bool) {
		print("#introFinished not implemented!");
	}

	/**
	 Receive this callback, after the user finished the bridges configuration.

	 - parameter bridgesId: the selected ID of the list you gave in the constructor of
	 BridgeSelectViewController.
	 - parameter customBridges: the list of custom bridges the user configured.
	 */
	func bridgeConfigured(_ bridgesId: Int, customBridges: [String]) {
		UserDefaults.standard.set(bridgesId, forKey: USE_BRIDGES)
		UserDefaults.standard.set(customBridges, forKey: CUSTOM_BRIDGES)

		// At this point we already have a connection. The bridge reconfiguration is very cheap,
		// so we stay in the browser view and let OnionManager reconfigure in the background.
		// Actually, the reconfiguration can be done completely offline, so we don't have a chance to
		// find out, if another bridge setting (or no bridge) actually works afterwards.
		// The user will find out, when she tries to continue browsing.
		OnionManager.shared.setBridgeConfiguration(bridgesId: bridgesId, customBridges: customBridges)
		OnionManager.shared.startTor(delegate: nil)
	}

	func changeSettings() {
		print("#changeSettings not implemented!");
	}

	func userFinishedConnecting() {
		print("#userFinishedConnecting not implemented!");
	}
}
