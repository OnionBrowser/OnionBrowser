//
//  WelcomeViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 02.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

class WelcomeViewController: UIViewController {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString("Welcome to %@", comment: "Placeholder is 'Onion Browser'"), Bundle.main.displayName)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = NSLocalizedString("You're one step closer to private browsing.", comment: "")
		}
	}

	@IBOutlet weak var nextBt: UIButton! {
		didSet {
			nextBt.setTitle(NSLocalizedString("Next", comment: ""))
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		Settings.didWelcome = true
	}

	@IBAction
	func next() {
		view.sceneDelegate?.show(OrbotManager.shared.checkStatus())
	}
}
