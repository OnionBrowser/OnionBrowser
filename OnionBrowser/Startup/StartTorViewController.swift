//
//  StartTorViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.10.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI

class StartTorViewController: UIViewController, BridgesConfDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = NSLocalizedString("Starting Tor…", comment: "")
		}
	}

	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!

	@IBOutlet weak var retryBt: UIButton! {
		didSet {
			retryBt.setTitle(NSLocalizedString("Retry", comment: ""))
		}
	}

	@IBOutlet weak var progressView: UIProgressView!

	@IBOutlet weak var errorLb: UILabel!

	@IBOutlet weak var bridgesBt: UIButton! {
		didSet {
			bridgesBt.setTitle(NSLocalizedString("Configure Bridges", comment: ""))
		}
	}


	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		retry()
	}


	// MARK: BridgesConfDelegate

	var transport: IPtProxyUI.Transport {
		get {
			Settings.transport
		}
		set {
			Settings.transport = newValue
		}
	}

	var customBridges: [String]? {
		get {
			Settings.customBridges
		}
		set {
			Settings.customBridges = newValue
		}
	}

	func save() {
		TorManager.shared.updateConfig(Settings.transport)
	}


	// MARK: Actions

	@IBAction
	func retry() {
		activityIndicator.isHidden = false
		retryBt.isHidden = true
		progressView.progress = 0
		errorLb.isHidden = true

		TorManager.shared.start(Settings.transport) { [weak self] progress in
			guard let progress = progress else {
				return
			}

			DispatchQueue.main.async {
				self?.progressView.setProgress(Float(progress) / 100, animated: true)
			}
		} _: { [weak self] error in
			guard error == nil else {
				DispatchQueue.main.async {
					self?.activityIndicator.isHidden = true
					self?.retryBt.isHidden = false
					self?.errorLb.text = (error ?? TorManager.Errors.noSocksAddr).localizedDescription
					self?.errorLb.isHidden = false
				}

				return
			}

			DispatchQueue.main.async {
				AppDelegate.shared?.allOpenTabs.forEach { tab in
					tab.reinitWebView()
				}

				self?.view.sceneDelegate?.show(OrbotManager.shared.checkStatus())
			}
		}
	}

	@IBAction
	func configureBridges() {
		let vc = BridgesConfViewController()
		vc.delegate = self

		present(UINavigationController(rootViewController: vc))
	}
}
