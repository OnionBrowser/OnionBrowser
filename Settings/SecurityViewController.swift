//
//  SecurityViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class SecurityViewController: FormViewController {

	var host: String?

	private lazy var hostSettings = host?.isEmpty ?? true
		? HostSettings.forDefault()
		: HostSettings.for(host)

	private let securityPresetsRow = SecurityPresetsRow()

	private let contentPolicyRow = PushRow<HostSettings.ContentPolicy>() {
		$0.title = NSLocalizedString("Content Policy", comment: "Option title")
		$0.selectorTitle = $0.title

		$0.options = [.open, .blockXhr, .strict]

		$0.cell.textLabel?.numberOfLines = 0
	}

	private let webRtcRow = SwitchRow() {
		$0.title = NSLocalizedString("WebRTC", comment: "Option title")
		$0.cell.switchControl.onTintColor = .poeAccent
		$0.cell.textLabel?.numberOfLines = 0
	}

	private let mixedModeRow = SwitchRow() {
		$0.title = NSLocalizedString("Mixed-mode Resources", comment: "Option title")
		$0.cell.switchControl.onTintColor = .poeAccent
		$0.cell.textLabel?.numberOfLines = 0
	}


    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = host ?? NSLocalizedString("Default Security", comment: "Scene title")

		// We're the root here! Provide a means to exit.
		if navigationController?.viewControllers.first == self {
			navigationItem.leftBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .done, target: self,
				action: #selector(_dismiss))
		}

		securityPresetsRow.value = SecurityPreset(hostSettings)

		contentPolicyRow.value = hostSettings.contentPolicy

		webRtcRow.value = hostSettings.webRtc

		mixedModeRow.value = hostSettings.mixedMode


        form
		+++ (host != nil ? Section() : Section("to be replaced in #willDisplayHeaderView to avoid capitalization"))

		<<< securityPresetsRow
		.onChange { row in
			// Only change other settings, if a non-custom preset was chosen.
			// Do nothing, if it was unselected.
			if let values = row.value?.values {

				// Force-set this, because #onChange callbacks are only called,
				// when values actually change. So this might lead to a host
				// still being configured for default values, although these should
				// be set hard.
				self.hostSettings.contentPolicy = values.csp
				self.hostSettings.webRtc = values.webRtc
				self.hostSettings.mixedMode = values.mixedMode

				self.contentPolicyRow.value = values.csp
				self.webRtcRow.value = values.webRtc
				self.mixedModeRow.value = values.mixedMode

				self.contentPolicyRow.updateCell()
				self.webRtcRow.updateCell()
				self.mixedModeRow.updateCell()
			}
		}

		+++ Section(footer: NSLocalizedString("Handle tapping on links in a non-standard way to avoid possibly opening external applications.",
											  comment: "Option description"))

		<<< contentPolicyRow
		.onPresent { vc, selectorVc in
			// This is just to trigger the usage of #sectionFooterTitleForKey
			selectorVc.sectionKeyForValue = { value in
				return NSLocalizedString("Content Policy", comment: "Option title")
			}

			selectorVc.sectionFooterTitleForKey = { key in
				return NSLocalizedString("Restrictions on resources loaded from web pages.",
										 comment: "Option description")
			}
		}
		.onChange { row in
			self.hostSettings.contentPolicy = row.value ?? .strict
			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Universal Link Protection", comment: "Option title")
			$0.value = hostSettings.universalLinkProtection
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.hostSettings.universalLinkProtection = row.value ?? false
		}

		+++ Section(footer: NSLocalizedString("Allow hosts to access WebRTC functions.",
											  comment: "Option description"))

		<<< webRtcRow
		.onChange { row in
			self.hostSettings.webRtc = row.value ?? false

			// Cannot have WebRTC while blocking everything besides images and styles.
			// So need to lift restrictions there, too.
			if row.value ?? false && self.contentPolicyRow.value == .strict {
				self.contentPolicyRow.value = .blockXhr
				self.contentPolicyRow.updateCell()
			}

			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(footer: NSLocalizedString("Allow HTTPS hosts to load page resources from non-HTTPS hosts. (Useful for RSS readers and other aggregators.)",
											  comment: "Option description"))

		<<< mixedModeRow
		.onChange { row in
			self.hostSettings.mixedMode = row.value ?? false
			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(header: NSLocalizedString("Privacy", comment: "Section title"),
					footer: NSLocalizedString("Allow hosts to permanently store cookies and local storage databases.", comment: "Option description"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow Persistent Cookies", comment: "Option title")
			$0.value = hostSettings.whitelistCookies
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.hostSettings.whitelistCookies = row.value ?? false
		}

		let section = Section(header: NSLocalizedString("Other", comment: "Section title"),
							  footer: NSLocalizedString("Custom user-agent string, or blank to use the default.",
														comment: "Option description"))

		form
		+++ section

		if hostSettings.ignoreTlsErrors {
			section
			<<< SwitchRow() {
				$0.title = NSLocalizedString("Ignore TLS Errors", comment: "Option title")
				$0.value = hostSettings.ignoreTlsErrors
				$0.cell.switchControl.onTintColor = .poeAccent
				$0.cell.textLabel?.numberOfLines = 0
			}
			.onChange { row in
				self.hostSettings.ignoreTlsErrors = false

				row.cell.switchControl.isEnabled = false
			}
		}

		section
		<<< TextRow() {
			$0.title = NSLocalizedString("User Agent", comment: "Option title")
			$0.value = hostSettings.userAgent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange {row in
			self.hostSettings.userAgent = row.value ?? ""
		}
    }

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		hostSettings.save().store()
	}


	// MARK: UITableViewDelegate

	/**
	Workaround to avoid capitalization of header.
	*/
	func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		if section == 0,
			let header = view as? UITableViewHeaderFooterView {

			header.textLabel?.text = String(format:
				NSLocalizedString("This is your default security setting for every website you visit in %@.",
								  comment: "Scene description, placeholder will contain app name"),
											Bundle.main.displayName)
		}
	}


	// MARK: Private Methods

	@objc
	private func _dismiss() {
		dismiss(animated: true)
	}
}
