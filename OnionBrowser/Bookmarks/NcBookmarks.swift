//
//  NcBookmarks.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 23.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

class NcBookmarks {

	static var rootDir = FileManager.default.docsDir

	static var root: NcFolder = {

		// Migrate from old storage format.
		if let oldStorageFile,
		   let data = NSDictionary(contentsOf: oldStorageFile)
		{
			let root = NcFolder(id: -1, title: "")

			for d in data["bookmarks"] as? [NSDictionary] ?? [] {
				if let url = d["url"] as? String,
				   let title = d["name"] as? String
				{
					let b = NcBookmark(
						url: url,
						title: title,
						lastModified: Int(d["last_updated"] as? TimeInterval ?? Date().timeIntervalSince1970),
						folder: root,
						iconName: d["icon"] as? String)

					root.bookmarks.append(b)
				}
			}

			if let storageFile {
				// Written a second time here to avoid a circular call.
				do {
					try encoder.encode(root).write(to: storageFile, options: .atomic)
				}
				catch {
					Log.error(for: NcBookmarks.self, "\(error)")
				}

				// Successfully stored in new format. Remove old stuff.
				if storageFile.exists {
					try? FileManager.default.removeItem(at: oldStorageFile)
				}
			}

			if #available(iOS 18.0, *) {
				BookmarkEntity.add(folder: root)
			}

			return root
		}

		if let storageFile,
		   let data = try? Data(contentsOf: storageFile),
		   let root = try? PropertyListDecoder().decode(NcFolder.self, from: data)
		{

			if #available(iOS 18.0, *) {
				BookmarkEntity.add(folder: root)
			}

			return root
		}

		return .init(id: -1, title: "")
	}()


	private static let storageFile = rootDir?.appendingPathComponent("nc_bookmarks.plist")
	private static let oldStorageFile = rootDir?.appendingPathComponent("bookmarks.plist")

	private static let encoder = PropertyListEncoder()

	private static var startPageNeedsUpdate = true

	private static let defaultBookmarks: [NcBookmark] = {
		var defaults = [NcBookmark]()

		defaults.append(.init(url: "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/", title: "DuckDuckGo"))
		defaults.append(.init(url: "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/", title: "BBC"))
		defaults.append(.init(url: "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/", title: "ProPublica"))
		defaults.append(.init(url: "http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/", title: "Freedom of the Press Foundation"))
		defaults.append(.init(url: "https://www.dwnewsgngmhlplxy6o2twtfgjnrnjxbegbwqx6wnotdhkzt562tszfid.onion/", title: "Deutsche Welle"))

		defaults.append(.init(url: "http://juhanurmihxlp77nkq76byazcldy2hlmovfu2epvl5ankdibsot4csyd.onion/", title: "Ahmia"))

		defaults.append(.init(url: "https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/", title: "Facebook"))

		defaults.append(.init(url: "https://onionbrowser.com", title: "Onion Browser official site"))
		defaults.append(.init(url: "http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/", title: "The Tor Project"))

		return defaults
	}()

	private static let v2ToV3 = [
		"https://3g2upl4pq6kufc4m.onion/": "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/",
		"https://bbcnewsv2vjtpsuy.onion/": "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/",
		"https://m.facebookcorewwwi.onion/": "https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/",
		"https://www.propub3r6espa33w.onion/": "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/",
		"https://freedom.press/": "http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/",
		"http://expyuzz4wqqyqhjn.onion/": "http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/"]


	// MARK: Public Methods

	class func store() {
		guard let storageFile else {
			return
		}

		// Trigger update of start page when things changed.
		startPageNeedsUpdate = true

		do {
			try encoder.encode(root).write(to: storageFile, options: .atomic)
		}
		catch {
			Log.error(for: Self.self, "\(error)")
		}
	}

	class func updateStartPage(force: Bool = false) {
		guard let source = Bundle.main.url(forResource: "start", withExtension: "html") else {
			return
		}

		// Always update after start. Language could have been changed.
		if !startPageNeedsUpdate && !force {
			if let dm = (try? URL.start.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
			   let sm = (try? source.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
			{
				if dm > sm {
					return
				}
			}
		}

		try? FileTranslator.translate(
			Bundle.main.url(forResource: "security-levels", withExtension: "html"),
			to: .securityLevels, with: "SecurityLevels")

		guard var template = try? String(contentsOf: source) else {
			return
		}

		if Settings.disableBookmarksOnStartPage {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "display: none")
		}
		else {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "")

			let bookmarks = root.bookmarks

			// Render bookmarks.
			for i in 0 ... 5 {
				let url: String
				let name: String
				let icon: UIImage

				if bookmarks.count > i {
					let tempUrl = bookmarks[i].url

					url = tempUrl

					name = bookmarks[i].title.isEmpty ? URL(string: url)?.host ?? "" : bookmarks[i].title
					icon = bookmarks[i].icon ?? NcBookmark.defaultIcon
				}
				else {
					if i < defaultBookmarks.count {
						// Make sure that the first 6 default bookmarks are available!
						url = defaultBookmarks[i].url
						name = defaultBookmarks[i].title.isEmpty ? URL(string: url)?.host ?? "" : defaultBookmarks[i].title
						icon = defaultBookmarks[i].icon ?? NcBookmark.defaultIcon
					}
					else {
						url = ""
						name = ""
						icon = NcBookmark.defaultIcon
					}
				}

				template = template
					.replacingOccurrences(of: "{{ bookmark_url_\(i) }}", with: url)
					.replacingOccurrences(of: "{{ bookmark_name_\(i) }}", with: name)
					.replacingOccurrences(of: "{{ bookmark_icon_\(i) }}",
						with: "data:image/png;base64,\(icon.pngData()?.base64EncodedString() ?? "")")
			}
		}

		template = template
			.replacingOccurrences(of: "{{ Onion Browser }}",
								  with: Bundle.main.displayName)
			.replacingOccurrences(of: "{{ Learn more about Onion Browser }}",
								  with: String(format: NSLocalizedString("Learn more about %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Donate to Onion Browser }}",
								  with: String(format: NSLocalizedString("Donate to %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Subscribe to Tor Newsletter }}",
								  with: NSLocalizedString("Subscribe to Tor Newsletter", comment: ""))

		try? template.write(to: URL.start, atomically: true, encoding: .utf8)

		startPageNeedsUpdate = false
	}

	class func firstRunSetup() {
		guard !Settings.bookmarkFirstRunDone else {
			return
		}

		// Only set up default list of bookmarks, when there's no others.
		guard root.bookmarks.count < 1 else {
			Settings.bookmarkFirstRunDone = true

			return
		}

		root.bookmarks.append(contentsOf: defaultBookmarks)

		store()

		Task {
			await recurse(root) { bookmark in
				if await bookmark.acquireIcon() {
					store()
				}

				return false
			}

			Settings.bookmarkFirstRunDone = true
		}
	}

	class func migrateToV3() {
		guard !Settings.bookmarksMigratedToOnionV3 else {
			return
		}

		recurse(root) { bookmark in
			if let v3 = v2ToV3[bookmark.url]
			{
				bookmark.url = v3
			}

			return false
		}

		store()

		Settings.bookmarksMigratedToOnionV3 = true

		Task {
			await recurse(root) { bookmark in
				if await bookmark.acquireIcon() {
					store()
				}

				return false
			}
		}
	}

	class func find(_ lambda: (_ bookmark: NcBookmark) -> Bool) -> [NcBookmark] {
		return recurse(root, lambda)
	}

	class func find(_ url: URL) -> NcBookmark? {
		let url = url.absoluteString

		return find({ bookmark in
			return bookmark.url == url
		}).first
	}


	// MARK: Private Methods

	@discardableResult
	private class func recurse(_ folder: NcFolder, _ lambda: (_ bookmark: NcBookmark) async -> Bool) async -> NcBookmark? {
		for bookmark in folder.bookmarks {
			if await lambda(bookmark) {
				return bookmark
			}
		}

		for folder in folder.folders {
			if let bookmark = await recurse(folder, lambda) {
				return bookmark
			}
		}

		return nil
	}

	@discardableResult
	private class func recurse(_ folder: NcFolder, _ lambda: (_ bookmark: NcBookmark) -> Bool) -> [NcBookmark] {
		var result = [NcBookmark]()

		for bookmark in folder.bookmarks {
			if lambda(bookmark) {
				result.append(bookmark)
			}
		}

		for folder in folder.folders {
			result.append(contentsOf: recurse(folder, lambda))
		}

		return result
	}
}
