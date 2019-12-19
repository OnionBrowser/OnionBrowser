//
//  Bookmark.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//


import UIKit
import FavIcon

@objc
@objcMembers
open class Bookmark: NSObject {

	private static let keyBookmarks = "bookmarks"
	private static let keyVersion = "version"
	private static let keyName = "name"
	private static let keyUrl = "url"
	private static let keyIcon = "icon"

	private static let version = 2

	private static var root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
	private static var bookmarkFilePath = root?.appendingPathComponent("bookmarks.plist")

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
		// Only set up default list of bookmarks, when there's no others.
		if all.count < 1 {
			add(name: "DuckDuckGo", url: "https://3g2upl4pq6kufc4m.onion/")
			add(name: "New York Times", url: "https://mobile.nytimes3xbfgragh.onion/")
			add(name: "BBC", url: "https://bbcnewsv2vjtpsuy.onion/")
			add(name: "Facebook", url: "https://m.facebookcorewwwi.onion/")
			add(name: "ProPublica", url: "https://www.propub3r6espa33w.onion/")
			add(name: "Freedom of the Press Foundation", url: "https://freedom.press/")

			add(name: "Onion Browser landing page", url: "http://3heens4xbedlj57xwcggjsdglot7e36p4rogy642xokemfo2duh6bbyd.onion/")
			add(name: "Onion Browser official site", url: "http://tigas3l7uusztiqu.onion/onionbrowser/")
			add(name: "The Tor Project", url: "http://expyuzz4wqqyqhjn.onion/")
			add(name: "Mike Tigas, Onion Browser author", url: "http://tigas3l7uusztiqu.onion/")

			store()

			DispatchQueue.global(qos: .background).async {
				for bookmark in all {
					bookmark.acquireIcon() {
						store()
					}
				}
			}
        }
	}

	class func add(name: String?, url: String) {
		all.append(Bookmark(name: name, url: url))
	}

	@discardableResult
	class func store() -> Bool {
		if let path = bookmarkFilePath {
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

	func acquireIcon(_ completion: () -> Void) {
		if let url = url {
			Bookmark.icon(for: url) { image in
				self.icon = image
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
