//
//  WhyViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 03.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit

protocol WhyDelegate: AnyObject {

	var buttonTitle1: String { get }

	var buttonTitle2: String? { get }

	func run(useBuiltInTor: Bool)
}

class WhyViewController: UIViewController {

	static func instantiate(_ delegate: WhyDelegate) -> UINavigationController {
		let vc = Self()
		vc.delegate = delegate

		return UINavigationController(rootViewController: vc)
	}

	weak var delegate: WhyDelegate?

	@IBOutlet weak var title1Lb: UILabel! {
		didSet {
			title1Lb.text = String(
				format: NSLocalizedString(
					"Why %1$@ needs %2$@",
					comment: "Placeholder 1 is 'Onion Browser', placeholder 2 is 'Orbot'"),
				Bundle.main.displayName, OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var body1Lb: UILabel! {
		didSet {
			body1Lb.text = String(
				format: NSLocalizedString(
					"So that you can do more with Tor on iOS! In %1$@, %2$@ improves the browsing experience with:",
					comment: "Placeholder 1 is 'Onion Browser', placeholder 2 is 'Orbot'"),
				Bundle.main.displayName, OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var body2Lb: UILabel! {
		didSet {
			body2Lb.text = String(format: NSLocalizedString("%@ a little more speed", comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var body3Lb: UILabel! {
		didSet {
			body3Lb.text = String(format: NSLocalizedString("%@ new standards", comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var body4Lb: UILabel! {
		didSet {
			body4Lb.text = String(format: NSLocalizedString("%@ video and audio streaming", comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var body5Lb: UILabel! {
		didSet {
			body5Lb.text = String(format: NSLocalizedString("%@ more protection from IP leaks", comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var body6Lb: UILabel! {
		didSet {
			body6Lb.text = String(
				format: NSLocalizedString(
					"%@ alone provides a VPN proxy. It will hide apps from network monitoring and give you access when they are blocked.",
					comment: "Placeholder is 'Orbot'"),
				OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var body7Lb: UILabel! {
		didSet {
			body7Lb.text = NSLocalizedString("Both are free to use. Free of tracking. Code is open source.", comment: "")
		}
	}

	@IBOutlet weak var button1: UIButton! {
		didSet {
			button1.setTitle(delegate?.buttonTitle1)
		}
	}

	@IBOutlet weak var title2Lb: UILabel! {
		didSet {
			eventuallyHide(title2Lb)
			title2Lb.text = NSLocalizedString("Reasons to use the built-in Tor (iOS 17 only)", comment: "")
		}
	}

	@IBOutlet weak var body8Lb: UILabel! {
		didSet {
			eventuallyHide(body8Lb)
			body8Lb.text = String(format: NSLocalizedString("%1$@ If you have connectivity issues with %2$@", comment: "Placeholder 1 is bullet point, placeholder 2 is 'Orbot'"), "•", OrbotKit.orbotName)
		}
	}

	@IBOutlet weak var body9Lb: UILabel! {
		didSet {
			eventuallyHide(body9Lb)
			body9Lb.text = String(format: NSLocalizedString("%1$@ if you want to use %2$@ over another VPN", comment: "Placeholder 1 is bullet point, Placeholder 2 is 'Onion Browser'"), "•", Bundle.main.displayName)
		}
	}

	@IBOutlet weak var body10Lb: UILabel! {
		didSet {
			eventuallyHide(body10Lb)
			body10Lb.text = NSLocalizedString("Drawbacks:", comment: "")
		}
	}

	@IBOutlet weak var body11Lb: UILabel! {
		didSet {
			eventuallyHide(body11Lb)
			body11Lb.text = String(format: NSLocalizedString(
				"%@ video and audio streams don't go through Tor and might get blocked",
				comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var body12Lb: UILabel! {
		didSet {
			eventuallyHide(body12Lb)
			body12Lb.text = String(format: NSLocalizedString(
				"%@ Websites can uncover your real IP address using JavaScript",
				comment: "Placeholder is bullet point"), "•")
		}
	}

	@IBOutlet weak var button2: UIButton! {
		didSet {
			eventuallyHide(button2)
			button2.setTitle(delegate?.buttonTitle2)
		}
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Why", comment: "")
		navigationItem.rightBarButtonItem = .init(barButtonSystemItem: .close, target: self, action: #selector(close))
	}

	@IBAction
	func action(_ sender: UIButton) {
		dismiss(animated: true) {
			self.delegate?.run(useBuiltInTor: sender == self.button2)
		}
	}

	@objc
	func close() {
		dismiss(animated: true)
	}


	private func eventuallyHide(_ view: UIView) {
		if #available(iOS 17.0, *) {
			guard delegate?.buttonTitle2?.isEmpty ?? true else {
				return
			}
		}

		view.isHidden = true

		view.constraints.forEach { $0.isActive = false }

		view.heightAnchor.constraint(equalToConstant: 0).isActive = true
	}
}
