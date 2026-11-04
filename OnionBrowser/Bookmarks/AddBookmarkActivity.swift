//
//  AddBookmarkActivity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.01.20.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
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
		return UIImage(systemName: "bookmark")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		for item in activityItems {
			if !(item is URL) || NcBookmarks.find(item as! URL) != nil {
				return false
			}
		}

		return true
	}

	override func prepare(withActivityItems activityItems: [Any]) {
		urls = activityItems.filter({ $0 is URL }) as? [URL]
	}

	override func perform() {
		Task {
			let tabs = await AppDelegate.shared?.allOpenTabs

			for url in urls ?? [] {
				let title = await MainActor.run {
					// .title contains a call which needs the UI thread.
					tabs?.first(where: { $0.url == url })?.title
				}

				let b = NcBookmark(url: url.absoluteString, title: title ?? "")
				NcBookmarks.root.bookmarks.append(b)

				NcBookmarks.store() // First store, so the user sees it immediately.

				if await b.acquireIcon() {
					// Second store, so the user sees the icon, too.
					NcBookmarks.store()
				}

				do {
					if try await b.upload() {
						// Third store, so we keep the server ID.
						NcBookmarks.store()
					}
				}
				catch {
					Log.error(for: Self.self, "\(error)")
				}
			}

			await MainActor.run {
				activityDidFinish(true)
			}
		}
	}
}
