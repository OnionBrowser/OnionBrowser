//
//  AboutSecurityLevelsViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 19.03.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import WebKit

class AboutSecurityLevelsViewController: UIViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done, target: self, action: #selector(done))
		navigationItem.title = NSLocalizedString("Learn More", comment: "")

		let webView = WKWebView()
		webView.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(webView)
		webView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		webView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

		webView.loadFileURL(URL.securityLevels, allowingReadAccessTo: URL.securityLevels)
	}

	@objc private func done() {
		navigationController?.dismiss(animated: true)
	}
}
