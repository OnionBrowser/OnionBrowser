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

		// Prefill with current tab's URL.
		if let info = AddSiteViewController.getCurrentTabInfo() {
			urlRow.value = info.url
			navigationItem.rightBarButtonItem?.isEnabled = true
		}

		form
		+++ urlRow
		.onChange { row in
			self.navigationItem.rightBarButtonItem?.isEnabled = row.value != nil
		}
    }
    

	// MARK: Actions

	@objc private func add() {
		if let host = urlRow.value?.host ?? urlRow.value?.path {

			// Create full host settings for this host, if not yet available.
			if !HostSettings.has(host) {
				HostSettings(for: host, withDefaults: true).save().store()
			}

			if var vcs = navigationController?.viewControllers {
				vcs.removeLast()

				let vc = SecurityViewController()
				vc.host = host
				vcs.append(vc)

				navigationController?.setViewControllers(vcs, animated: true)
			}
		}
	}

	/**
	Evaluates the current tab, if it contains a valid URL.

	- returns: nil if current tab contains no valid URL, or the URL and possibly the tab title.
	*/
	public class func getCurrentTabInfo() -> (url: URL, title: String?)? {
		if let tab = AppDelegate.shared().browsingUi?.currentTab,
			let scheme = tab.url.scheme?.lowercased() {

			if scheme == "http" || scheme == "https" {
				return (url: tab.url, title: tab.title)
			}
		}

		return nil
	}
}
