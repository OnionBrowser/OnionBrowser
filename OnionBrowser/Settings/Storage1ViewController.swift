//
//  Storage1ViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class Storage1ViewController: SearchableTableViewController {

    private var filtered = [String]()

	private var showShortlist = true

	private var hosts = [String]()

	init() {
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Cookies and Local Storage", comment: "Scene title")

		self.navigationItem.rightBarButtonItem = self.editButtonItem

		WebsiteStorage.shared.hosts { [weak self] hosts in
			self?.hosts = hosts

			self?.tableView.reloadData()
		}
	}


    // MARK: UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return isFiltering ? 1 : 2
	}

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return isFiltering ? filtered.count : (showShortlist && hosts.count > 11 ? 11 : hosts.count)
		}

		return 1
    }

	override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		if section == 0 {
			return 56
		}

		return super.tableView(tableView, heightForHeaderInSection: section)
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		if section == 0 {
			let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: "header")
				?? UITableViewHeaderFooterView(reuseIdentifier: "header")

			var title: UILabel? = view.contentView.viewWithTag(666) as? UILabel

			if title == nil {
				title = UILabel()
				title?.textColor = UIColor(red: 0.427451, green: 0.427451, blue: 0.447059, alpha: 1)
				title?.font = .systemFont(ofSize: 14)
				title?.translatesAutoresizingMaskIntoConstraints = false
				title?.tag = 666

				view.contentView.addSubview(title!)
				title?.leadingAnchor.constraint(equalTo: view.contentView.leadingAnchor, constant: 16).isActive = true
				title?.bottomAnchor.constraint(equalTo: view.contentView.bottomAnchor, constant: -8).isActive = true
			}

			title?.text = NSLocalizedString("Local Storage", comment: "Section header")
				.localizedUppercase

			return view
		}

		return nil
	}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section > 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "button")
				?? UITableViewCell(style: .default, reuseIdentifier: "button")

			cell.textLabel?.text = NSLocalizedString("Remove All Local Storage", comment: "Button label")

			cell.textLabel?.textAlignment = .center
			cell.textLabel?.textColor = .systemRed

			return cell
		}

		if !isFiltering && showShortlist && indexPath.row == 10 {
			if hosts.count > 11 {
				let cell = tableView.dequeueReusableCell(withIdentifier: "overflowCell")
					?? UITableViewCell(style: .default, reuseIdentifier: "overflowCell")

				cell.textLabel?.textColor = .systemBlue
				cell.textLabel?.text = NSLocalizedString("Show All Sites", comment: "Button label")

				return cell
			}
		}

        let cell = tableView.dequeueReusableCell(withIdentifier: "storageCell")
			?? UITableViewCell(style: .default, reuseIdentifier: "storageCell")

		cell.textLabel?.text = (isFiltering ? filtered : hosts)[indexPath.row]
		cell.accessoryType = .disclosureIndicator

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 0 || !isFiltering && showShortlist && indexPath.row == 10 && hosts.count > 11 {
			return false
		}

		return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle:
		UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
			let host = (isFiltering ? filtered : hosts)[indexPath.row]

			WebsiteStorage.shared.remove(for: host, ignoreWhitelist: true)

			if isFiltering {
				filtered.remove(at: indexPath.row)

				hosts.removeAll { $0 == host }
			}
			else {
				hosts.remove(at: indexPath.row)
			}

			tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
        }
    }


	// MARK: UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// Must be the show-all cell, others can't be selected.
		if indexPath.section == 0 {
			if showShortlist && indexPath.row == 10 && hosts.count > 11 {
				showShortlist = false

				tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
			}
			else {
				let vc = Storage2ViewController()
				vc.host = (isFiltering ? filtered : hosts)[indexPath.row]
				navigationController?.pushViewController(vc, animated: true)
			}
		}
		// The remove-all cell
		else if indexPath.section > 0 {
			WebsiteStorage.shared.cleanup()

			hosts.removeAll()

			tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		}

		tableView.deselectRow(at: indexPath, animated: true)
	}


	// MARK: UISearchResultsUpdating

	override func updateSearchResults(for searchController: UISearchController) {
		if let searchText = searchText {
			filtered = hosts.filter() { $0.contains(searchText) }
        }
		else {
			filtered.removeAll()
		}

        tableView.reloadData()
	}
}
