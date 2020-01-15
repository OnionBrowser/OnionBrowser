//
//  ErrorViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 11.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class ErrorViewController: UIViewController {

	@IBOutlet weak var messageLb: UILabel! {
		didSet {
			messageLb.text = NSLocalizedString("Looks like we got stuck! Quit. Then restart the app.", comment: "")
		}
	}
}
