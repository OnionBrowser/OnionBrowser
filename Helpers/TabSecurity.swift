//
//  TabSecurity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.05.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
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

	private static let openTabs = "open_tabs"

	class var isClearOnBackground: Bool {
		return Settings.tabSecurity  == .clearOnBackground
	}

	/**
	Handle tab privacy
	*/
	class func handleBackgrounding() {
		let ud = UserDefaults.standard
		let security = Settings.tabSecurity
		let appDelegate = UIApplication.shared.delegate as? AppDelegate
		let controller = appDelegate?.webViewController
		let cookieJar = appDelegate?.cookieJar
		let ocspCache = appDelegate?.certificateAuthentication

		if security == .clearOnBackground {
			controller?.removeAllTabs()
			cookieJar?.clearAllNonWhitelistedData()
		}
		else {
			cookieJar?.clearAllOldNonWhitelistedData()
			ocspCache?.persist()
		}

		if security == .alwaysRemember {
			if let tabs = controller?.webViewTabs() {

				var urls = [URL]()

				for tab in tabs {
					if let url = tab.url {
						urls.append(url)

						print("[\(String(describing: self))] save open tab url=\(url)")
					}
				}

				ud.set(NSKeyedArchiver.archivedData(withRootObject: urls),
					   forKey: openTabs)
			}
		}
		else {
			print("[\(String(describing: self))] clear saved open tab urls")

			ud.removeObject(forKey: openTabs)
		}
	}

	class func restore() {
		let ud = UserDefaults.standard

		if Settings.tabSecurity  == .alwaysRemember,
			let controller = (UIApplication.shared.delegate as? AppDelegate)?.webViewController,
			let data = ud.object(forKey: openTabs) as? Data,
			let urls = NSKeyedUnarchiver.unarchiveObject(with: data) as? [URL] {

			for url in urls {
				print("[\(String(describing: self))] restore tab with url=\(url)")

				controller.addNewTab(for: url, forRestoration: false,
									 with: .hidden, withCompletionBlock: nil)
			}
		}
		else {
			print("[\(String(describing: self))] clear saved open tab urls")

			ud.removeObject(forKey: openTabs)
		}
	}
}
