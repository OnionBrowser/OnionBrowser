//
//  BookmarksViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import ProgressHUD

protocol BookmarksViewControllerDelegate {

	func needsReload()
}

class BookmarksViewController: UIViewController, UITableViewDataSource,
							   UITableViewDelegate, UISearchResultsUpdating,
							   BookmarksViewControllerDelegate, UIDocumentPickerDelegate
{
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var toolbar: UIToolbar!

	private lazy var doneBt = UIBarButtonItem(barButtonSystemItem: .done,
											  target: self, action: #selector(dismiss_))

	private lazy var doneEditingBt = UIBarButtonItem(barButtonSystemItem: .done,
													 target: self, action: #selector(edit))
	private lazy var editBt = UIBarButtonItem(barButtonSystemItem: .edit,
											  target: self, action: #selector(edit))

	private let searchController = UISearchController(searchResultsController: nil)
	private var filtered = [NcBookmark]()

	var folder: NcFolder = NcBookmarks.root

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
			UIBarButtonItem(image: NcFolder.icon, style: .plain, target: self, action: #selector(addFolder)),
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)]

		toolbarItems?.first?.accessibilityLabel = NSLocalizedString("Add Bookmark", comment: "")
		toolbarItems?[1].accessibilityLabel = NSLocalizedString("Add Folder", comment: "")

		if folder.id == -1 {
			toolbarItems?.append(contentsOf: [
				UIBarButtonItem(title: NSLocalizedString("Sync", comment: ""), style: .plain,
								target: self, action: #selector(showSyncScene)),
				UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)])
		}

		navigationItem.title = folder.title.isEmpty ? NSLocalizedString("Bookmarks", comment: "Scene title") : folder.title

		navigationItem.rightBarButtonItems = [
			.init(image: .init(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(exportBookmarks)),
			.init(image: .init(systemName: "square.and.arrow.down"), style: .plain, target: self, action: #selector(importBookmarks))]
		navigationItem.rightBarButtonItems?.first?.accessibilityLabel = NSLocalizedString("Import Bookmarks", comment: "")
		navigationItem.rightBarButtonItems?.last?.accessibilityLabel = NSLocalizedString("Export Bookmarks", comment: "")

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

	func numberOfSections(in tableView: UITableView) -> Int {
		2
	}

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == 0 {
			return folder.folders.count
		}

		return isFiltering ? filtered.count : folder.bookmarks.count
	}

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return BookmarkCell.height
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: BookmarkCell.reuseId, for: indexPath) as! BookmarkCell

		if indexPath.section == 0 {
			return cell.set(folder.folders[indexPath.row])
		}

		return cell.set((isFiltering ? filtered : folder.bookmarks)[indexPath.row])
	}

	func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return !isFiltering
	}

	/**
	 Limits moves within their own section.
	 */
	func tableView(_ tableView: UITableView,
				   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
				   toProposedIndexPath proposedDestinationIndexPath: IndexPath
	) -> IndexPath {
		if sourceIndexPath.section != proposedDestinationIndexPath.section {
			var row = 0

			if sourceIndexPath.section < proposedDestinationIndexPath.section {
				row = tableView.numberOfRows(inSection: sourceIndexPath.section) - 1
			}

			return IndexPath(row: row, section: sourceIndexPath.section)
		}

		return proposedDestinationIndexPath
	}

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete else {
			return
		}

		if indexPath.section == 0 {
			let subfolder = folder.folders[indexPath.row]

			folder.folders.remove(at: indexPath.row)

			Task {
				do {
					try await NcServer.delete(subfolder)
				}
				catch {
					Log.error(for: Self.self, "\(error)")
				}
			}
		}
		else {
			let bookmark = folder.bookmarks[indexPath.row]
			bookmark.icon = nil // Delete icon file.

			folder.bookmarks.remove(at: indexPath.row)

			if #available(iOS 18.0, *) {
				BookmarkEntity.remove(bookmark: bookmark)
			}

			Task {
				do{
					try await NcServer.delete(bookmark)
				}
				catch {
					Log.error(for: Self.self, "\(error)")
				}
			}
		}

		NcBookmarks.store()

		tableView.reloadSections([indexPath.section], with: .automatic)
	}

	func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		if sourceIndexPath.section == 0 && destinationIndexPath.section == 0 {
			folder.folders.insert(folder.folders.remove(at: sourceIndexPath.row), at: destinationIndexPath.row)

			NcBookmarks.store()
		}
		else if sourceIndexPath.section > 0 && destinationIndexPath.section > 0 {
			folder.bookmarks.insert(folder.bookmarks.remove(at: sourceIndexPath.row), at: destinationIndexPath.row)

			NcBookmarks.store()
		}
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		var index: Int? = indexPath.row

		if isFiltering {
			index = folder.bookmarks.firstIndex(of: filtered[index!])
		}

		if let index {
			if tableView.isEditing {
				if indexPath.section == 0 {
					let vc = FolderViewController()
					vc.delegate = self
					vc.index = index
					vc.parentFolder = folder

					navigationController?.pushViewController(vc, animated: true)
				}
				else {
					let vc = BookmarkViewController()
					vc.delegate = self
					vc.index = index
					vc.folder = folder

					navigationController?.pushViewController(vc, animated: true)
				}
			}
			else if indexPath.section == 0 {
				let folder = folder.folders[index]

				let vc = BookmarksViewController()
				vc.folder = folder

				navigationController?.pushViewController(vc, animated: true)
			}
			else {
				let bookmark = folder.bookmarks[index]

				view.sceneDelegate?.browsingUi.addNewTab(
					URL(string: bookmark.url), transition: .notAnimated) { [weak self] _ in
						self?.dismiss_()
					}
			}
		}

		tableView.deselectRow(at: indexPath, animated: false)
	}


	// MARK: UISearchResultsUpdating

	func updateSearchResults(for searchController: UISearchController) {
		if let search = searchController.searchBar.text?.lowercased() {
			filtered = folder.bookmarks.filter() {
				$0.title.lowercased().contains(search)
					|| $0.url.lowercased().contains(search)
			}
		}
		else {
			filtered.removeAll()
		}

		tableView.reloadData()
	}


	// MARK: BookmarksViewControllerDelegate

	func needsReload() {
		_needsReload = true
	}


	// MARK: UIDocumentPickerDelegate

	func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
		guard let file = urls.first else {
			return
		}

		let data: Data

		do {
			data = try Data(contentsOf: file)
		}
		catch {
			return AlertHelper.present(self, message: error.localizedDescription)
		}

		guard let contents = String(data: data, encoding: .utf8) else {
			return
		}

		ProgressHUD.animate()

		Task {
			var err: Error? = nil

			do {
				try await MozillaBookmarks.import(contents)
			}
			catch {
				if case ApiError.noRequestPossible = error {
					// This just means, that no sync is set up.
				}
				else {
					Log.error(for: Self.self, error.localizedDescription)

					err = error
				}
			}

			await MainActor.run {
				if let err {
					ProgressHUD.error(err.localizedDescription, delay: 3)
				}
				else {
					ProgressHUD.succeed()
				}

				tableView.reloadData()
			}
		}
	}


	// MARK: Actions

	@objc private func dismiss_() {
		navigationController?.dismiss(animated: true)
	}

	@objc private func exportBookmarks(sender: UIBarButtonItem) {
		do {
			let exported = try MozillaBookmarks.export(folder)

			let vc = UIActivityViewController(activityItems: [exported], applicationActivities: nil)
			vc.modalPresentationStyle = .popover
			vc.popoverPresentationController?.barButtonItem = sender

			present(vc, animated: true)
		}
		catch {
			AlertHelper.present(self, message: error.localizedDescription)
		}
	}

	@objc private func importBookmarks() {
		let vc = UIDocumentPickerViewController(forOpeningContentTypes: [.html], asCopy: true)
		vc.delegate = self

		present(vc)
	}

	@objc private func add() {
		let vc = BookmarkViewController()
		vc.delegate = self
		vc.folder = folder

		navigationController?.pushViewController(vc, animated: true)
	}

	@objc private func addFolder() {
		let vc = FolderViewController()
		vc.delegate = self
		vc.parentFolder = folder

		navigationController?.pushViewController(vc, animated: true)
	}

	@objc private func edit() {
		tableView.setEditing(!tableView.isEditing, animated: true)

		updateButtons()
	}

	@objc private func showSyncScene() {
		let vc = SyncViewController()
		vc.delegate = self

		navigationController?.pushViewController(vc, animated: true)
	}


	// MARK: Private Methods

	private func updateButtons() {
		if tableView.isEditing || folder.id != -1 {
			navigationItem.leftBarButtonItem = nil
		}
		else {
			navigationItem.leftBarButtonItem = doneBt
		}

		var items = toolbarItems

		items?.append(tableView.isEditing ? doneEditingBt : editBt)

		toolbar.setItems(items, animated: true)
	}
}
