//
//  MainViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class MainViewController: UIViewController {

	@IBOutlet weak var claimLb: UILabel!
	@IBOutlet weak var actionLb: UILabel!

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		if Settings.didIntro {
			let vc = ConnectingViewController()
			vc.autoClose = true

			AppDelegate.shared?.show(vc)

			return
		}

		claimLb.text = NSLocalizedString("Free to be you.", comment: "")

		let rtl = UIView.userInterfaceLayoutDirection(for: actionLb.semanticContentAttribute) == .rightToLeft
		actionLb.text = String(format: NSLocalizedString("Let's go %@", comment: ""),
							   rtl ? "\u{276c}" : "\u{276d}") // Angle bracket
	}


	@IBAction func showNext() {
		AppDelegate.shared?.show(BridgesViewController())
	}
}
