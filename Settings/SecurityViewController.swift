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

    enum ContentPolicy: String, CustomStringConvertible {
        case open = "open"
        case blockXhr = "block_connect"
        case strict = "strict"

		var description: String {
			switch self {
			case .open:
				return NSLocalizedString("Open (normal browsing mode)",
				comment: "Content policy option")

			case .blockXhr:
				return NSLocalizedString("No XHR/WebSocket/Video connections",
				comment: "Content policy option")

			default:
				return NSLocalizedString("Strict (no JavaScript, video, etc.)",
				comment: "Content policy option")
			}
		}
    }

	private lazy var hostSettings = host != nil
		? HostSettings.forHost(host)
		: HostSettings.default()

	private let securityPresetsRow = SecurityPresetsRow()

	private let contentPolicyRow = PushRow<ContentPolicy>() {
		$0.title = NSLocalizedString("Content Policy", comment: "Option title")
		$0.selectorTitle = $0.title

		$0.options = [ContentPolicy.open,
					  ContentPolicy.blockXhr,
					  ContentPolicy.strict]

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

		securityPresetsRow.value = SecurityPreset(hostSettings)

		if let value = hostSettings?.settingOrDefault(HOST_SETTINGS_KEY_CSP) {
			contentPolicyRow.value = ContentPolicy(rawValue: value)
		}

		webRtcRow.value = hostSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_WEBRTC)

		mixedModeRow.value = hostSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE)


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
				self.hostSettings?.setSetting(HOST_SETTINGS_KEY_CSP, toValue: values.csp)
				self.hostSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_WEBRTC, toValue: values.webRtc
					? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
				self.hostSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE, toValue: values.mixedMode
					? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)

				self.contentPolicyRow.value = ContentPolicy(rawValue: values.csp)
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
		.onChange { row in
			self.hostSettings?.setSetting(HOST_SETTINGS_KEY_CSP, toValue: row.value?.rawValue)
			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Universal Link Protection", comment: "Option title")
			$0.value = hostSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION)
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.hostSettings?.setSetting(HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
		}

		+++ Section(footer: NSLocalizedString("Allow hosts to access WebRTC functions.",
											  comment: "Option description"))

		<<< webRtcRow
		.onChange { row in
			self.hostSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_WEBRTC,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(footer: NSLocalizedString("Allow HTTPS hosts to load page resources from non-HTTPS hosts. (Useful for RSS readers and other aggregators.)",
											  comment: "Option description"))

		<<< mixedModeRow
		.onChange { row in
			self.hostSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
			self.securityPresetsRow.value = SecurityPreset(self.hostSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(header: NSLocalizedString("Privacy", comment: "Section title"),
					footer: NSLocalizedString("Allow hosts to permanently store cookies and local storage databases.", comment: "Option description"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow Persistent Cookies", comment: "Option title")
			$0.value = hostSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_WHITELIST_COOKIES)
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.hostSettings?.setSetting((HOST_SETTINGS_KEY_WHITELIST_COOKIES),
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
		}

		+++ Section(header: NSLocalizedString("Other", comment: "Section title"),
					footer: NSLocalizedString("Custom user-agent string, or blank to use the default.", comment: "Option description"))

		<<< TextRow() {
			$0.title = NSLocalizedString("User Agent", comment: "Option title")
			$0.value = hostSettings?.settingOrDefault(HOST_SETTINGS_KEY_USER_AGENT)
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange {row in
			self.hostSettings?.setSetting(HOST_SETTINGS_KEY_USER_AGENT, toValue: row.value)
		}
    }

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		HostSettings.persist()
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
}
