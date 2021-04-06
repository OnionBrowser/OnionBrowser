//
//  CustomSitesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class CustomSitesViewController: SearchableTableViewController {

	private lazy var hosts = [String]()

	private lazy var filtered = [String]()

	private lazy var levels = [String: SecurityPreset]()

	init() {
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Custom Site Security", comment: "Scene title")

		self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		// Reload, could have been changed by AddSiteViewController
		hosts = HostSettings.hosts

		for host in hosts {
			levels[host] = SecurityPreset(HostSettings.for(host))
		}

		tableView.reloadData()
	}

    // MARK: UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
		return isFiltering ? 1 : 2
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return (isFiltering ? filtered : hosts).count
		}

		return 1
    }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 {
			return "to be replaced in #willDisplayHeaderView to avoid capitalization"
		}

		return nil
	}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "site")
				?? UITableViewCell(style: .value1, reuseIdentifier: "site")

			let host = (isFiltering ? filtered : hosts)[indexPath.row]

			cell.textLabel?.text = host
			cell.detailTextLabel?.text = levels[host]?.description
			cell.accessoryType = .disclosureIndicator

			return cell
		}

		let cell = tableView.dequeueReusableCell(withIdentifier: "addSite")
			?? UITableViewCell(style: .default, reuseIdentifier: "addSite")

		cell.textLabel?.text = NSLocalizedString("Add Site", comment: "Button label")
		cell.textLabel?.textColor = .systemBlue

		return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return indexPath.section == 0
    }

    override func tableView(_ tableView: UITableView, commit
		editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
			let host = (isFiltering ? filtered : hosts)[indexPath.row]

			hosts.removeAll { $0 == host }
			filtered.removeAll { $0 == host }
			levels.removeValue(forKey: host)

			HostSettings.remove(host).store()

            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }

	// MARK: UITableViewDelegate

	/**
	Workaround to avoid capitalization of header.
	*/
	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		if section == 0,
			let header = view as? UITableViewHeaderFooterView {

			header.textLabel?.text = NSLocalizedString("Define custom settings for specific sites.",
													   comment: "Option description")
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.section == 0 {
			let vc = SecurityViewController()
			vc.host = (isFiltering ? filtered : hosts)[indexPath.row]

			navigationController?.pushViewController(vc, animated: true)
		}
		else {
			navigationController?.pushViewController(AddSiteViewController(), animated: true)
		}

		tableView.deselectRow(at: indexPath, animated: false)
	}


	// MARK: UISearchResultsUpdating

	override func updateSearchResults(for searchController: UISearchController) {
		if let searchText = searchText {
			filtered = hosts.filter() { $0.lowercased().contains(searchText) }
        }
		else {
			filtered.removeAll()
		}

        tableView.reloadData()
	}
}
