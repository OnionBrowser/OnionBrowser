//
//  SecurityViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import SDCAlertView

class SecurityViewController: FixedFormViewController {

	var host: String?


	private static let uaStrings = NSDictionary(contentsOfFile: Bundle.main.path(forResource: "ua-strings", ofType: "plist")!) as! [String: String]


	private lazy var hostSettings = host?.isEmpty ?? true
		? HostSettings.forDefault()
		: HostSettings.for(host)

	private let securityPresetsRow = SecurityPresetsRow()

	private let javaScriptRow = SwitchRow() {
		$0.title = NSLocalizedString("Allow JavaScript", comment: "Option title")
		$0.cell.switchControl.onTintColor = .accent
		$0.cell.textLabel?.numberOfLines = 0
	}

	private let orientationAndMotionRow = SwitchRow() {
		$0.title = NSLocalizedString("Allow Access to Orientation and Motion Data", comment: "Option title")
		$0.cell.switchControl.onTintColor = .accent
		$0.cell.textLabel?.numberOfLines = 0
	}

	private let mediaCaptureRow = SwitchRow() {
		$0.title = NSLocalizedString("Allow Access to Microphone and Video", comment: "Option title")
		$0.cell.switchControl.onTintColor = .accent
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

		javaScriptRow.value = hostSettings.javaScript
		orientationAndMotionRow.value = hostSettings.orientationAndMotion
		mediaCaptureRow.value = hostSettings.mediaCapture


		form
		+++ (host != nil ? Section() : Section("to be replaced in #willDisplayHeaderView to avoid capitalization"))

		<<< securityPresetsRow
		.onChange { [weak self] row in
			// Only change other settings, if a non-custom preset was chosen.
			// Do nothing, if it was unselected.
			if let values = row.value?.values {

				// Force-set this, because #onChange callbacks are only called,
				// when values actually change. So this might lead to a host
				// still being configured for default values, although these should
				// be set hard.
				self?.hostSettings.javaScript = values.javaScript
				self?.hostSettings.orientationAndMotion = values.orientationAndMotion
				self?.hostSettings.mediaCapture = values.mediaCapture

				self?.javaScriptRow.value = values.javaScript
				self?.orientationAndMotionRow.value = values.orientationAndMotion
				self?.mediaCaptureRow.value = values.mediaCapture

				self?.javaScriptRow.updateCell()
				self?.orientationAndMotionRow.updateCell()
				self?.mediaCaptureRow.updateCell()
			}
		}

		+++ javaScriptRow
		.onChange { [weak self] row in
			guard let hostSettings = self?.hostSettings else {
				return
			}

			self?.alertBeforeChange(
				row.value ?? false,
				hostSettings.orientationAndMotion,
				hostSettings.mediaCapture)
		}

		<<< orientationAndMotionRow
		.onChange { [weak self] row in
			guard let hostSettings = self?.hostSettings else {
				return
			}

			self?.alertBeforeChange(
				hostSettings.javaScript,
				row.value ?? false,
				hostSettings.mediaCapture)
		}

		<<< mediaCaptureRow
		.onChange { [weak self] row in
			guard let hostSettings = self?.hostSettings else {
				return
			}

			self?.alertBeforeChange(
				hostSettings.javaScript,
				hostSettings.orientationAndMotion,
				row.value ?? false)
		}

		+++ Section(footer: NSLocalizedString("Handle tapping on links in a non-standard way to avoid possibly opening external applications.",
											  comment: "Option description"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Universal Link Protection", comment: "Option title")
			$0.value = hostSettings.universalLinkProtection
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			self?.hostSettings.universalLinkProtection = row.value ?? false
		}

		+++ Section(header: NSLocalizedString("Privacy", comment: "Section title"),
					footer: NSLocalizedString("Allow hosts to permanently store cookies and local storage databases.", comment: "Option description"))

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow Persistent Cookies", comment: "Option title")
			$0.value = hostSettings.whitelistCookies
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			self?.hostSettings.whitelistCookies = row.value ?? false
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
				$0.cell.switchControl.onTintColor = .accent
				$0.cell.textLabel?.numberOfLines = 0
			}
			.onChange { [weak self] row in
				self?.hostSettings.ignoreTlsErrors = false

				row.cell.switchControl.isEnabled = false
			}
		}

		section
		<<< SwitchRow() {
			$0.title = NSLocalizedString("Follow Onion-Location Header Automatically", comment: "")
			$0.value = hostSettings.followOnionLocationHeader
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			self?.hostSettings.followOnionLocationHeader = row.value ?? false
		}

		let uaRow = TextRow() {
			$0.title = NSLocalizedString("User Agent", comment: "Option title")
			$0.value = hostSettings.userAgent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textField.clearButtonMode = .whileEditing
		}
		.onChange { [weak self] row in
			self?.hostSettings.userAgent = row.value ?? ""
		}

		section
		<<< uaRow

		if !SecurityViewController.uaStrings.isEmpty {
			let section = Section(
				header: NSLocalizedString("Popular User Agents", comment: ""),
				footer: NSLocalizedString("These might change server behaviour. E.g. show or not show Captchas or return pages meant for desktop browsers.", comment: ""))

			form
			+++ section

			for key in SecurityViewController.uaStrings.keys.sorted() {
				section
				<<< ButtonRow() {
					$0.title = key
					$0.value = SecurityViewController.uaStrings[key]
				}
				.onCellSelection({ _, row in
					uaRow.value = row.value
					uaRow.updateCell()
				})
			}
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

	private var calledTwice = false

	private func alertBeforeChange(_ javaScript: Bool, _ orientationAndMotion: Bool, _ mediaCapture: Bool) {

		let preset = SecurityPreset(javaScript, orientationAndMotion, mediaCapture)

		let okHandler = { [weak self] in
			self?.hostSettings.javaScript = javaScript
			self?.hostSettings.orientationAndMotion = orientationAndMotion
			self?.hostSettings.mediaCapture = mediaCapture

			self?.securityPresetsRow.value = SecurityPreset(self?.hostSettings)
			self?.securityPresetsRow.updateCell()
		}

		if !calledTwice && preset == .custom && securityPresetsRow.value != .custom {
			let cancelHandler = { [weak self] in
				self?.javaScriptRow.value = self?.hostSettings.javaScript
				self?.orientationAndMotionRow.value = self?.hostSettings.orientationAndMotion
				self?.mediaCaptureRow.value = self?.hostSettings.mediaCapture

				self?.javaScriptRow.updateCell()
				self?.orientationAndMotionRow.updateCell()
				self?.mediaCaptureRow.updateCell()

				self?.calledTwice = false
			}

			let alert = AlertController(title: nil, message: nil)
			let cv = alert.contentView

			let illustration = UIImageView(image: UIImage(named: "custom-shield"))
            illustration.translatesAutoresizingMaskIntoConstraints = false
			cv.addSubview(illustration)
			illustration.topAnchor.constraint(equalTo: cv.topAnchor, constant: -16).isActive = true
			illustration.widthAnchor.constraint(equalToConstant: 24).isActive = true
			illustration.heightAnchor.constraint(equalToConstant: 30).isActive = true
			illustration.centerXAnchor.constraint(equalTo: cv.centerXAnchor).isActive = true

			let message = UILabel()
			message.translatesAutoresizingMaskIntoConstraints = false
			message.text = NSLocalizedString("By editing this setting, you have created a custom security setting.", comment: "")
			message.font = .boldSystemFont(ofSize: 16)
			message.textAlignment = .center
			message.numberOfLines = 0
			cv.addSubview(message)
			message.topAnchor.constraint(equalTo: illustration.bottomAnchor, constant: 8).isActive = true
			message.leftAnchor.constraint(equalTo: cv.leftAnchor).isActive = true
			message.rightAnchor.constraint(equalTo: cv.rightAnchor).isActive = true
			message.bottomAnchor.constraint(equalTo: cv.bottomAnchor, constant: -16).isActive = true

			alert.addAction(AlertAction(
				title: NSLocalizedString("Cancel", comment: ""), style: .preferred,
				handler: { _ in cancelHandler() }))
			alert.addAction(AlertAction(
				title: NSLocalizedString("OK", comment: ""), style: .normal,
				handler: { _ in okHandler() }))

			present(alert)
		}
		else {
			okHandler()
			calledTwice = false
		}
	}
}
