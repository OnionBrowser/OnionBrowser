//
//  CustomSitesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

class CustomSitesViewController: SearchableTableViewController {

	private lazy var hosts: [String] = {
		var hosts = HostSettings.sortedHosts() as? [String] ?? []

		// We only want to have the real hosts here.
		hosts.removeAll { $0 == HOST_SETTINGS_DEFAULT }

		return hosts
	}()

	private var filtered = [String]()

	private lazy var levels: [String: SecurityPreset] = {
		var levels = [String: SecurityPreset]()

		for host in hosts {
			levels[host] = SecurityPreset(HostSettings.forHost(host))
		}

		return levels
	}()

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

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

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
