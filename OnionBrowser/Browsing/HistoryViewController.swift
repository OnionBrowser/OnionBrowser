//
//  HistoryViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 28.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class HistoryViewController: UITableViewController {

	struct Item {
		var url: URL
		var title: String?
	}

	private weak var tab: Tab?
	private var history: [Item]?

	class func instantiate(_ tab: Tab) -> UINavigationController {
		let vc = HistoryViewController()
		vc.tab = tab

		return UINavigationController(rootViewController: vc)
	}

    override func viewDidLoad() {
        super.viewDidLoad()

		navigationItem.title = NSLocalizedString("History", comment: "")
		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done, target: self, action: #selector(_dismiss))

		history = tab?.history.reversed()
		history?.removeFirst()
    }


    // MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return max(1, tab?.history.count ?? 1) - 1
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "history")
			?? UITableViewCell(style: .subtitle, reuseIdentifier: "history")

		let url = history?[indexPath.row].url

		cell.textLabel?.text = history?[indexPath.row].title ?? BrowsingViewController.prettyTitle(url)
		cell.detailTextLabel?.text = url?.absoluteString

        return cell
    }


	// MARK: UITableViewDelegate

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if let item = history?[indexPath.row] {
			tab?.load(item.url)
		}

		_dismiss()
	}

	// MARK: Private Methods

	@objc
	private func _dismiss() {
		dismiss(animated: true)
	}
}
