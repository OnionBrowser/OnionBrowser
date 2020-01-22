//
//  InitSecurityLevelViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 15.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class InitSecurityLevelViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = NSLocalizedString("Define Default Security Level", comment: "")
		}
	}

	@IBOutlet weak var explanationLb: UILabel! {
		didSet {
			explanationLb.text = NSLocalizedString(
				"Your security level will affect each website you visit and may affect their performance. Security levels can be modified per site by tapping the shield icon in your browser.",
				comment: "")
		}
	}

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var startBt: UIButton! {
		didSet {
			startBt.setTitle(NSLocalizedString("Start Browsing", comment: ""))
			startBt.isEnabled = false
		}
	}

	@IBOutlet weak var learnMoreBt: UIButton! {
		didSet {
			learnMoreBt.setTitle(NSLocalizedString("Learn More", comment: ""))
			learnMoreBt.isEnabled = false
		}
	}

	private var presets: [SecurityPreset] = [.insecure, .medium, .secure]


	override func viewDidLoad() {
		super.viewDidLoad()

		tableView.register(SecurityLevelCell.nib, forCellReuseIdentifier: SecurityLevelCell.reuseId)

		tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))
	}


	// MARK: UITableViewDataSource

	func numberOfSections(in tableView: UITableView) -> Int {
		return presets.count
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 1
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: SecurityLevelCell.reuseId, for: indexPath)
			as! SecurityLevelCell

		cell.contentView.backgroundColor = .white
		cell.contentView.layer.cornerRadius = 8
		cell.contentView.layer.masksToBounds = true

		cell.nameLb.textColor = .darkGray
		cell.explanationLb.textColor = .gray

		cell.layer.cornerRadius = 8
		cell.layer.masksToBounds = true

		return cell.set(presets[indexPath.section])
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
		return section < 2 ? 24 : 0
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return SecurityLevelCell.height
	}

	func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
		view.tintColor = .clear
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		startBt.isEnabled = true
		startBt.backgroundColor = .ok
		learnMoreBt.isEnabled = true
	}


	// MARK: Actions

	@IBAction func start(_ sender: UIView) {
		guard let selected = tableView.indexPathForSelectedRow,
			selected.section < presets.count else {
			return
		}

		let preset = presets[selected.section]

		let hs = HostSettings.forDefault()

		hs.contentPolicy = preset.values?.csp ?? .strict
		hs.webRtc = preset.values?.webRtc ?? false
		hs.mixedMode = preset.values?.mixedMode ?? false

		// Trigger creation, save and store of default HostSettings.
		hs.save().store()

		Settings.didIntro = true

		ConnectingViewController.start(sender == learnMoreBt)
	}
}
