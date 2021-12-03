//
//  Storage2ViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 11.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

class Storage2ViewController: SearchableTableViewController {

	struct Item {
		let host: String

		var cookies = 0

		var storage: Int64 = 0

		init(_ host: String) {
			self.host = host
		}
	}

    private var filtered = [Item]()

	private var showShortlist = true

	private let cookieJar = AppDelegate.shared?.cookieJar

	private lazy var data: [Item] = {
		var data = [String: Item]()

		if let cookies = cookieJar?.cookieStorage.cookies {
			for cookie in cookies {
				var host = cookie.domain

				if host.first == "." {
					host.removeFirst()
				}

				var item = data[host] ?? Item(host)
				item.cookies += 1
				data[host] = item
			}
		}

		if let files = cookieJar?.localStorageFiles() {
			for item in files {
				if let filepath = item.key as? String,
					let host = item.value as? String {

					var item = data[host] ?? Item(host)
					item.storage += (FileManager.default.sizeOfItem(atPath: filepath) ?? 0)
					data[host] = item
				}
			}
		}

		return data.map { $1 }.sorted { $0.storage == $1.storage ? $0.cookies > $1.cookies : $0.storage > $1.storage }
	}()

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
	}


    // MARK: UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return isFiltering ? 1 : 2
	}

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return isFiltering ? filtered.count : (showShortlist && data.count > 11 ? 11 : data.count)
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
			var amount: UILabel? = view.contentView.viewWithTag(667) as? UILabel

			if title == nil {
				title = UILabel()
				title?.textColor = UIColor(red: 0.427451, green: 0.427451, blue: 0.447059, alpha: 1)
				title?.font = .systemFont(ofSize: 14)
				title?.translatesAutoresizingMaskIntoConstraints = false
				title?.tag = 666

				view.contentView.addSubview(title!)
				title?.leadingAnchor.constraint(equalTo: view.contentView.leadingAnchor, constant: 16).isActive = true
				title?.bottomAnchor.constraint(equalTo: view.contentView.bottomAnchor, constant: -8).isActive = true

				amount = UILabel()
				amount?.textColor = title?.textColor
				amount?.font = title?.font
				amount?.translatesAutoresizingMaskIntoConstraints = false
				amount?.tag = 667

				view.contentView.addSubview(amount!)
				amount?.trailingAnchor.constraint(equalTo: view.contentView.trailingAnchor, constant: -16).isActive = true
				amount?.bottomAnchor.constraint(equalTo: view.contentView.bottomAnchor, constant: -8).isActive = true
			}

			var count: Int64 = 0

			for item in isFiltering ? filtered : data {
				count += item.storage
			}

			title?.text = NSLocalizedString("Local Storage", comment: "Section header")
				.localizedUppercase

			amount?.text = ByteCountFormatter
				.string(fromByteCount: count, countStyle: .file)

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
			if data.count > 11 {
				let cell = tableView.dequeueReusableCell(withIdentifier: "overflowCell")
					?? UITableViewCell(style: .default, reuseIdentifier: "overflowCell")

				cell.textLabel?.textColor = .systemBlue
				cell.textLabel?.text = NSLocalizedString("Show All Sites", comment: "Button label")

				return cell
			}
		}

        let cell = tableView.dequeueReusableCell(withIdentifier: "storageCell")
			?? UITableViewCell(style: .value1, reuseIdentifier: "storageCell")

		cell.selectionStyle = .none

		let item = (isFiltering ? filtered : data)[indexPath.row]

		cell.textLabel?.text = item.host

		var detail = [String]()

		if item.cookies > 0 {
			detail.append(String.localizedStringWithFormat(
				NSLocalizedString("%d cookie(s)", comment: "#bc-ignore!"), item.cookies))
		}

		if item.storage > 0 {
			detail.append(ByteCountFormatter.string(fromByteCount: item.storage, countStyle: .file))
		}

		cell.detailTextLabel?.text = detail.joined(separator: ", ")

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 0 || !isFiltering && showShortlist && indexPath.row == 10 && data.count > 11 {
			return false
		}

		return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle:
		UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
			let host = (isFiltering ? filtered : data)[indexPath.row].host

			cookieJar?.clearAllData(forHost: host)

			if isFiltering {
				filtered.remove(at: indexPath.row)

				data.removeAll { $0.host == host }
			}
			else {
				data.remove(at: indexPath.row)
			}

			tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
        }
    }


	// MARK: UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		// Must be the show-all cell, others can't be selected.
		if indexPath.section == 0 {
			showShortlist = false
		}
		// The remove-all cell
		else if indexPath.section > 0 {
			cookieJar?.clearAllNonWhitelistedData()

			data.removeAll()
		}

		tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		tableView.deselectRow(at: indexPath, animated: true)
	}


	// MARK: UISearchResultsUpdating

	override func updateSearchResults(for searchController: UISearchController) {
		if let searchText = searchText {
			filtered = data.filter() { $0.host.lowercased().contains(searchText) }
        }
		else {
			filtered.removeAll()
		}

        tableView.reloadData()
	}
}
