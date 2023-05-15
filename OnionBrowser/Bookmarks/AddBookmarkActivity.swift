//
//  AddBookmarkActivity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class AddBookmarkActivity: UIActivity {

	private var urls: [URL]?

	override var activityType: UIActivity.ActivityType? {
		return ActivityType(String(describing: type(of: self)))
	}

	override var activityTitle: String? {
		return NSLocalizedString("Add Bookmark", comment: "")
	}

	override var activityImage: UIImage? {
		return UIImage(named: "bookmarks")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		for item in activityItems {
			if !(item is URL) || Bookmark.contains(url: item as! URL) {
				return false
			}
		}

		return true
	}

	override func prepare(withActivityItems activityItems: [Any]) {
		urls = activityItems.filter({ $0 is URL }) as? [URL]
	}

	override func perform() {
		DispatchQueue.global(qos: .userInitiated).async {
			let tabs = AppDelegate.shared?.allOpenTabs

			for url in self.urls ?? [] {
				var title: String?

				// .title contains a call which needs the UI thread.
				DispatchQueue.main.sync {
					title = tabs?.first(where: { $0.url == url })?.title
				}

				let b = Bookmark.add(title, url.absoluteString)
				Bookmark.store() // First store, so the user sees it immediately.

				Nextcloud.getId(b) { id in
					Nextcloud.store(b, id: id)
				}

				b.acquireIcon { updated in
					if updated {
						// Second store, so the user sees the icon, too.
						Bookmark.store()
					}
				}
			}

			DispatchQueue.main.async {
				self.activityDidFinish(true)
			}
		}
	}
}
