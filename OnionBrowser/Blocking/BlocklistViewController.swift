//
//  BlocklistViewController.swift
//  AnyoneBrowser
//
//  Created by Benjamin Erhart on 29.01.25.
//  Copyright © 2025 Anyone. All rights reserved.
//

import UIKit
import ProgressHUD

class BlocklistViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating {

	@IBOutlet weak var enableLb: UILabel! {
		didSet {
			enableLb.text = NSLocalizedString("Use URL Blocker", comment: "")
		}
	}
	@IBOutlet weak var enableSw: UISwitch!

	@IBOutlet weak var tableView: UITableView!

	private var hostsInUse = [String]()
	private var hostsFiltered = [String]()

	private var filtered: Bool {
		navigationItem.searchController?.isActive ?? false && !(navigationItem.searchController?.searchBar.text?.isEmpty ?? true)
	}

	init() {
		super.init(nibName: String(describing: Self.self), bundle: nil)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		let sc = UISearchController(searchResultsController: nil)
		sc.searchResultsUpdater = self
		sc.obscuresBackgroundDuringPresentation = false

		definesPresentationContext = true
		navigationItem.searchController = sc

		hostsInUse = AppDelegate.shared?.browsingUis
			.compactMap({ $0.currentTab })
			.flatMap({ $0.applicableUrlBlockerRules }) ?? []

		navigationItem.title = NSLocalizedString("Blocked 3rd-Party Hosts", comment: "")
		navigationItem.rightBarButtonItem = .init(
			title: NSLocalizedString("Update", comment: ""),
			style: .plain, target: self, action: #selector(update))

		enableSw.isOn = Settings.enableUrlBlocker
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		ProgressHUD.dismiss()
	}


	// MARK: UITableViewDataSource

	func numberOfSections(in tableView: UITableView) -> Int {
		3
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		hosts(for: section).count
	}

	func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		switch section {
		case 0:
			return UrlBlocker.shared.title

		case 1:
			return NSLocalizedString("Rules in use on current page", comment: "")

		default:
			return NSLocalizedString("All rules", comment: "")
		}
	}


	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "rule") ?? newCell("rule")

		if indexPath.section == 0 {
			cell.textLabel?.lineBreakMode = .byWordWrapping
			cell.textLabel?.numberOfLines = 0
		}
		else {
			cell.textLabel?.lineBreakMode = .byTruncatingMiddle
			cell.textLabel?.numberOfLines = 1
		}


		let host = hosts(for: indexPath.section)[indexPath.row]

		cell.textLabel?.text = host

		let reason = indexPath.section != 0 ? UrlBlocker.shared.isDisabled(host: host) : nil

		if let reason = reason {
			cell.textLabel?.textColor = .systemRed
			cell.detailTextLabel?.textColor = .systemRed

			cell.detailTextLabel?.text = String(format: NSLocalizedString("Disabled: %@", comment: ""), reason)
		}
		else {
			cell.textLabel?.textColor = Settings.enableUrlBlocker ? .label : .secondaryLabel
			cell.detailTextLabel?.textColor = .secondaryLabel

			cell.detailTextLabel?.text = nil
		}

		return cell
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		indexPath.section > 0
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			toggle(hosts(for: indexPath.section)[indexPath.row])
			tableView.reloadRows(at: [indexPath], with: .automatic)
		}
	}

	func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
		if UrlBlocker.shared.isDisabled(host: hosts(for: indexPath.section)[indexPath.row]) != nil {
			return NSLocalizedString("Enable", comment: "")
		}

		return NSLocalizedString("Disable", comment: "")
	}

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		guard indexPath.section == 0 else {
			return
		}

		view.sceneDelegate?.browsingUi.addNewTab(
			.init(string: "https://github.com/hagezi/dns-blocklists"),
			transition: .notAnimated) { [weak self] _ in
				self?.navigationController?.dismiss(animated: true)
			}
	}


	// MARK: UISearchResultsUpdating

	func updateSearchResults(for searchController: UISearchController) {
		if let search = searchController.searchBar.text, !search.isEmpty {
			hostsFiltered = UrlBlocker.shared.hosts.filter({ $0.localizedCaseInsensitiveContains(search) })
		}
		else {
			hostsFiltered.removeAll()
		}

		// DO NOT RELOAD SECTIONS! Would be way too slow with the numbers of hosts from the HaGeZi blocklists!
		tableView.reloadData()
	}


	// MARK: Actions

	@objc
	func update() {
		AlertHelper.present(
			self,
			message: NSLocalizedString("Choose your preferred blocklist:", comment: ""),
			title: NSLocalizedString("Update Blocklist", comment: ""),
			actions: [
				AlertHelper.cancelAction(),
				AlertHelper.defaultAction("HaGeZi Light (~ 67k)", handler: { [weak self] _ in
					self?.loadBlocklist("light-onlydomains.txt")
				}),
				AlertHelper.defaultAction("HaGeZi Normal (~145k)", handler: { [weak self] _ in
					self?.loadBlocklist("multi-onlydomains.txt")
				}),
				AlertHelper.defaultAction("HaGeZi Pro (~200k)", handler: { [weak self] _ in
					self?.loadBlocklist("pro-onlydomains.txt")
				}),
				AlertHelper.defaultAction("HaGeZi Pro++ (~300k)", handler: { [weak self] _ in
					self?.loadBlocklist("pro.plus-onlydomains.txt")
				}),
				AlertHelper.defaultAction("HaGeZi Ultimate (~412k)", handler: { [weak self] _ in
					self?.loadBlocklist("ultimate-onlydomains.txt")
				}),
			])
	}

	@IBAction
	func toggleBlocker() {
		Settings.enableUrlBlocker = enableSw.isOn

		tableView.reloadData()
	}


	// MARK: Private Methods

	private func hosts(for section: Int) -> [String] {
		switch section {
		case 0:
			if filtered {
				return []
			}

			return [
				UrlBlocker.shared.desc,
				UrlBlocker.shared.modified]

		case 1:
			return hostsInUse

		default:
			if filtered {
				return hostsFiltered
			}

			return UrlBlocker.shared.hosts
		}
	}

	private func toggle(_ host: String) {
		if UrlBlocker.shared.isDisabled(host: host) != nil {
			UrlBlocker.shared.enable(host: host)
		}
		else {
			UrlBlocker.shared.disable(host: host, with: NSLocalizedString("User disabled", comment: ""))
		}
	}

	private func newCell(_ reuseIdentifier: String) -> UITableViewCell {
		let cell = UITableViewCell(style: .subtitle, reuseIdentifier: reuseIdentifier)

		cell.selectionStyle = .none

		cell.textLabel?.adjustsFontSizeToFitWidth = true
		cell.textLabel?.minimumScaleFactor = 0.5

		cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
		cell.detailTextLabel?.minimumScaleFactor = 0.75
		cell.detailTextLabel?.lineBreakMode = .byTruncatingMiddle

		return cell
	}

	private func loadBlocklist(_ name: String) {
		guard let url = URL(string: "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/wildcard/")?
			.appendingPathComponent(name),
			  let dest = UrlBlocker.updateUrl
		else {
			return
		}

		ProgressHUD.animate()

		let task = TorManager.shared.session().apiTask(with: .init(url: url)) { [weak self] (data: Data?, error: Error?) in
			if let error = error {
				Log.error(for: Self.self, error.localizedDescription)

				ProgressHUD.error(error.localizedDescription, delay: 3)

				return
			}

			do {
				try data?.write(to: dest, options: .atomic)

				UrlBlocker.shared.reload()

				ProgressHUD.succeed()

				// DO NOT RELOAD SECTIONS! Would be way too slow with the numbers of hosts from the HaGeZi blocklists!
				self?.tableView.reloadData()
			}
			catch {
				Log.error(for: Self.self, error.localizedDescription)

				ProgressHUD.error(error.localizedDescription, delay: 3)
			}
		}
		task.resume()
	}
}
