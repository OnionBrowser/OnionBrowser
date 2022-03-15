//
//  Bookmark.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//


import UIKit
import FavIcon

@objc
@objcMembers
open class Bookmark: NSObject {

	static let defaultIcon = UIImage(named: "default-icon")!

	private static let keyBookmarks = "bookmarks"
	private static let keyVersion = "version"
	private static let keyName = "name"
	private static let keyUrl = "url"
	private static let keyIcon = "icon"

	private static let version = 2

	private static var root = FileManager.default.docsDir
	private static var bookmarkFilePath = root?.appendingPathComponent("bookmarks.plist")

	private static let defaultBookmarks: [Bookmark] = {
		var defaults = [Bookmark]()

		defaults.append(Bookmark(name: "DuckDuckGo", url: "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/"))
		defaults.append(Bookmark(name: "New York Times", url: "https://www.nytimesn7cgmftshazwhfgzm37qxb44r64ytbb2dj3x62d2lljsciiyd.onion/"))
		defaults.append(Bookmark(name: "BBC", url: "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/"))
		defaults.append(Bookmark(name: "ProPublica", url: "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/"))
		defaults.append(Bookmark(name: "Freedom of the Press Foundation", url: "http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/"))
		defaults.append(Bookmark(name: "Deutsche Welle", url: "https://www.dwnewsgngmhlplxy6o2twtfgjnrnjxbegbwqx6wnotdhkzt562tszfid.onion/"))

		defaults.append(Bookmark(name: "Facebook", url: "https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/"))
		defaults.append(Bookmark(name: "Twitter", url: "https://twitter3e4tixl4xyajtrzo62zg5vztmjuricljdp2c5kshju4avyoid.onion/"))

		defaults.append(Bookmark(name: "Onion Browser official site", url: "https://onionbrowser.com"))
		defaults.append(Bookmark(name: "The Tor Project", url: "http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/"))

		return defaults
	}()

	private static let v2ToV3 = [
		"https://3g2upl4pq6kufc4m.onion/": "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion/",
		"https://mobile.nytimes3xbfgragh.onion/": "https://www.nytimesn7cgmftshazwhfgzm37qxb44r64ytbb2dj3x62d2lljsciiyd.onion/",
		"https://bbcnewsv2vjtpsuy.onion/": "https://www.bbcnewsd73hkzno2ini43t4gblxvycyac5aw4gnv7t2rccijh7745uqd.onion/",
		"https://m.facebookcorewwwi.onion/": "https://m.facebookwkhpilnemxj7asaniu7vnjjbiltxjqhye3mhbshg7kx5tfyd.onion/",
		"https://www.propub3r6espa33w.onion/": "https://p53lf57qovyuvwsc6xnrppyply3vtqm7l6pcobkmyqsiofyeznfu5uqd.onion/",
		"https://freedom.press/": "http://fpfjxcrmw437h6z2xl3w4czl55kvkmxpapg37bbopsafdu7q454byxid.onion/",
		"http://expyuzz4wqqyqhjn.onion/": "http://2gzyxa5ihm7nsggfxnu52rck2vv4rvmdlkiu3zzui5du4xyclen53wid.onion/"]

	private static var startPageNeedsUpdate = true

	static var all: [Bookmark] = {

		// Init FavIcon config here, because all code having to do with bookmarks should come along here anyway.
		FavIcon.downloadSession = URLSession.shared
		FavIcon.authorize = { url in
			JAHPAuthenticatingHTTPProtocol.temporarilyAllow(url)

			return true
		}

		var bookmarks = [Bookmark]()

		if let path = bookmarkFilePath {
			let data = NSDictionary(contentsOf: path)

			for b in data?[keyBookmarks] as? [NSDictionary] ?? [] {
				bookmarks.append(Bookmark(b))
			}
		}

		return bookmarks
	}()

	class func firstRunSetup() {
		guard !Settings.bookmarkFirstRunDone else {
			return
		}

		// Only set up default list of bookmarks, when there's no others.
		guard all.count < 1 else {
			Settings.bookmarkFirstRunDone = true

			return
		}

		all.append(contentsOf: defaultBookmarks)

		store()

		DispatchQueue.global(qos: .background).async {
			for bookmark in all {
				bookmark.acquireIcon() {
					store()
				}
			}

			Settings.bookmarkFirstRunDone = true
		}
	}

	class func migrateToV3() {
		guard !Settings.bookmarksMigratedToOnionV3 else {
			return
		}

		for bookmark in all {
			if let v2 = bookmark.url?.absoluteString,
			   let v3 = v2ToV3[v2]
			{
				bookmark.url = URL(string: v3)
			}
		}

		store()

		Settings.bookmarksMigratedToOnionV3 = true

		DispatchQueue.global(qos: .background).async {
			for bookmark in all {
				bookmark.acquireIcon() {
					store()
				}
			}
		}
	}

	class func updateStartPage(force: Bool = false) {
		guard let source = Bundle.main.url(forResource: "start", withExtension: "html") else {
			return
		}

		// Always update after start. Language could have been changed.
		if !startPageNeedsUpdate && !force {
			let fm = FileManager.default

			// If files exist and destination is newer than source, don't do anything. (Upgrades!)
			if let dm = try? fm.attributesOfItem(atPath: URL.start.path)[.modificationDate] as? Date,
				let sm = try? fm.attributesOfItem(atPath: source.path)[.modificationDate] as? Date {

				if dm > sm {
					return
				}
			}
		}

		guard var template = try? String(contentsOf: source) else {
			return
		}

		if Settings.disableBookmarksOnStartPage {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "display: none")
		}
		else {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "")

			// Render bookmarks.
			for i in 0 ... 5 {
				let url: URL
				let name: String
				let icon: UIImage

				if all.count > i,
					let tempUrl = all[i].url {

					url = tempUrl

					name = all[i].name ?? url.host!
					icon = all[i].icon ?? Bookmark.defaultIcon
				}
				else {
					// Make sure that the first 6 default bookmarks are available!
					url = defaultBookmarks[i].url!
					name = defaultBookmarks[i].name ?? url.host!
					icon = defaultBookmarks[i].icon ?? Bookmark.defaultIcon
				}

				template = template
					.replacingOccurrences(of: "{{ bookmark_url_\(i) }}", with: url.absoluteString)
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

	@discardableResult
	class func add(_ name: String?, _ url: String) -> Bookmark {
		let bookmark = Bookmark(name: name, url: url)

		all.append(bookmark)

		return bookmark
	}

	@discardableResult
	class func store() -> Bool {
		if let path = bookmarkFilePath {

			// Trigger update of start page when things changed.
			startPageNeedsUpdate = true

			for tab in AppDelegate.shared?.browsingUi?.tabs ?? [] {
				if tab.url == URL.start {
					DispatchQueue.main.async {
						tab.refresh()
					}
				}
			}

			let bookmarks = NSMutableArray()

			for b in all {
				bookmarks.add(b.asDic())
			}

			let data = NSMutableDictionary()
			data[keyBookmarks] = bookmarks
			data[keyVersion] = version
			
			return data.write(to: path, atomically: true)
		}

		return false
	}

	@objc(containsUrl:)
	class func contains(url: URL) -> Bool {
		return all.contains { $0.url == url }
	}

	var name: String?
	var url: URL?

	private var iconName = ""

	private var _icon: UIImage?
	var icon: UIImage? {
		get {
			if _icon == nil && !iconName.isEmpty,
				let path = Bookmark.root?.appendingPathComponent(iconName).path {

				_icon = UIImage(contentsOfFile: path)
			}

			return _icon
		}
		set {
			_icon = newValue

			// Remove old icon, if it gets deleted.
			if _icon == nil {
				if !iconName.isEmpty,
					let path = Bookmark.root?.appendingPathComponent(iconName) {

					try? FileManager.default.removeItem(at: path)
				}

				iconName = ""
			}

			if _icon != nil {
				if iconName.isEmpty {
					iconName = UUID().uuidString
				}

				if let path = Bookmark.root?.appendingPathComponent(iconName) {
					try? _icon?.pngData()?.write(to: path)
				}
			}
		}
	}

	init(name: String? = nil, url: String? = nil, icon: UIImage? = nil) {
		super.init()

		self.name = name

		if let url = url {
			self.url = URL(string: url)
		}

		self.icon = icon
	}

	init(name: String?, url: String?, iconName: String) {
		super.init()

		self.name = name

		if let url = url {
			self.url = URL(string: url)
		}

		self.iconName = iconName
	}

	convenience init(_ dic: NSDictionary) {
		self.init(name: dic[Bookmark.keyName] as? String,
				  url: dic[Bookmark.keyUrl] as? String,
				  iconName: dic[Bookmark.keyIcon] as? String ?? "")
	}


	// MARK: Public Methods

	class func icon(for url: URL, _ completion: @escaping (_ image: UIImage?) -> Void) {
		try! FavIcon.downloadPreferred(url, width: 128, height: 128) { result in
			if case let .success(image) = result {
				completion(image)
			}
			else {
				completion(nil)
			}
		}

	}

	func acquireIcon(_ completion: @escaping () -> Void) {
		if let url = url {
			Bookmark.icon(for: url) { image in
				self.icon = image

				completion()
			}
		}
	}


	// MARK: Private Methods

	private func asDic() -> NSDictionary {
		return NSDictionary(dictionary: [
			Bookmark.keyName: name ?? "",
			Bookmark.keyUrl: url?.absoluteString ?? "",
			Bookmark.keyIcon: iconName,
		])
	}
}
