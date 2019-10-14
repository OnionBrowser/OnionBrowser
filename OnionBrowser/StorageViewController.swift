//
//  StorageViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 11.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

class StorageViewController: UITableViewController {

	enum DisplayType {
		case cookies
		case localStorage
	}

	private let displayType: DisplayType

	private var showShortlist = true

	private var cookieJar: CookieJar? {
		return AppDelegate.shared()?.cookieJar
	}

	private lazy var cookies: [String: Int] = {
		var data = [String: Int]()

		if let cookies = cookieJar?.cookieStorage.cookies {
			for cookie in cookies {
				var domain = cookie.domain

				if domain.first == "." {
					domain.removeFirst()
				}

				var counted = data[domain] ?? 0
				data[domain] = counted + 1
			}
		}

		return data
	}()

	private lazy var localStorage: [String: Int64] = {
		var data = [String: Int64]()

		if let files = cookieJar?.localStorageFiles() {
			for item in files {
				if let filepath = item.key as? String,
					let domain = item.value as? String {

					var space = data[domain] ?? 0

					data[domain] = space + (size(filepath) ?? 0)
				}
			}
		}

		return data
	}()

	init(type: StorageViewController.DisplayType) {
		displayType = type
		super.init(style: .grouped)
	}

	required init?(coder: NSCoder) {
		displayType = coder.decodeObject(forKey: "displayType") as? DisplayType ?? .cookies
		super.init(coder: coder)
	}

	override func encode(with coder: NSCoder) {
		coder.encode(displayType, forKey: "displayType")
		super.encode(with: coder)
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = displayType == .cookies
			? NSLocalizedString("Cookies", comment: "Scene title")
			: NSLocalizedString("Local Storage", comment: "Scene title")

		self.navigationItem.rightBarButtonItem = self.editButtonItem
	}


    // MARK: UITableViewDataSource

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 2
	}

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			let count = displayType == .cookies ? cookies.count : localStorage.count

			return showShortlist && count > 11 ? 11 : count
		}

		return 1
    }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == 0 {
			return displayType == .cookies
				? NSLocalizedString("Cookies", comment: "Section header")
				: NSLocalizedString("Local Storage", comment: "Section header")
		}

		return nil
	}

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section > 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "button")
				?? UITableViewCell(style: .default, reuseIdentifier: "button")

			cell.textLabel?.text = displayType == .cookies
				? NSLocalizedString("Remove All Cookies", comment: "Button label")
				: NSLocalizedString("Remove All Local Storage", comment: "Button label")

			cell.textLabel?.textAlignment = .center
			cell.textLabel?.textColor = .systemRed

			return cell
		}

		if showShortlist && indexPath.row == 10 {
			let count = displayType == .cookies ? cookies.count : localStorage.count

			if count > 11 {
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

		if displayType == .cookies {
			let domain = cookies.keys.sorted()[indexPath.row]

			cell.textLabel?.text = domain
			cell.detailTextLabel?.text = NumberFormatter.localizedString(
				from: NSNumber(value: cookies[domain] ?? 0), number: .none)
		}
		else {
			let domain = localStorage.keys.sorted()[indexPath.row]

			cell.textLabel?.text = domain

			cell.detailTextLabel?.text = ByteCountFormatter.string(
				fromByteCount: localStorage[domain] ?? 0, countStyle: .file)
		}

        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		if indexPath.section > 0 || showShortlist && indexPath.row == 10
			&& (displayType == .cookies ? cookies.count : localStorage.count) > 11 {

			return false
		}

		return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle:
		UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        if editingStyle == .delete {
			let host = (displayType == .cookies ? cookies.keys.sorted() : localStorage.keys.sorted())[indexPath.row]

			cookieJar?.clearAllData(forHost: host)

			if displayType == .cookies {
				cookies.removeValue(forKey: host)
			}
			else {
				localStorage.removeValue(forKey: host)
			}

            tableView.deleteRows(at: [indexPath], with: .fade)
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

			if displayType == .cookies {
				cookies.removeAll()
			}
			else {
				localStorage.removeAll()
			}

		}

		tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		tableView.deselectRow(at: indexPath, animated: true)
	}


	// MARK: Private Methods

	/**
	Get size in byte of a given file.

	- parameter filepath: The path to the file.
	- returns: File size in bytes.
	*/
	private func size(_ filepath: String?) -> Int64? {
		if let filepath = filepath,
			let attr = try? FileManager.default.attributesOfItem(atPath: filepath) {
			return (attr[.size] as? NSNumber)?.int64Value
		}

		return nil
	}
}
