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

@objc class TabSecurity: NSObject {

	private static let tabSecurity = "tab_security"
	private static let alwaysRemember = "always_remember"
	private static let forgetOnShutdown = "forget_on_shutdown"
	private static let clearOnBackground = "clear_on_background"
	private static let openTabs = "open_tabs"

	@objc class var isClearOnBackground: Bool {
		return UserDefaults.standard.object(forKey: tabSecurity) as? String ?? forgetOnShutdown == clearOnBackground
	}

	/**
	Handle tab privacy
	*/
	@objc class func handleBackgrounding() {
		let ud = UserDefaults.standard
		let security = ud.object(forKey: tabSecurity) as? String ?? forgetOnShutdown
		let appDelegate = UIApplication.shared.delegate as? AppDelegate
		let controller = appDelegate?.webViewController
		let cookieJar = appDelegate?.cookieJar

		if security == clearOnBackground {
			controller?.removeAllTabs()
			cookieJar?.clearAllNonWhitelistedData()
		}
		else {
			cookieJar?.clearAllOldNonWhitelistedData()
		}

		if security == alwaysRemember {
			if let tabs = controller?.webViewTabs() as? [WebViewTab] {

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

	@objc class func restore() {
		let ud = UserDefaults.standard

		if let tabSecurity = ud.object(forKey: tabSecurity) as? String,
			tabSecurity == alwaysRemember,
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
