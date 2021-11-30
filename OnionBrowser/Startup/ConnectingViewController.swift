//
//  ConnectingViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI

class ConnectingViewController: UIViewController, OnionManagerDelegate, BridgesConfDelegate {

	class func start() {
		let appDelegate = AppDelegate.shared

		if appDelegate?.browsingUi == nil {
			appDelegate?.browsingUi = BrowsingViewController()
		}

		appDelegate?.show(appDelegate?.browsingUi) { _ in
			TabSecurity.restore()

			appDelegate?.browsingUi?.becomesVisible()
		}
	}


	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = NSLocalizedString("Connecting to Tor", comment: "")
		}
	}

	@IBOutlet weak var bridgeConfBt: UIButton!
	@IBOutlet weak var progress: UIProgressView! {
		didSet {
			progress.isHidden = true
		}
	}

	@IBOutlet weak var troubleLb: UILabel! {
		didSet {
			updateTroubles(
				NSLocalizedString("We're having trouble.", comment: ""),
				NSLocalizedString(
					"Close Onion Browser and restart or try using a bridge.",
					comment: ""))
		}
	}
	@IBOutlet weak var troubleLbHeight: NSLayoutConstraint!

	@IBOutlet weak var image: UIImageView!
	@IBOutlet weak var claimLb: UILabel!
	@IBOutlet weak var claimLbTopAnchor: NSLayoutConstraint!

	@IBOutlet weak var nextBt: UIButton! {
		didSet {
			nextBt.isHidden = true
		}
	}

	/**
	If set to true, will immediately jump to `browsingUi` after successful connect.
	*/
	var autoClose = false

	private var refresh: Timer?

	private var success = false

	private var lastClaim: Int?

	private class Claim {
		let text: String
		let textColor: UIColor
		let backgroundColor: UIColor?
		let image: UIImage?

		init(_ text: String, _ textColor: UIColor, _ backgroundColor: String, _ image: String) {
			self.text = text
			self.textColor = textColor
			self.backgroundColor = UIColor(named: backgroundColor)
			self.image = UIImage(named: image)
		}
	}

	// Intentionally non-static to free memory after usage.
	private let claims = [
		Claim(NSLocalizedString("__CLAIM_1__", comment: ""), .white, "group_bg", "group"),
		Claim(NSLocalizedString("__CLAIM_2__", comment: ""), .black, "people_bg", "people"),
		Claim(NSLocalizedString("__CLAIM_3__", comment: ""), .white, "facebook_bg", "facebook"),
		Claim(NSLocalizedString("__CLAIM_4__", comment: ""), .white, "activist_bg", "activist"),
		Claim(NSLocalizedString("__CLAIM_5__", comment: ""), .white, "blogger_bg", "blogger"),
		Claim(NSLocalizedString("__CLAIM_6__", comment: ""), .black, "journalist_bg", "journalist"),
		Claim(NSLocalizedString("__CLAIM_7__", comment: ""), .black, "business_bg", "business"),
		Claim(NSLocalizedString("__CLAIM_8__", comment: ""), .black, "worker_bg", "worker"),
	]

	override func viewDidLoad() {
		super.viewDidLoad()

		OnionManager.shared.setTransportConf(transport: Settings.transport,
											 customBridges: Settings.customBridges)

		OnionManager.shared.startTor(delegate: self)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		showClaim(nil)
		refresh = Timer.scheduledTimer(timeInterval: 3, target: self,
									   selector: #selector(showClaim), userInfo: nil, repeats: true)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		refresh?.invalidate()
		refresh = nil
	}


	// MARK: OnionManagerDelegate

	func torConnProgress(_ progress: Int) {
		DispatchQueue.main.async {
			self.progress.progress = Float(progress) / 100
			self.progress.isHidden = false
		}
	}

	func torConnFinished() {
		DispatchQueue.main.async {
			Bookmark.firstRunSetup()
			Bookmark.migrateToV3()

			if self.autoClose {
				return ConnectingViewController.start()
			}

			self.refresh?.invalidate()
			self.refresh = nil

			self.titleLb.text = NSLocalizedString("Connected!", comment: "")
			self.bridgeConfBt.isHidden = true
			self.bridgeConfBt.widthAnchor.constraint(equalToConstant: 0).isActive = true
			self.progress.isHidden = true
			self.troubleLbHeight.constant = 0
			self.troubleLb.isHidden = true
			self.claimLb.isHidden = true

			self.nextBt.setTitle(NSLocalizedString("Next", comment: ""))
			self.nextBt.isHidden = false

			self.success = true
		}
	}

	func torConnDifficulties() {
		DispatchQueue.main.async {
			self.troubleLbHeight.constant = 98
			self.troubleLb.isHidden = false

			self.claimLb.isHidden = true

			self.nextBt.setTitle(NSLocalizedString("Configure Bridges", comment: ""))
			self.nextBt.isHidden = false
		}
	}


	// MARK: BridgeConfDelegate

	// Ignore, not used.
	var transport = Transport.none

	// Ignore, not used.
	var customBridges: [String]? = nil

	func save() {
		guard !troubleLb.isHidden else {
			return
		}

		updateTroubles(
			NSLocalizedString("Trying a bridge…", comment: ""),
			NSLocalizedString(
				"This may take time. If it doesn't work after a while, choose a different bridge.",
				comment: ""))
	}


	// MARK: Actions

	@IBAction func next() {
		if success {
			AppDelegate.shared?.show(InitSecurityLevelViewController())
		}
		else {
			bridgeSettings()
		}
	}

	@IBAction func bridgeSettings() {
		ObBridgesConfViewController.present(from: self)
	}

	// MARK: Private methods

	@objc private func showClaim(_ timer: Timer?) {
		var nextClaim: Int

// FOR DEBUGGING: Show all in a row.
//		if lastClaim == nil || lastClaim! >= claims.count - 1 {
//			nextClaim = 0
//		}
//		else {
//			nextClaim = lastClaim! + 1
//		}

		repeat {
			nextClaim = Int(arc4random_uniform(UInt32(claims.count)))
		} while nextClaim == lastClaim

		lastClaim = nextClaim

		let claim = claims[nextClaim]

		troubleLb.textColor = claim.textColor
		claimLb.text = claim.text
		claimLb.textColor = claim.textColor
		view.backgroundColor = claim.backgroundColor
		image.image = claim.image
	}

	private func updateTroubles(_ header: String, _ body: String) {
		let text = NSMutableAttributedString(
			string: header, attributes: [.font: UIFont.boldSystemFont(ofSize: 24)])

		text.append(NSAttributedString(string: "\n"))

		text.append(NSAttributedString(
			string: body, attributes: [.font: UIFont.systemFont(ofSize: 15)]))

		troubleLb.attributedText = text
	}
}
