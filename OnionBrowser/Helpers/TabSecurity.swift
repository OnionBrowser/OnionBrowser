//
//  TabSecurity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.05.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

@objcMembers
class TabSecurity: NSObject {

	enum Level: String, CustomStringConvertible {

		case alwaysRemember = "always_remember"
		case forgetOnShutdown = "forget_on_shutdown"
		case clearOnBackground = "clear_on_background"

		var description: String {
			switch self {
			case .alwaysRemember:
				return NSLocalizedString("Remember Tabs", comment: "Tab security level")

			case .forgetOnShutdown:
				return NSLocalizedString("Forget at Shutdown", comment: "Tab security level")

			default:
				return NSLocalizedString("Forget in Background", comment: "Tab security level")
			}
		}
	}

	class var isClearOnBackground: Bool {
		return Settings.tabSecurity  == .clearOnBackground
	}

	/**
	Handle tab privacy
	*/
	class func handleBackgrounding() {
		let security = Settings.tabSecurity
		let controller = AppDelegate.shared?.browsingUi
		let cookieJar = AppDelegate.shared?.cookieJar
		let ocspCache = AppDelegate.shared?.certificateAuthentication

		if security == .clearOnBackground {
			controller?.removeAllTabs()
		}
		else {
			cookieJar?.clearAllOldNonWhitelistedData()
			ocspCache?.persist()
		}

		if security == .alwaysRemember {
			// Ignore special URLs, as these could get us into trouble after app updates.
			Settings.openTabs = controller?.tabs.map({ $0.url }).filter({ !$0.isSpecial })

			print("[\(String(describing: self))] save open tabs=\(String(describing: Settings.openTabs))")
		}
		else {
			print("[\(String(describing: self))] clear saved open tab urls")
			Settings.openTabs = nil
		}
	}

	class func restore() {
		if Settings.tabSecurity  == .alwaysRemember,
			let controller = AppDelegate.shared?.browsingUi {

			for url in Settings.openTabs ?? [] {
				// Ignore special URLs, as these could get us into trouble after app updates.
				if !url.isSpecial {
					print("[\(String(describing: self))] restore tab with url=\(url)")

					controller.addNewTab(url, transition: .notAnimated)
				}
			}
		}
		else {
			print("[\(String(describing: self))] clear saved open tab urls")
			Settings.openTabs = nil
		}
	}
}
