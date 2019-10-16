//
//  SettingsViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import POE

struct Option: CustomStringConvertible, Equatable {

	let id: String

	var description: String

	init(_ id: String, _ title: String? = nil) {
		self.id = id
		description = title ?? ""
	}

	// MARK: Equatable

	static func ==(lhs: Option, rhs: Option) -> Bool {
		return lhs.id == rhs.id
	}
}

class SettingsViewController: FormViewController {

	private let userDefaults = UserDefaults.standard

    @objc
	class func instantiate() -> UINavigationController {
		return UINavigationController(rootViewController: self.init())
	}

	override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done, target: self, action: #selector(dismsiss_))
		navigationItem.title = NSLocalizedString("Settings", comment: "Scene title")

		form
		+++ Section(header: NSLocalizedString("Search", comment: "Section header"),
					footer: NSLocalizedString("When disabled, all text entered in search bar will be sent to the search engine unless it starts with \"http\"",
											  comment: "Explanation in section footer"))

		<<< PushRow<String>() {
			$0.title = NSLocalizedString("Search Engine", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = (AppDelegate.shared()?.searchEngines.allKeys as? [String])?.sorted()
			$0.value = userDefaults.object(forKey: "search_engine") as? String
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.userDefaults.set(row.value ?? AppDelegate.shared()?.searchEngines.allKeys.first,
								  forKey: "search_engine")
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Auto-Complete Search Results", comment: "Option title")
			$0.value = userDefaults.bool(forKey: "search_engine_live")
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.userDefaults.set(row.value ?? false, forKey: "search_engine_live")
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Stop Auto-Complete at First Dot", comment: "Option title")
			$0.value = userDefaults.bool(forKey: "search_engine_stop_dot")
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.userDefaults.set(row.value ?? true, forKey: "search_engine_stop_dot")
		}

		+++ Section(header: NSLocalizedString("Privacy & Security", comment: "Section header"),
					footer: NSLocalizedString("Choose, how long app remembers open tabs.", comment: "Explanation in section footer"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Send Do-Not-Track Header", comment: "Option title")
			$0.value = userDefaults.bool(forKey: "send_dnt")
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.userDefaults.set(row.value ?? false, forKey: "send_dnt")
		}

		<<< LabelRow() {
			$0.title = NSLocalizedString("Edit Local Storage", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
		}
		.onCellSelection { _, _ in
			self.navigationController?.pushViewController(
				StorageViewController(type: .localStorage), animated: true)
		}

		<<< LabelRow() {
			$0.title = NSLocalizedString("Edit Cookies", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
		}
		.onCellSelection { _, _ in
			self.navigationController?.pushViewController(
				StorageViewController(type: .cookies), animated: true)
		}

		<<< PushRow<Option>() {
			$0.title = NSLocalizedString("TLS Version", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = [Option("tls_12", NSLocalizedString("TLS 1.2 Only", comment: "Option")),
						  Option("tls_10", NSLocalizedString("TLS 1.2, 1.1 or 1.0", comment: "Option"))]

			if let value = userDefaults.object(forKey: "tls_version") as? String {
				$0.value = $0.options?.first { $0.id == value }
			}

			$0.cell.textLabel?.numberOfLines = 0
		}
		.onPresent { vc, selectorVc in
			print("[\(String(describing: type(of: self)))] selectorVc=\(selectorVc)")

			// This is just to trigger the usage of #sectionFooterTitleForKey
			selectorVc.sectionKeyForValue = { value in
				return NSLocalizedString("TLS Version", comment: "Option title")
			}

			selectorVc.sectionFooterTitleForKey = { key in
				return NSLocalizedString("Minimum version of TLS required for hosts to negotiate HTTPS connections.", comment: "Option description")
			}
		}
		.onChange { row in
			self.userDefaults.set(row.value?.id ?? "tls_12", forKey: "tls_version")
		}

		<<< PushRow<Option>() {
			$0.title = NSLocalizedString("Tab Security", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = [Option("always_remember", NSLocalizedString("Remember Tabs", comment: "")),
						  Option("forget_on_shutdown", NSLocalizedString("Forget at Shutdown", comment: "")),
						  Option("clear_on_background", NSLocalizedString("Forget in Background", comment: ""))]

			if let value = userDefaults.object(forKey: "tab_security") as? String {
				$0.value = $0.options?.first { $0.id == value }
			}

			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.userDefaults.set(row.value?.id ?? "forget_on_shutdown", forKey: "tab_security")
		}

		let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"

		let section = Section(header: NSLocalizedString("Support", comment: "Section header"),
							  footer: String(format: NSLocalizedString(
								"Version %@", comment: "Version info at end of scene"), version))

		form
		+++ section
		<<< ButtonRow() {
			$0.title = NSLocalizedString("Report a Bug", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
		}
		.onCellSelection { _, _ in
			AppDelegate.shared()?.webViewController.addNewTab(
				for: URL(string: "https://github.com/OnionBrowser/OnionBrowser/issues"),
				forRestoration: false, with: .quick, withCompletionBlock: nil)

			self.dismsiss_()
		}

		if let url = URL(string: "itms-apps://itunes.apple.com/app/id519296448"),
			UIApplication.shared.canOpenURL(url) {

			section
			<<< ButtonRow() {
				$0.title = NSLocalizedString("Rate on App Store", comment: "Button title")
				$0.cell.textLabel?.numberOfLines = 0
			}
			.cellUpdate { cell, _ in
				cell.textLabel?.textAlignment = .natural
			}
			.onCellSelection { _, _ in
				UIApplication.shared.open(url, options: [:])
			}
		}

		section
		<<< LabelRow() {
			$0.title = NSLocalizedString("Fund Development", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
		}
		.onCellSelection { _, _ in
			self.navigationController?.pushViewController(DonationViewController(), animated: true)
		}

		<<< ButtonRow() {
			$0.title = NSLocalizedString("About", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
		}
		.onCellSelection { _, _ in
			AppDelegate.shared()?.webViewController.addNewTab(
				for: URL(string: ABOUT_ONION_BROWSER), forRestoration: false,
				with: .quick, withCompletionBlock: nil)

			self.dismsiss_()
		}
    }

	@objc private func dismsiss_() {
		navigationController?.dismiss(animated: true)
	}
}
