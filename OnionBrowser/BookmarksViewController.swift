//
//  BookmarksViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2019 jcs. All rights reserved.
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

		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "bookmark")
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

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "bookmark", for: indexPath)

		let bookmark = (isFiltering ? filtered : Bookmark.all)[indexPath.row]

		cell.textLabel?.text = bookmark.name?.isEmpty ?? true
			? bookmark.url?.absoluteString
			: bookmark.name

		cell.textLabel?.adjustsFontSizeToFitWidth = true
		cell.textLabel?.minimumScaleFactor = 0.5

		return cell
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		switch editingStyle {
		case .delete:
			Bookmark.all.remove(at: indexPath.row)
			Bookmark.store()
			tableView.reloadSections(IndexSet(integer: 0), with: .automatic)

		default:
			break
		}
	}

	func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		Bookmark.all.insert(Bookmark.all.remove(at: sourceIndexPath.row), at: destinationIndexPath.row)
		Bookmark.store()
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let vc = BookmarkViewController()
		vc.delegate = self
		vc.index = indexPath.row

		if isFiltering {
			if let index = Bookmark.all.firstIndex(of: filtered[indexPath.row]) {
				vc.index = index
			}
			else {
				tableView.deselectRow(at: indexPath, animated: true)
				return
			}
		}

		navigationController?.pushViewController(vc, animated: true)

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

	@objc func dismiss_() {
		navigationController?.dismiss(animated: true)
	}

    @objc func add() {
		let vc = BookmarkViewController()
		vc.delegate = self

		navigationController?.pushViewController(vc, animated: true)
    }

    @objc func edit() {
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
}
