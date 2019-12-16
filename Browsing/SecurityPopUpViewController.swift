//
//  SecurityPopUpViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 13.12.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SecurityPopUpViewController: UIViewController, UIPopoverPresentationControllerDelegate,
UITableViewDataSource, UITableViewDelegate {

	var host: String?

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = NSLocalizedString("Security Level for This Site", comment: "")
		}
	}

	@IBOutlet weak var tableView: UITableView!

	@IBOutlet weak var customizeBt: UIButton! {
		didSet {
			customizeBt.setTitle(NSLocalizedString("Customize", comment: ""))
		}
	}

	@IBOutlet weak var learnMoreBt: UIButton! {
		didSet {
			learnMoreBt.setTitle(NSLocalizedString("Learn More", comment: ""))
		}
	}


	override var preferredContentSize: CGSize {
		get {
			return CGSize(width: 300, height: 320 + (current == .custom ? SecurityLevelCell.height : 0))
		}
		set {
			// Ignore.
		}
	}

	private var presets: [SecurityPreset] = [.insecure, .medium, .secure]

	private lazy var current = SecurityPreset(HostSettings(orDefaultsForHost: host))

	override func viewDidLoad() {
		super.viewDidLoad()

		if current == .custom {
			presets.append(.custom)
		}

		tableView.register(SecurityLevelCell.nib, forCellReuseIdentifier: SecurityLevelCell.reuseId)
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if let row = presets.firstIndex(of: current) {
			tableView.selectRow(at: IndexPath(row: row, section: 0), animated: animated, scrollPosition: .none)
		}
	}


	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return presets.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: SecurityLevelCell.reuseId, for: indexPath)
			as! SecurityLevelCell

		return cell.set(presets[indexPath.row])
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return SecurityLevelCell.height
	}


	// MARK: UIPopoverPresentationControllerDelegate

	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: Actions

	@IBAction func customize() {
		// TODO
	}

	@IBAction func learnMore() {
		// TODO
	}
}
