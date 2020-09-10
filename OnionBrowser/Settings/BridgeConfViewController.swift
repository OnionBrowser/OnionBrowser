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

protocol BridgeConfDelegate: class {

	var bridgesType: Settings.BridgesType { get set }

	var customBridges: [String]? { get set }

	func connect()
}

class BridgeConfViewController: FixedFormViewController, UINavigationControllerDelegate,
BridgeConfDelegate {

	class func present(from: UIViewController) {
		from.present(UINavigationController(rootViewController: BridgeConfViewController()))
	}

	private let bridgesSection: SelectableSection<ListCheckRow<Settings.BridgesType>> = {
		let description = [
			NSLocalizedString("If you are in a country or using a connection that censors Tor, you might need to use bridges.",
							  comment: ""),
			"",
			String(format: NSLocalizedString("%1$@ %2$@ makes your traffic appear \"random\".",
							  comment: ""), "\u{2022}", "obfs4"),
			String(format: NSLocalizedString("%1$@ %2$@ makes your traffic pose as traffic to a Microsoft website.",
							  comment: ""), "\u{2022}", "meek-azure"),
			"",
			NSLocalizedString("If one type of bridge does not work, try using a different one.",
							  comment: "")
			]

		return SelectableSection<ListCheckRow<Settings.BridgesType>>(
			header: "", footer: description.joined(separator: "\n"),
			selectionType: .singleSelection(enableDeselection: false))
	}()

	var bridgesType = Settings.currentlyUsedBridges {
		didSet {
			for row in bridgesSection {
				if (row as? ListCheckRow<Settings.BridgesType>)?.value == bridgesType {
					row.select()
				}
				else {
					row.deselect()
				}
			}
		}
	}

	var customBridges = Settings.customBridges

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationController?.delegate = self

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
		navigationItem.title = NSLocalizedString("Bridge Configuration", comment: "")
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("Connect", comment: ""), style: .done,
			target: self, action: #selector(connect))

		let bridges: [Settings.BridgesType: String] = [
			.none: NSLocalizedString("No Bridges", comment: ""),
			.obfs4: String(format: NSLocalizedString("Built-in %@", comment: ""), "obfs4"),
			.meekazure: String(format: NSLocalizedString("Built-in %@", comment: ""), "meek-azure"),
			.snowflake: String(format: NSLocalizedString("Built-in %@", comment: ""), "snowflake"),
			.custom: NSLocalizedString("Custom Bridges", comment: ""),
		]

		bridgesSection.onSelectSelectableRow = { [weak self] _, row in
			if row.value == .custom {
				let vc = CustomBridgesViewController()
				vc.delegate = self

				self?.navigationController?.pushViewController(vc, animated: true)
			}
		}

		form
			+++ ButtonRow() {
				$0.title = NSLocalizedString("Request Bridges from torproject.org", comment: "")
			}
			.onCellSelection { [weak self] _, _ in
				let vc = MoatViewController()
				vc.delegate = self

				self?.navigationController?.pushViewController(vc, animated: true)
			}

			+++ bridgesSection

		for option in bridges.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
			form.last! <<< ListCheckRow<Settings.BridgesType>() {
				$0.title = option.value
				$0.selectableValue = option.key
				$0.value = option.key == bridgesType ? bridgesType : nil
			}
		}

		if Settings.advancedTorConf?.count ?? 0 > 0 {
			let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 0))
			toolbar.translatesAutoresizingMaskIntoConstraints = false
			toolbar.sizeToFit() // Stupid workaround to avoid NSLayoutConstraint issues.

			let button = UIBarButtonItem(title: NSLocalizedString("Remove Advanced Tor Conf", comment: ""),
										 style: .plain, target: self, action: #selector(removeAdvancedTorConf))
			toolbar.setItems([button], animated: false)

			view.addSubview(toolbar)
			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
			toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
			toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
		}
	}


	// MARK: UINavigationControllerDelegate

	func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
		guard viewController == self else {
			return
		}

		for row in bridgesSection.allRows as? [ListCheckRow<Settings.BridgesType>] ?? [] {
			row.value = row.selectableValue == bridgesType ? bridgesType : nil
		}
	}


	// MARK: Actions

	@objc
	func connect() {
		Settings.currentlyUsedBridges = bridgesSection.selectedRow()?.value ?? .none
		Settings.customBridges = customBridges

		if presentingViewController is BridgesViewController {
			AppDelegate.shared?.show(ConnectingViewController())
		}
		else {
			// At this point we already have a connection. The bridge reconfiguration is very cheap,
			// so we stay in the browser view and let OnionManager reconfigure in the background.
			// Actually, the reconfiguration can be done completely offline, so we don't have a chance to
			// find out, if another bridge setting (or no bridge) actually works afterwards.
			// The user will find out, when she tries to continue browsing.

			OnionManager.shared.setBridgeConfiguration(bridgesType: Settings.currentlyUsedBridges,
													   customBridges: Settings.customBridges)
			OnionManager.shared.startTor(delegate: nil)

			navigationController?.dismiss(animated: true)
		}
	}

	@objc
	private func cancel() {
		dismiss(animated: true)
	}

	@objc
	private func removeAdvancedTorConf() {
		Settings.advancedTorConf = nil

		AlertHelper.present(self, message: NSLocalizedString("Quit. Then restart the app.", comment: ""),
							title: NSLocalizedString("Advanced Tor Configuration Removed", comment: ""))
	}
}
