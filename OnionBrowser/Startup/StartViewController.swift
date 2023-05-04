//
//  StartViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 03.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import OrbotKit

class StartViewController: UIViewController, WhyDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString("Start Tor in %@.", comment: ""),
								  InstallViewController.orbot)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = NSLocalizedString("Then come back for private browsing.", comment: "")
		}
	}

	@IBOutlet weak var startTorBt: UIButton! {
		didSet {
			startTorBt.setTitle(buttonTitle)
		}
	}

	@IBOutlet weak var whyBt: UIButton! {
		didSet {
			whyBt.setTitle(NSLocalizedString("Why", comment: ""))
		}
	}


	// MARK: WhyDelegate

	var buttonTitle: String {
		NSLocalizedString("Start Tor", comment: "")
	}


	// MARK: Actions

	@IBAction
	func action() {
		OrbotKit.shared.open(.start)
	}

	@IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
