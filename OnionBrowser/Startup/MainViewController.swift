//
//  MainViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class MainViewController: UIViewController {

	@IBOutlet weak var claimLb: UILabel! {
		didSet {
			claimLb.text = NSLocalizedString("Free to be you.", comment: "")
		}
	}
	
	@IBOutlet weak var actionLb: UILabel! {
		didSet {
			let rtl = UIView.userInterfaceLayoutDirection(for: actionLb.semanticContentAttribute) == .rightToLeft
			actionLb.text = String(format: NSLocalizedString("Let's go %@", comment: ""),
								   rtl ? "\u{276c}" : "\u{276d}") // Angle bracket
		}
	}

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		if Settings.didIntro {
			let vc = ConnectingViewController()
			vc.autoClose = true

			AppDelegate.shared?.show(vc)
		}
	}


	@IBAction func showNext() {
		AppDelegate.shared?.show(BridgesViewController())
	}
}
