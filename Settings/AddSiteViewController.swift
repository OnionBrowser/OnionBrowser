//
//  AddSiteViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class AddSiteViewController: FormViewController {

	private var urlRow = URLRow() {
		$0.title = NSLocalizedString("URL", comment: "Option title")
		$0.placeholder = "example.com"
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Add Site", comment: "Scene title")
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .add, target: self, action: #selector(add))
		navigationItem.rightBarButtonItem?.isEnabled = false

		form
		+++ urlRow
		.onChange { row in
			self.navigationItem.rightBarButtonItem?.isEnabled = row.value != nil
		}
    }
    

	// MARK: Actions

	@objc private func add() {
		if let host = urlRow.value?.host ?? urlRow.value?.path {
			HostSettings(forHost: host, withDict: nil)?.save()
			HostSettings.persist()

			navigationController?.popViewController(animated: true)
		}
	}
}
