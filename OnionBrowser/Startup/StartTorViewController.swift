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
import IPtProxyUI_iOS

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

	@IBOutlet weak var statusLb: UILabel!

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

	var transport: IPtProxyUI_Shared.Transport {
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

	var countryCode: String? {
		get {
			Settings.countryCode
		}
		set {
			Settings.countryCode = newValue
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
		statusLb.isHidden = true

		TorManager.shared.start(Settings.transport) { [weak self] progress, summary in
			guard let progress = progress else {
				return
			}

			Task {
				await MainActor.run {
					self?.progressView.setProgress(Float(progress) / 100, animated: true)

					UIAccessibility.post(notification: .announcement, argument: String(format: "%d%%", progress))

					if let summary = summary, !summary.isEmpty {
						self?.statusLb.text = summary
						self?.statusLb.textColor = .label
						self?.statusLb.isHidden = false
					}
					else {
						self?.statusLb.isHidden = true
					}
				}
			}
		} _: { [weak self] error in
			Task {
				guard error == nil else {
					await MainActor.run {
						self?.activityIndicator.isHidden = true
						self?.retryBt.isHidden = false
						self?.statusLb.text = (error ?? TorManager.Errors.noSocksAddr).localizedDescription
						self?.statusLb.textColor = .systemRed
						self?.statusLb.isHidden = false

						UIAccessibility.post(notification: .announcement, argument: self?.statusLb.text)
					}

					return
				}

				await MainActor.run {
					AppDelegate.shared?.allOpenTabs.forEach { tab in
						tab.reinitWebView()
					}

					self?.view.sceneDelegate?.show(OrbotManager.shared.checkStatus())
				}
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
