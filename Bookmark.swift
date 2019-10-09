//
//  Bookmark.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

@objc
@objcMembers
open class Bookmark: NSObject {

	private static let keyBookmarks = "bookmarks"
	private static let keyVersion = "version"
	private static let keyName = "name"
	private static let keyUrl = "url"

	private static let version = 1

	private static var path: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
		.last?.appendingPathComponent("bookmarks.plist")

	static var all: [Bookmark] = {
		var bookmarks = [Bookmark]()

		if let path = path {
			let data = NSDictionary(contentsOf: path)

			for b in data?[keyBookmarks] as? [NSDictionary] ?? [] {
				bookmarks.append(Bookmark(b))
			}
		}

		return bookmarks
	}()

	class func add(name: String?, url: String) {
		all.append(Bookmark(name: name, url: url))
	}

	@discardableResult
	class func store() -> Bool {
		if let path = path {
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

	init(name: String? = nil, url: String? = nil) {
		super.init()

		self.name = name

		if let url = url {
			self.url = URL(string: url)
		}
	}

	convenience init(_ dic: NSDictionary) {
		self.init(name: dic[Bookmark.keyName] as? String,
				  url: dic[Bookmark.keyUrl] as? String)
	}

	private func asDic() -> NSDictionary {
		return NSDictionary(dictionary: [
			Bookmark.keyName: name ?? "",
			Bookmark.keyUrl: url?.absoluteString ?? "",
		])
	}
}
