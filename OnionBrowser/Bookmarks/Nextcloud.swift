//
//  Nextcloud.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 26.02.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI

/**
Implementation of communication with Nextcloud Bookmarks plug-in.

URLs are *unique* in Nextcloud bookmarks, so all comparisons are done against that.

IDs are only fetched on-the-fly in order to avoid having to deal with 2 identifiers.

https://nextcloud-bookmarks.readthedocs.io/en/latest/bookmark.html
*/
class Nextcloud: NSObject {

	typealias Completion = (_ error: Error?) -> ()

	private static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()

		if #available(iOS 13.0, *) {
			encoder.outputFormatting = .withoutEscapingSlashes
		}

		return encoder
	}()

	class func sync(_ completion: Completion? = nil) {
		guard let request = buildRequest(query: "page=-1&folder=-1") else { // Only root folder items.
			completion?(ApiError.noRequestPossible)
			return
		}

		execute(request) { items, error in
			if let error = error {
				print("[\(String(describing: self))]#sync error=\(error)")
				completion?(error)
				return
			}

			for item in items ?? [] {
				guard let url = item.url, !url.isEmpty else {
					continue
				}

				let name = item.title

				// Update title of existing.
				if let bookmark = Bookmark.all.first(where: { $0.url?.absoluteString == url }) {
					if let name = name {
						bookmark.name = name
					}
				}
					// Add non-existing.
				else {
					Bookmark.add(name, url).acquireIcon {
						Bookmark.store()
					}
				}
			}

			Bookmark.store()

			// Upload local-only ones.
			for bookmark in Bookmark.all {
				guard let url = bookmark.url?.absoluteString, !url.isEmpty else {
					continue
				}

				if items?.first(where: { $0.url == url }) == nil {
					store(bookmark)
				}
			}

			completion?(nil)
		}
	}

	class func store(_ bookmark: Bookmark, id: String? = nil, _ completion: Completion? = nil) {
		var json = ["url": bookmark.url?.absoluteString,
					"title": bookmark.name]

		if let id = id {
			json["id"] = id
		}

		guard var request = buildRequest(id),
			let payload = try? encoder.encode(json) else {
				completion?(ApiError.noRequestPossible)
				return
		}

		request.httpMethod = id != nil ? "PUT" : "POST"
		request.httpBody = payload

		execute(request) { items, error in
			if let error = error {
				print("[\(String(describing: self))]#store error=\(error)")
				completion?(error)
				return
			}

			completion?(nil)
		}
	}

	class func delete(_ bookmark: Bookmark, _ completion: Completion? = nil) {
		getId(bookmark) { id in
			guard let id = id,
				var request = buildRequest(id) else {
					completion?(ApiError.noRequestPossible)
					return
			}

			request.httpMethod = "DELETE"

			execute(request) { _, error in
				completion?(error)
			}
		}
	}

	class func getId(_ bookmark: Bookmark, _ completion: ((_ id: String?) -> ())? = nil) {
		guard let url = bookmark.url?.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
			!url.isEmpty,
			let request = buildRequest(query: "url=\(url)") else {
				completion?(nil)
				return
		}

		execute(request) { items, error in
			guard let id = items?.first?.id else {
				completion?(nil)
				return
			}

			completion?(String(id))
		}
	}


	// MARK: Private Methods

	private class func buildRequest(_ id: String? = nil, query: String = "") -> URLRequest? {
		guard let server = Settings.nextcloudServer,
			!server.isEmpty,
			let username = Settings.nextcloudUsername,
			!username.isEmpty,
			let password = Settings.nextcloudPassword,
			!password.isEmpty,
			let auth = "\(username):\(password)".data(using: .utf8)?.base64EncodedString(),
			let url = URL(string: "https://\(server)/index.php/apps/bookmarks/public/rest/v2/bookmark\(id != nil ? "/\(id!)" : "")\(query.isEmpty ? "" : "?\(query)")") else {

				return nil
		}

		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")

		JAHPAuthenticatingHTTPProtocol.temporarilyAllow(url)

		return request
	}

	private class func execute(_ request: URLRequest, _ completion: ((_ items: [Item]?, _ error: Error?) -> ())? = nil) {
		let task = URLSession.shared.apiTask(with: request) { (response: Response?, error) in
			if let error = error {
				completion?(nil, error)
				return
			}

			guard response?.status == "success" else {
				completion?(nil, ApiError.notSuccess(status: response?.status))
				return
			}

			var items = response?.data

			// TODO, can be unavailable (DELETE) or "data" (GET on collection)
			if items == nil, let item = response?.item {
				items = [item]
			}

			completion?(items, nil)
		}
		task.resume()
	}

	private class Response: Codable {

		var status: String?

		var data: [Item]?

		var item: Item?
	}

	private class Item: Codable {

		var id: Int?

		var title: String?

		var url: String?
	}
}
