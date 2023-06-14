//
//  InstallViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 02.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit

class InstallViewController: UIViewController, WhyDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString(
				"Install %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = String(
				format: NSLocalizedString(
					"%1$@ relies on %2$@ for a secure connection to Tor. Install the %2$@ app to continue.",
					comment: "Placeholder 1 is 'Onion Browser', placeholder 2 is 'Orbot'"),
				Bundle.main.displayName,
				OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var getOrbotBt: UIButton! {
		didSet {
			getOrbotBt.setTitle(buttonTitle)
		}
	}

	@IBOutlet weak var whyBt: UIButton! {
		didSet {
			whyBt.setTitle(NSLocalizedString("Why", comment: ""))
		}
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		Settings.orbotWasAlreadyInstalled = false
	}


	// MARK: WhyDelegate

	var buttonTitle: String {
		String(format: NSLocalizedString("Get %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
	}


	// MARK: Actions

	@IBAction
	func action() {
		UIApplication.shared.open(OrbotKit.appStoreLink)
	}

	@IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
