//
//  StartOrbotViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 03.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit

class StartOrbotViewController: UIViewController, WhyDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(
				format: NSLocalizedString(
					"Start Tor in %@.",
					comment: "Placeholder is 'Orbot'"),
				OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = NSLocalizedString("Then come back for private browsing.", comment: "")
		}
	}

	@IBOutlet weak var startOrbotBt: UIButton! {
		didSet {
			startOrbotBt.setTitle(buttonTitle1)

			if !onionOnly, #available(iOS 17.0, *) {
			}
			else {
				if let superview = startOrbotBt.superview {
					startOrbotBt.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
				}
			}
		}
	}

	@IBOutlet weak var startBuiltInTorBt: UIButton! {
		didSet {
			if !onionOnly, #available(iOS 17.0, *) {
				startBuiltInTorBt.setTitle(buttonTitle2)
			}
			else {
				startBuiltInTorBt.isHidden = true
				startBuiltInTorBt.constraints
					.first(where: { $0.firstAttribute == .width })?
					.constant = 0
			}
		}
	}

	@IBOutlet weak var whyBt: UIButton! {
		didSet {
			whyBt.setTitle(NSLocalizedString("Why", comment: ""))
		}
	}


	private var info: OrbotKit.Info? {
		OrbotManager.shared.lastInfo
	}

	private var onionOnly: Bool {
		info?.onionOnly ?? false
	}


	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if onionOnly {
			bodyLb.attributedText = NSAttributedString(
				string: String(
					format: NSLocalizedString(
						"%1$@ runs in onion-only mode. This is dangerous and %2$@ does not support it. Switch it off to use %2$@!",
						comment: "Placeholder 1 is 'Orbot', placeholder 2 is 'Onion Browser'"),
					OrbotKit.orbotName, Bundle.main.displayName),
				attributes: [.foregroundColor: UIColor.error!])
		}
	}


	// MARK: WhyDelegate

	var buttonTitle1: String {
		if info?.onionOnly ?? false {
			return String(
				format: NSLocalizedString(
					"Go to %@",
					comment: "Placeholder is 'Orbot'"),
				OrbotKit.orbotName)
		}

		return String(format: NSLocalizedString("Start %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
	}

	var buttonTitle2: String? {
		onionOnly ? nil : NSLocalizedString("Start built-in Tor", comment: "")
	}

	func run(useBuiltInTor: Bool) {
		Settings.useBuiltInTor = useBuiltInTor

		if useBuiltInTor {
			view.sceneDelegate?.show(OrbotManager.shared.checkStatus())
		}
		else {
			if info?.status == .stopped {
				// Tabs where already initialized but blocked. They'll need a refresh
				// when the user comes back.
				AppDelegate.shared?.allOpenTabs.forEach { $0.needsRefresh = true }

				OrbotKit.shared.open(.start(callback: URL(string: "onionbrowser:main")))
			}
			else {
				OrbotKit.shared.open(.settings)
			}
		}
	}


	// MARK: Actions

	@IBAction
	func action(_ sender: UIButton!) {
		run(useBuiltInTor: sender == startBuiltInTorBt)
	}

	@IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
