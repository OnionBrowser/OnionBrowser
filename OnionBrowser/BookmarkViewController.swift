//
//  BookmarkViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit
import Eureka

protocol BookmarkViewControllerDelegate {

	func needsReload()
}

class BookmarkViewController: FormViewController {

	var index: Int?
	var delegate: BookmarkViewControllerDelegate?

	private var bookmark: Bookmark?

    override func viewDidLoad() {
        super.viewDidLoad()

		// Was called via "+" (add).
		if index == nil {
			let tab = AppDelegate.shared()?.webViewController?.curWebViewTab()

			// Check, if this page is already bookmarked. If so, edit that.
			if let bookmark = Bookmark.all.first(where: { $0.url == tab?.url }) {
				self.bookmark = bookmark
				index = Bookmark.all.firstIndex(of: bookmark)
			}
			else {
				bookmark = Bookmark()

				// Check, if we have a URL. If so, prefill with that.
				if let url = tab?.url {
					bookmark?.name = tab?.title?.text
					bookmark?.url = url
				}
			}
		}
		else {
			bookmark = Bookmark.all[index!]
		}

		navigationItem.title = index == nil
			? NSLocalizedString("Add Bookmark", comment: "Scene titlebar")
			: NSLocalizedString("Edit Bookmark", comment: "Scene title")

		if index == nil {
			navigationItem.rightBarButtonItem = UIBarButtonItem(
				barButtonSystemItem: .save, target: self, action: #selector(save))

			// Don't allow to store empty bookmarks.
			if bookmark?.url == nil {
				navigationItem.rightBarButtonItem?.isEnabled = false
			}
		}

		form
			+++ TextRow() {
				$0.placeholder = NSLocalizedString("Title", comment: "Bookmark title placeholder")
				$0.value = bookmark?.name
			}
			.onChange({ row in
				self.bookmark?.name = row.value

				if self.index != nil {
					self.store()
				}
			})
			<<< URLRow() {
				$0.placeholder = NSLocalizedString("Address", comment: "Bookmark URL placeholder")
				$0.value = bookmark?.url
			}
			.onChange({ row in
				if let value = row.value {
					self.bookmark?.url = value

					self.navigationItem.rightBarButtonItem?.isEnabled = true

					if self.index != nil {
						self.store()
					}
				}
			})
    }

	@objc private func save() {
		store()

		navigationController?.popViewController(animated: true)
	}

	private func store() {
		if index == nil,
			let bookmark = bookmark {

			Bookmark.all.append(bookmark)

			index = Bookmark.all.firstIndex(of: bookmark)
		}

		Bookmark.store()

		delegate?.needsReload()
	}
}
