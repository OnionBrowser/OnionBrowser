//
//  BookmarksViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BookmarksViewController: UIViewController, UITableViewDataSource,
UITableViewDelegate, UISearchResultsUpdating, BookmarkViewControllerDelegate {

	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var toolbar: UIToolbar!

	private lazy var doneBt = UIBarButtonItem(barButtonSystemItem: .done,
											  target: self, action: #selector(dismiss_))

	private lazy var doneEditingBt = UIBarButtonItem(barButtonSystemItem: .done,
													 target: self, action: #selector(edit))
	private lazy var editBt = UIBarButtonItem(barButtonSystemItem: .edit,
											  target: self, action: #selector(edit))

	private let searchController = UISearchController(searchResultsController: nil)
	private var filtered = [Bookmark]()

	private var _needsReload = false

	/**
	true, if a search filter is currently set by the user.
	*/
	private var isFiltering: Bool {
		return searchController.isActive
			&& !(searchController.searchBar.text?.isEmpty ?? true)
	}


	@objc
	class func instantiate() -> UINavigationController {
		return UINavigationController(rootViewController: self.init())
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		toolbarItems = [
			UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(add)),
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]

		navigationItem.title = NSLocalizedString("Bookmarks", comment: "Scene title")
		updateButtons()

		tableView.register(BookmarkCell.nib, forCellReuseIdentifier: BookmarkCell.reuseId)
		tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

		searchController.searchResultsUpdater = self
		searchController.obscuresBackgroundDuringPresentation = false
		definesPresentationContext = true
		navigationItem.searchController = searchController
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		if _needsReload {
			tableView.reloadData()
			_needsReload = false
		}
	}


	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return (isFiltering ? filtered : Bookmark.all).count
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return BookmarkCell.height
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BookmarkCell.reuseId, for: indexPath) as! BookmarkCell

		return cell.set((isFiltering ? filtered : Bookmark.all)[indexPath.row])
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		if editingStyle == .delete {
			Bookmark.all[indexPath.row].icon = nil // Delete icon file.
			let bookmark = Bookmark.all.remove(at: indexPath.row)
			delete(bookmark)
			Bookmark.store()
			tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
		}
	}

	func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		Bookmark.all.insert(Bookmark.all.remove(at: sourceIndexPath.row), at: destinationIndexPath.row)
		Bookmark.store()
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		var index: Int? = indexPath.row

		if isFiltering {
			index = Bookmark.all.firstIndex(of: filtered[index!])
		}

		if let index = index {
			if tableView.isEditing {
				let vc = BookmarkViewController()
				vc.delegate = self
				vc.index = index

				navigationController?.pushViewController(vc, animated: true)
			}
			else {
				let bookmark = Bookmark.all[index]

				AppDelegate.shared?.browsingUi?.addNewTab(
				bookmark.url, transition: .notAnimated) { _ in
					self.dismiss_()
				}
			}
		}

		tableView.deselectRow(at: indexPath, animated: false)
	}


	// MARK: UISearchResultsUpdating

	func updateSearchResults(for searchController: UISearchController) {
		if let search = searchController.searchBar.text?.lowercased() {
			filtered = Bookmark.all.filter() {
				$0.name?.lowercased().contains(search) ?? false
					|| $0.url?.absoluteString.lowercased().contains(search) ?? false
			}
		}
		else {
			filtered.removeAll()
		}

		tableView.reloadData()
	}


	// MARK: BookmarkViewControllerDelegate

	func needsReload() {
		_needsReload = true
	}


	// MARK: Actions

	@objc private func dismiss_() {
		navigationController?.dismiss(animated: true)
	}

	@objc private func add() {
		let vc = BookmarkViewController()
		vc.delegate = self

		navigationController?.pushViewController(vc, animated: true)
	}

	@objc private func edit() {
		tableView.setEditing(!tableView.isEditing, animated: true)

		updateButtons()
	}


	// MARK: Private Methods

	private func updateButtons() {
		navigationItem.leftBarButtonItem = tableView.isEditing
			? nil
			: doneBt

		var items = toolbarItems

		items?.append(tableView.isEditing ? doneEditingBt : editBt)

		toolbar.setItems(items, animated: true)
	}

	private lazy var encoder: JSONEncoder = {
		let encoder = JSONEncoder()

		if #available(iOS 13.0, *) {
			encoder.outputFormatting = .withoutEscapingSlashes
		}

		return encoder
	}()

	private lazy var decoder = JSONDecoder()

	private func save(_ bookmark: Bookmark) {
		guard var request = buildRequest(),
			let payload = try? encoder.encode(["url": bookmark.url?.absoluteString,
											   "title": bookmark.name]) else {
												return
		}

		request.httpMethod = "POST"
		request.httpBody = payload

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				print("[\(String(describing: type(of: self)))]#save error=\(error)")
				return
			}

			guard let response = response as? HTTPURLResponse else {
				print("[\(String(describing: type(of: self)))]#save error=No HTTP response")
				return
			}

			guard response.statusCode == 200 else {
				print("[\(String(describing: type(of: self)))]#save statusCode=\(response.statusCode)")
				return
			}

			guard let data = data else {
				print("[\(String(describing: type(of: self)))]#save error=No body")
				return
			}

			if let payload = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
				guard payload["status"] as? String == "success" else {
					print("[\(String(describing: type(of: self)))]#save error=No success")
					return
				}

				guard let item = payload["item"] as? [String: String] else {
					print("[\(String(describing: type(of: self)))]#save error=No valid bookmark item")
					return
				}

				bookmark.id = item["id"]
			}
		}
		task.resume()
	}

	private func delete(_ bookmark: Bookmark) {
		guard let id = bookmark.id,
			var request = buildRequest(id) else {

				return
		}

		request.httpMethod = "DELETE"

		let task = URLSession.shared.dataTask(with: request)
		task.resume()
	}

	/**
	https://nextcloud-bookmarks.readthedocs.io/en/latest/bookmark.html
	*/
	private func buildRequest(_ id: String? = nil) -> URLRequest? {
		guard let server = Settings.nextcloudServer,
			let username = Settings.nextcloudUsername,
			let password = Settings.nextcloudPassword,
			let auth = "\(username):\(password)".data(using: .utf8)?.base64EncodedString(),
			let url = URL(string: "https://\(server)/index.php/apps/bookmarks/public/rest/v2/bookmark\(id != nil ? "/\(id!)" : "")") else {

				return nil
		}

		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")

		JAHPAuthenticatingHTTPProtocol.temporarilyAllow(url)

		return request
	}
}
