//
//  StartViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 03.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import OrbotKit

class StartViewController: UIViewController, WhyDelegate {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(
				format: NSLocalizedString(
					"Start Tor in %@.",
					comment: "Placeholder is 'Orbot'"),
				OrbotManager.orbot)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = NSLocalizedString("Then come back for private browsing.", comment: "")
		}
	}

	@IBOutlet weak var startTorBt: UIButton! {
		didSet {
			startTorBt.setTitle(buttonTitle)
		}
	}

	@IBOutlet weak var whyBt: UIButton! {
		didSet {
			whyBt.setTitle(NSLocalizedString("Why", comment: ""))
		}
	}


	private var info: OrbotKit.Info? {
		OrbotManager.shared.lastInfo
	}


	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if info?.onionOnly ?? false {
			bodyLb.attributedText = NSAttributedString(
				string: String(
					format: NSLocalizedString(
						"%1$@ runs in onion-only mode. This is dangerous and %2$@ does not support it. Switch it off to use %2$@!",
						comment: "Placeholder 1 is 'Orbot', placeholder 2 is 'Onion Browser'"),
					OrbotManager.orbot, Bundle.main.displayName),
				attributes: [.foregroundColor: UIColor.error!])
		}
	}


	// MARK: WhyDelegate

	var buttonTitle: String {
		if info?.onionOnly ?? false {
			return String(
				format: NSLocalizedString(
					"Go to %@",
					comment: "Placeholder is 'Orbot'"),
				OrbotManager.orbot)
		}

		return NSLocalizedString("Start Tor", comment: "")
	}


	// MARK: Actions

	@IBAction
	func action() {
		if info?.status == .stopped {
			OrbotKit.shared.open(.start)
		}
		else {
			OrbotKit.shared.open(.settings)
		}
	}

	@IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
