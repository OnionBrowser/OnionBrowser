//
//  AdvancedTorConfViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import IPtProxyUI

class AdvancedTorConfViewController: FixedFormViewController {

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Advanced Tor Configuration", comment: "")
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save,
															target: self, action: #selector(save))

		form
			+++ MultivaluedSection(multivaluedOptions: [.Insert, .Delete],
								   header: "to be replaced in #willDisplayHeaderView to avoid capitalization") {

				$0.header?.height = { 280 }

				$0.addButtonProvider = { _ in
					return ButtonRow()
				}

				$0.multivaluedRowToInsertAt = { [weak self] index in
					return TextRow() {
						$0.tag = String(index)

						self?.turnOffAutoCorrect($0.cell.textField)
					}
				}

				if let conf = Settings.advancedTorConf {
					var i = 0
					for item in conf {
						let r = $0.multivaluedRowToInsertAt!(i)
						r.baseValue = item
						$0 <<< r
						i += 1
					}
				}
				else {
					$0 <<< TextRow() {
						$0.tag = "0"

						turnOffAutoCorrect($0.cell.textField)

						$0.placeholder = "--HidServAuth"
						}
						<<< TextRow() {
							$0.tag = "1"

							turnOffAutoCorrect($0.cell.textField)

							$0.placeholder = "example.onion kTgk5lBIROvw2Uv9za8838"
					}
				}
		}
	}


	// MARK: UITableViewDelegate

	/**
	Workaround to avoid capitalization of header.
	*/
	func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		if section == 0,
			let header = view as? UITableViewHeaderFooterView {

			header.textLabel?.text = NSLocalizedString("Add additional command line options for Tor startup.", comment: "")
				+ "\n\n"
				+ String(format: NSLocalizedString("Refer to %@ for possible options.", comment: ""),
						 "https://2019.www.torproject.org/docs/tor-manual.html")
				+ "\n\n"
				+ NSLocalizedString("Changing this option requires restarting the app.", comment: "")
				+ "\n\n"
				+ NSLocalizedString("To recover from a non working configuration, remove everything under \"Bridge Configuration\" on startup and restart the app.",
									comment: "")
		}
	}


	// MARK: Actions

	@objc
	func save() {
		let values = form.values().sorted { Int($0.key)! < Int($1.key)! }.compactMap { $0.value as? String }

		print("[\(String(describing: type(of: self)))] values=\(values)")

		Settings.advancedTorConf = values

		dismiss(animated: true)
	}


	// MARK: Private Methods

	private func turnOffAutoCorrect(_ textField: UITextField) {
		textField.autocorrectionType = .no
		textField.autocapitalizationType = .none
		textField.smartDashesType = .no
		textField.smartQuotesType = .no
		textField.smartInsertDeleteType = .no
	}
}
