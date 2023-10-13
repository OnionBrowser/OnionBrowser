//
//  OrbotOrBuiltInViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.10.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit

class OrbotOrBuiltInViewController: UIViewController, WhyDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString(
				"%@ or built-in Tor", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = String(
				format: NSLocalizedString(
					"%1$@ can either rely on %2$@ for a secure connection to Tor or run its own built-in Tor. The built-in Tor has security problems.",
					comment: "Placeholder 1 is 'Onion Browser', placeholder 2 is 'Orbot'"),
				Bundle.main.displayName,
				OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var useOrbotBt: UIButton! {
		didSet {
			useOrbotBt.setTitle(buttonTitle1)
		}
	}

	@IBOutlet weak var useBuiltInTor: UIButton! {
		didSet {
			useBuiltInTor.setTitle(buttonTitle2)
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

	var buttonTitle1: String {
		String(format: NSLocalizedString("Use %@", comment: "Placeholder is 'Orbot'"), OrbotKit.orbotName)
	}

	var buttonTitle2: String? {
		NSLocalizedString("Use built-in Tor", comment: "")
	}

	func run(useBuiltInTor: Bool) {
		Settings.useBuiltInTor = useBuiltInTor

		view.sceneDelegate?.show(OrbotManager.shared.checkStatus())
	}


	// MARK: Actions

    @IBAction 
	func action(_ sender: UIButton) {
		run(useBuiltInTor: sender == useBuiltInTor)
    }

    @IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
