//
//  NcServer.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 24.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import Foundation

class NcServer {

	private enum ItemType: String {
		case folder
		case bookmark
	}

	private static let encoder: JSONEncoder = {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .withoutEscapingSlashes

		return encoder
	}()


	// MARK: Public Methods

	class func sync() async throws {
		guard let request = build(for: .folder, nil) else {
			throw ApiError.noRequestPossible
		}

		let folders: [NcFolder]? = try await call(request)

		try await syncFolder(NcBookmarks.root, .init(id: -1, title: "", folders: folders ?? []))

		try await syncBookmarks(NcBookmarks.root)

		NcBookmarks.store()
	}

	class func store(_ bookmark: NcBookmark) async throws -> NcBookmark? {
		let id = try await findId(for: bookmark)

		guard var request = build(for: .bookmark, id) else {
			return nil
		}

		request.httpMethod = id != nil ? "PUT" : "POST"
		request.httpBody = try encoder.encode(bookmark)

		return try await call(request)?.first
	}

	class func store(_ folder: NcFolder) async throws -> NcFolder? {
		guard var request = build(for: .folder, folder.id) else {
			return nil
		}

		request.httpMethod = folder.id != nil ? "PUT" : "POST"
		request.httpBody = try encoder.encode(folder)

		return try await call(request)?.first
	}

	class func delete(_ bookmark: NcBookmark) async throws {
		guard let id = try await findId(for: bookmark),
			  var request = build(for: .bookmark, id)
		else {
			return
		}

		request.httpMethod = "DELETE"

		let _: [NcBookmark]? = try await call(request)
	}

	class func delete(_ folder: NcFolder) async throws {
		guard let id = folder.id,
			  var request = build(for: .folder, id)
		else {
			return
		}

		request.httpMethod = "DELETE"

		let _: [NcFolder]? = try await call(request)
	}


	// MARK: Private Methods

	private class func findId(for bookmark: NcBookmark) async throws -> Int? {
		if bookmark.id != nil {
			return bookmark.id
		}

		guard let request = build(
			for: .bookmark,
			query: [.init(name: "url", value: bookmark.url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))])
		else {
			return nil
		}

		let bookmarks: [NcBookmark]? = try await call(request)

		return bookmarks?.first?.id
	}

	private class func build(for type: ItemType, _ id: Int? = nil, query: [URLQueryItem] = []) -> URLRequest? {
		guard let server = Settings.nextcloudServer,
			  !server.isEmpty,
			  let username = Settings.nextcloudUsername,
			  !username.isEmpty,
			  let password = Settings.nextcloudPassword,
			  !password.isEmpty,
			  let auth = "\(username):\(password)".data(using: .utf8)?.base64EncodedString(),
			  var urlc = URLComponents(string: "https://\(server)/index.php/apps/bookmarks/public/rest/v2")
		else {
			return nil
		}

		urlc.queryItems = query

		guard var url = urlc.url else {
			return nil
		}

		url = url.appendingPathComponent(type.rawValue)

		if let id {
			url = url.appendingPathComponent(String(id))
		}

		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")

		return request
	}

	private class func call<T: Codable>(_ request: URLRequest) async throws -> [T]? {
		let response: NcResponse<T>? = try await TorManager.shared.session().api(for: request)

		guard response?.status == "success" else {
			throw ApiError.notSuccess(status: response?.status)
		}

		var items = response?.data

		if items == nil, let item = response?.item {
			items = [item]
		}

		return items
	}

	private class func syncFolder(_ local: NcFolder, _ remote: NcFolder) async throws {
		local.id = remote.id
		local.title = remote.title

		for rsf in remote.folders {
			if let lsf = local.folders.first(where: { $0.id != nil && $0.id == rsf.id }) {
				try await syncFolder(lsf, rsf)
			}
			else if let lsf = local.folders.first(where: { $0.id == nil && $0.title == rsf.title }) {
				try await syncFolder(lsf, rsf)
			}
			else {
				local.folders.append(rsf)
			}
		}

		// Upload local ones which don't exist remotely, yet.
		for lsf in local.folders {
			guard lsf.id == nil || !remote.folders.contains(where: { $0.id == lsf.id }) else {
				continue
			}

			// Make sure the parentFolder is set correctly before creation on the server.
			lsf.parentFolder = local.id

			_ = try await lsf.upload()
		}
	}

	private class func syncBookmarks(_ localFolder: NcFolder) async throws {
		guard let id = localFolder.id,
			  let request = build(for: .bookmark, nil, query: [.init(name: "page", value: "-1"), .init(name: "folder", value: "\(id)")])
		else {
			throw ApiError.noRequestPossible
		}

		let bookmarks: [NcBookmark]? = try await call(request)

		// Update/insert remote bookmarks into local copy.
		for remote in bookmarks ?? [] {
			// Update existing with same ID.
			if let local = localFolder.bookmarks.first(where: { $0.id != nil && $0.id == remote.id }) {
				try await syncBookmark(id, local, remote)
			}
			// Update existing with same URL.
			else if let local = localFolder.bookmarks.first(where: { $0.id == nil && $0.url == remote.url }) {
				local.id = remote.id

				try await syncBookmark(id, local, remote)
			}
			// Insert new.
			else {
				localFolder.bookmarks.append(remote)
			}
		}

		// Make sure icons are available.
		await withTaskGroup(of: Void.self) { group in
			for local in localFolder.bookmarks {
				group.addTask {
					_ = await local.acquireIcon()
				}
			}

			await group.waitForAll()
		}

		// Upload local ones which don't exist remotely.
		for local in localFolder.bookmarks {
			guard local.id == nil || !(bookmarks?.contains(where: { $0.id == local.id }) ?? false) else {
				continue
			}

			// Make sure the folder is set correctly before updating on the server.
			local.folders = [id]

			_ = try await local.upload()
		}

		for local in localFolder.folders {
			try await syncBookmarks(local)
		}
	}

	private class func syncBookmark(_ id: Int, _ local: NcBookmark, _ remote: NcBookmark) async throws {
		if local.lastModified <= remote.lastModified {
			local.url = remote.url
			local.title = remote.title
			local.desc = remote.desc
			local.lastModified = remote.lastModified
		}
		else {
			// Make sure the parentFolder is set correctly before updating on the server.
			local.folders = [id]

			_ = try await local.upload()
		}
	}
}

private class NcResponse<T: Codable>: Codable {

	var status: String?

	var data: [T]?

	var item: T?
}
