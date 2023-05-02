//
//  SettingsViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class SettingsViewController: FixedFormViewController {

	private let defaultSecurityRow = LabelRow() {
		$0.title = NSLocalizedString("Default Security", comment: "Option title")
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}

	private let searchEngineRow = LabelRow() {
		$0.title = NSLocalizedString("Search Engine", comment: "Option title")
		$0.value = Settings.searchEngine.name
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}


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
		+++ defaultSecurityRow
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(
				SecurityViewController(), animated: true)
		}

		+++ Section(header: NSLocalizedString("Search", comment: "Section header"),
					footer: NSLocalizedString("When disabled, all text entered in search bar will be sent to the search engine unless it starts with \"http\".",
											  comment: "Explanation in section footer"))

		<<< searchEngineRow
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(SearchEnginesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Auto-Complete Search Results", comment: "Option title")
			$0.value = Settings.searchLive
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLive = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Stop Auto-Complete at First Dot", comment: "Option title")
			$0.value = Settings.searchLiveStopDot
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLiveStopDot = value
			}
		}

		+++ Section(header: NSLocalizedString("Privacy & Security", comment: "Section header"),
					footer: NSLocalizedString("Choose how long app remembers open tabs.", comment: "Explanation in section footer"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("Custom Site Security", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CustomSitesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Tell websites that you object to processing and selling of your personal data", comment: "Option title")
			$0.value = Settings.sendGpc
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.sendGpc = value
			}
		}

		<<< LabelRow() {
			$0.title = NSLocalizedString("Cookies and Local Storage", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(
				Storage1ViewController(), animated: true)
		}

		<<< SwitchRow() {
			switch SecureEnclave.biometryType() {
			case .touchID:
				$0.title = NSLocalizedString("Lock App with Touch ID or Device Passcode", comment: "")

			case .faceID:
				$0.title = NSLocalizedString("Lock App with Face ID or Device Passcode", comment: "")

			default:
				$0.title = NSLocalizedString("Lock App with Device Passcode", comment: "")
			}

			$0.value = SecureEnclave.loadKey() != nil
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			let newValue: Bool

			if row.value ?? false {
				newValue = SecureEnclave.createKey() != nil
			}
			else {
				newValue = !SecureEnclave.removeKey()
			}

			// Seems, we can't create a key. Maybe running on a simulator?
			if newValue != row.value {
				// Quirky way of disabling the onChange callback to avoid an endless loop.
				self?.form.delegate = nil

				row.value = newValue
				row.updateCell()

				row.disabled = true
				row.evaluateDisabled()

				self?.form.delegate = self // Enable callback again.
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Hide App Content when in Background", comment: "")
			$0.value = Settings.hideContent
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			Settings.hideContent = row.value ?? false
		})

		<<< PushRow<TabSecurity.Level>() {
			$0.title = NSLocalizedString("Tab Security", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = [TabSecurity.Level.alwaysRemember,
						  TabSecurity.Level.forgetOnShutdown,
						  TabSecurity.Level.clearOnBackground]

			$0.value = Settings.tabSecurity

			$0.cell.textLabel?.numberOfLines = 0
		}
		.onPresent { vc, selectorVc in
			// This is just to trigger the usage of #sectionFooterTitleForKey
			selectorVc.sectionKeyForValue = { value in
				return NSLocalizedString("Tab Security", comment: "Option title")
			}

			selectorVc.sectionFooterTitleForKey = { key in
				return NSLocalizedString("Choose how long app remembers open tabs.", comment: "")
			}
		}
		.onChange { row in
			if let value = row.value {
				Settings.tabSecurity = value
			}
		}

		+++ Section(header: NSLocalizedString("Miscellaneous", comment: "Section header"),
					footer: NSLocalizedString("Changing this option requires restarting the app.",
											  comment: "Option explanation"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("URL Blocker", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(URLBlockerRuleController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Mute Audio with Mute Switch", comment: "Option title")
			$0.value = Settings.muteWithSwitch
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.muteWithSwitch = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Disable Bookmarks on Start Page", comment: "Option title")
			$0.value = Settings.disableBookmarksOnStartPage
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			if let value = row.value, value != Settings.disableBookmarksOnStartPage {
				Settings.disableBookmarksOnStartPage = value

				Bookmark.updateStartPage(force: true)

				for tab in AppDelegate.shared?.browsingUi?.tabs ?? [] {
					if tab.url == URL.start {
						tab.refresh()
					}
				}
			}
		})

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow 3rd-Party Keyboards", comment: "Option title")
			$0.value = Settings.thirdPartyKeyboards
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.thirdPartyKeyboards = value
			}
		}


		let section = Section(header: NSLocalizedString("Support", comment: "Section header"),
							  footer: String(
								format: NSLocalizedString("Version %@", comment: "Version info at end of scene"),
								Bundle.main.version))

		form
		+++ section
		<<< ButtonRow() {
			$0.title = NSLocalizedString("Report a Bug", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
		}
		.onCellSelection { [weak self] _, _ in
			AppDelegate.shared?.browsingUi?.addNewTab(
				URL(string: "https://github.com/OnionBrowser/OnionBrowser/issues"),
				transition: .notAnimated)

			self?.dismsiss_()
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
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(DonationViewController(), animated: true)
		}

		<<< ButtonRow() {
			$0.title = NSLocalizedString("About", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
		}
		.onCellSelection { [weak self] _, _ in
			AppDelegate.shared?.browsingUi?.addNewTab(URL.aboutOnionBrowser,
													   transition: .notAnimated)

			self?.dismsiss_()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		defaultSecurityRow.value = SecurityPreset(HostSettings.forDefault()).description
		defaultSecurityRow.updateCell()

		searchEngineRow.value = Settings.searchEngine.name
		searchEngineRow.updateCell()
	}

	@objc private func dismsiss_() {
		navigationController?.dismiss(animated: true)
	}
}
