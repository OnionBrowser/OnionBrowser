//
//  PermissionViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 03.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import OrbotKit

class PermissionViewController: UIViewController, WhyDelegate {

	var error: Error?

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString("%@ installed! One more step.", comment: ""),
								  InstallViewController.orbot)
		}
	}

	@IBOutlet weak var body1Lb: UILabel! {
		didSet {
			body1Lb.text = String(format: NSLocalizedString("Ask %@ for permission to access it.", comment: ""),
								  InstallViewController.orbot)
		}
	}

	@IBOutlet weak var body2Lb: UILabel! {
		didSet {
			let text = NSMutableAttributedString(string: String(
				format: NSLocalizedString("This will allow %@ to:", comment: ""),
				Bundle.main.displayName))

			if let range = text.string.range(of: Bundle.main.displayName),
			   let descriptor = body2Lb.font.fontDescriptor.withSymbolicTraits(.traitBold)
			{
				text.setAttributes([.foregroundColor: UIColor.accent!,
									.font: UIFont(descriptor: descriptor, size: 0)],
								   range: NSRange(range, in: text.string))
			}

			body2Lb.attributedText = text
		}
	}

	@IBOutlet weak var body3Lb: UILabel! {
		didSet {
			body3Lb.text = String(
				format: NSLocalizedString("%1$@ Use %2$@ to connect to the official Tor network.", comment: ""),
				"•", InstallViewController.orbot)
		}
	}

	@IBOutlet weak var body4Lb: UILabel! {
		didSet {
			body4Lb.text = String(
				format: NSLocalizedString("%@ Get updates on the status of the connection.", comment: ""),
				"•")
		}
	}

	@IBOutlet weak var requestAccessBt: UIButton! {
		didSet {
			requestAccessBt.setTitle(buttonTitle)
		}
	}

	@IBOutlet weak var whyBt: UIButton! {
		didSet {
			whyBt.setTitle(NSLocalizedString("Why", comment: ""))
		}
	}


	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if let error = error {
			var description: String? = error.localizedDescription

			if case OrbotKit.Errors.httpError(statusCode: 403) = error {
				description = nil
			}

			titleLb.text = String(format: NSLocalizedString("Access to %@ was Denied", comment: ""),
								  InstallViewController.orbot)

			body1Lb.text = NSLocalizedString("Ask again to continue.", comment: "")

			if let description = description {
				body2Lb.attributedText = .init(string: description, attributes: [.foregroundColor: UIColor.error!])
			}
			else {
				body2Lb.isHidden = true
			}

			body3Lb.isHidden = true
			body4Lb.isHidden = true
		}
	}


	// MARK: WhyDelegate

	var buttonTitle: String {
		NSLocalizedString("Request Access", comment: "")
	}


	// MARK: Actions

	@IBAction
	func action() {
		OrbotKit.shared.open(.requestApiToken(needBypass: false, callback: URL(string: "onionbrowser:token-callback")))
	}

	@IBAction
	func why() {
		present(WhyViewController.instantiate(self))
	}
}
