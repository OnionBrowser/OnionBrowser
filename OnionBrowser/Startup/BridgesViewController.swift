//
//  BridgesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BridgesViewController: UIViewController {

	@IBOutlet weak var headerLb: UILabel!
	@IBOutlet weak var explanationLb: UILabel!
	@IBOutlet weak var connectBt: UIButton!
	@IBOutlet weak var configBt: UIButton!

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return .default
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		headerLb.text = NSLocalizedString("Connect to Tor for private browsing.", comment: "")
		explanationLb.text = NSLocalizedString(
			"If you are in a country or using a connection that censors Tor, you might need to use bridges.",
			comment: "")
		connectBt.setTitle(NSLocalizedString("Connect to Tor", comment: ""))
		configBt.setTitle(NSLocalizedString("Configure Bridges", comment: ""))
	}


    @IBAction func connect() {
        AppDelegate.shared?.show(ConnectingViewController())
    }
    
	@IBAction func config() {
		BridgeConfViewController.present(from: self)
	}
}
