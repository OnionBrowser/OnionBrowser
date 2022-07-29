//
//  Storage2ViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 29.07.22.
//  Copyright © 2012 - 2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class Storage2ViewController: UITableViewController {

	var host: String?

	private var details = [String: Int]()

	override func viewDidLoad() {
		super.viewDidLoad()

		guard let host = host else {
			return
		}

		navigationItem.title = host

		WebsiteStorage.shared.details(for: host) { [weak self] details in
			self?.details = details

			self?.tableView.reloadData()
		}
	}

	// MARK: UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		// #warning Incomplete implementation, return the number of sections
		return 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		return details.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "typeCell")
			?? UITableViewCell(style: .value1, reuseIdentifier: "typeCell")

		let key = details.keys.sorted()[indexPath.row]

		cell.textLabel?.text = key
		cell.detailTextLabel?.text = String(details[key] ?? 0)

		cell.selectionStyle = .none

		return cell
	}
}
