//
//  BridgesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BridgesViewController: UIViewController {

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = NSLocalizedString("Connect to Tor for private browsing.", comment: "")
		}
	}

	@IBOutlet weak var explanationLb: UILabel! {
		didSet {
			explanationLb.text = NSLocalizedString(
				"If you are in a country or using a connection that censors Tor, you might need to use bridges.",
				comment: "")
		}
	}

	@IBOutlet weak var connectBt: UIButton! {
		didSet {
			connectBt.setTitle(NSLocalizedString("Connect to Tor", comment: ""))
		}
	}

	@IBOutlet weak var configBt: UIButton! {
		didSet {
			configBt.setTitle(NSLocalizedString("Configure Bridges", comment: ""))
		}
	}

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}


	// MARK: Actions

    @IBAction func connect() {
        AppDelegate.shared?.show(ConnectingViewController())
    }
    
	@IBAction func config() {
		ObBridgesConfViewController.present(from: self)
	}
}
