//
//  BridgeConfViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 14.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class BridgeConfViewController: FixedFormViewController {

	class func present(from: UIViewController) {
		from.present(UINavigationController(rootViewController: BridgeConfViewController()))
	}

	var customBridges: [String]? = nil

	private let bridgesSection: SelectableSection<ListCheckRow<Int>> = {
		let description = [
			NSLocalizedString("If you live in a country that censors Tor, or if you are using a connection that blocks Tor, you can try using bridges to connect.",
							  comment: ""),
			"",
			String(format: NSLocalizedString("%@ obfs4 makes traffic appear \"random\".",
							  comment: ""), "\u{2022}"),
			String(format: NSLocalizedString("%@ meek-azure makes your traffic pose as traffic to a Microsoft website.",
							  comment: ""), "\u{2022}"),
			"",
			NSLocalizedString("If one type of bridge does not work, try using a different one.",
							  comment: "")
			]

		return SelectableSection<ListCheckRow<Int>>(
			header: "", footer: description.joined(separator: "\n"),
			selectionType: .singleSelection(enableDeselection: false))
	}()

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.title = NSLocalizedString("Bridge Configuration", comment: "")
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("Connect", comment: ""), style: .done,
			target: self, action: #selector(connect))

		let bridges = [
			USE_BRIDGES_NONE: NSLocalizedString("No Bridge", comment: ""),
			USE_BRIDGES_OBFS4: String(format: NSLocalizedString("Built-in %@", comment: ""), "obfs4"),
			USE_BRIDGES_MEEKAZURE: String(format: NSLocalizedString("Built-in %@", comment: ""), "meek-azure"),
			USE_BRIDGES_CUSTOM: NSLocalizedString("Custom Bridges", comment: ""),
		]

		let selected = Settings.currentlyUsedBridgesId

		form +++ bridgesSection

		for option in bridges.sorted(by: { $0.key < $1.key }) {
			form.last! <<< ListCheckRow<Int>() {
				$0.title = option.value
				$0.selectableValue = option.key
				$0.value = option.key == selected ? selected : nil
			}
			.onChange({ row in
				if self.bridgesSection.selectedRow()?.value == USE_BRIDGES_CUSTOM {
					self.navigationController?.pushViewController(
						CustomBridgesViewController(), animated: true)
				}
			})
		}
	}

	@objc
	func connect() {
		Settings.currentlyUsedBridgesId = bridgesSection.selectedRow()?.value ?? USE_BRIDGES_NONE

		if presentingViewController is BridgesViewController {
			AppDelegate.shared?.show(ConnectingViewController())
		}
		else {
			// At this point we already have a connection. The bridge reconfiguration is very cheap,
			// so we stay in the browser view and let OnionManager reconfigure in the background.
			// Actually, the reconfiguration can be done completely offline, so we don't have a chance to
			// find out, if another bridge setting (or no bridge) actually works afterwards.
			// The user will find out, when she tries to continue browsing.

			OnionManager.shared.setBridgeConfiguration(bridgesId: Settings.currentlyUsedBridgesId,
													   customBridges: Settings.customBridges)
			OnionManager.shared.startTor(delegate: nil)

			navigationController?.dismiss(animated: true)
		}
	}

	@objc
	private func cancel() {
		dismiss(animated: true)
	}
}
