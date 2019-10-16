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

	private let defaultSettings = HostSettings.default()

	private let securityPresetsRow = SecurityPresetsRow()

	private let contentPolicyRow = PushRow<Option>() {
		$0.title = NSLocalizedString("Content Policy", comment: "Option title")
		$0.selectorTitle = $0.title

		$0.options = [Option(HOST_SETTINGS_CSP_OPEN,
							 NSLocalizedString("Open (normal browsing mode)",
											   comment: "Content policy option")),
					  Option(HOST_SETTINGS_CSP_BLOCK_CONNECT,
							 NSLocalizedString("No XHR/WebSocket/Video connections",
											   comment: "Content policy option")),
					  Option(HOST_SETTINGS_CSP_STRICT,
							 NSLocalizedString("Strict (no JavaScript, video, etc.)",
											   comment: "Content policy option"))]

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

		navigationItem.title = NSLocalizedString("Default Security", comment: "Scene title")

		securityPresetsRow.value = SecurityPreset(defaultSettings)

		if let value = defaultSettings?.settingOrDefault(HOST_SETTINGS_KEY_CSP) {
			contentPolicyRow.value = contentPolicyRow.options?.first { $0.id == value }
		}

		webRtcRow.value = defaultSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_WEBRTC)

		mixedModeRow.value = defaultSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE)


        form
		+++ Section(String(format:
			NSLocalizedString("This is your default security setting for every website you visit in %@.",
							  comment: "Scene description, placeholder will display app name"),
						   Bundle.main.displayName))

		<<< securityPresetsRow
		.onChange { row in
			// Only change other settings, if a non-custom preset was chosen.
			// Do nothing, if it was unselected.
			if let values = row.value?.values {
				self.contentPolicyRow.value = self.contentPolicyRow.options?.first { $0.id == values.csp }
				self.webRtcRow.value = values.webRtc
				self.mixedModeRow.value = values.mixedMode

				self.contentPolicyRow.updateCell()
				self.webRtcRow.updateCell()
				self.mixedModeRow.updateCell()
			}
		}

		+++ Section(footer: NSLocalizedString("Handle tapping on links in a non-standard way to avoid possibly opening external applications",
											  comment: "Option description"))

		<<< contentPolicyRow
		.onChange { row in
			self.defaultSettings?.setSetting(HOST_SETTINGS_KEY_CSP, toValue: row.value?.id)
			self.securityPresetsRow.value = SecurityPreset(self.defaultSettings)
			self.securityPresetsRow.updateCell()
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Universal Link Protection", comment: "Option title")
			$0.value = defaultSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION)
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.defaultSettings?.setSetting(HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
		}

		+++ Section(footer: NSLocalizedString("Allow hosts to access WebRTC functions",
											  comment: "Option description"))

		<<< webRtcRow
		.onChange { row in
			self.defaultSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_WEBRTC,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
			self.securityPresetsRow.value = SecurityPreset(self.defaultSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(footer: NSLocalizedString("Allow HTTPS hosts to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)",
											  comment: "Option description"))

		<<< mixedModeRow
		.onChange { row in
			self.defaultSettings?.setSetting(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE,
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
			self.securityPresetsRow.value = SecurityPreset(self.defaultSettings)
			self.securityPresetsRow.updateCell()
		}

		+++ Section(header: NSLocalizedString("Privacy", comment: "Section title"),
					footer: NSLocalizedString("Allow hosts to permanently store cookies and local storage databases.", comment: "Option description"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow Persistent Cookies", comment: "Option title")
			$0.value = defaultSettings?.boolSettingOrDefault(HOST_SETTINGS_KEY_WHITELIST_COOKIES)
			$0.cell.switchControl.onTintColor = .poeAccent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			self.defaultSettings?.setSetting((HOST_SETTINGS_KEY_WHITELIST_COOKIES),
											 toValue: row.value ?? false ? HOST_SETTINGS_VALUE_YES : HOST_SETTINGS_VALUE_NO)
		}

		+++ Section(NSLocalizedString("Other", comment: "Section title"))

		<<< TextRow() {
			$0.title = NSLocalizedString("User Agent", comment: "Option title")
			$0.value = defaultSettings?.settingOrDefault(HOST_SETTINGS_KEY_USER_AGENT)
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange {row in
			self.defaultSettings?.setSetting(HOST_SETTINGS_KEY_USER_AGENT, toValue: row.value)
		}
    }

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		HostSettings.persist()
	}
}
