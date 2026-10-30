//
//  NcFolder.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 23.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

/**
 https://nextcloud-bookmarks.readthedocs.io/en/latest/folder.html
 */
class NcFolder: Codable, Equatable, CustomStringConvertible {

	enum CodingKeys: String, CodingKey {
		case id
		case title
		case parentFolder = "parent_folder"
		case children

		// This is *not* part of Nextcloud bookmarks, but used internally.
		case _bookmarks = "bookmarks"
	}


	static func == (lhs: NcFolder, rhs: NcFolder) -> Bool {
		if lhs.id != nil || rhs.id != nil {
			return lhs.id == rhs.id
		}

		return lhs.title == rhs.title
	}


	static let icon = UIImage(systemName: "folder")!

	var id: Int?

	var title: String

	var parentFolder: Int?

	private var children: [NcFolder]?

	private var _bookmarks: [NcBookmark]?


	var folders: [NcFolder] {
		get {
			if children == nil {
				children = []
			}

			return children!
		}
		set {
			children = newValue
		}
	}

	var bookmarks: [NcBookmark] {
		get {
			if _bookmarks == nil {
				_bookmarks = []
			}

			return _bookmarks!
		}
		set {
			_bookmarks = newValue
		}
	}


	init(id: Int? = nil, title: String, parentFolder: Int? = nil, folders: [NcFolder] = [], bookmarks: [NcBookmark] = []) {
		self.id = id
		self.title = title
		self.parentFolder = parentFolder
		self.folders = folders
		self.bookmarks = bookmarks
	}


	// MARK: Public Methods

	/**
	 Upload to Nextcloud server, if configured.

	 Will take over any changes from Nextcloud.

	 - returns: true if anything changed.
	 */
	func upload() async throws -> Bool {
		if let update = try await NcServer.store(self) {
			self.update(with: update)

			return true
		}

		return false
	}


	// MARK: Private Methods

	func update(with remote: NcFolder) {
		id = remote.id
		title = remote.title
		parentFolder = remote.parentFolder

		for rsf in remote.folders {
			if let lsf = folders.first(where: { $0.id != nil && $0.id == rsf.id }) {
				lsf.update(with: rsf)
			}
			else if let lsf = folders.first(where: { $0.id == nil && $0.title == rsf.title }) {
				lsf.update(with: rsf)
			}
			else {
				folders.append(rsf)
			}
		}

		var toDelete = [NcFolder]()

		for lsf in folders {
			if !remote.folders.contains(where: { $0.id != nil ? $0.id == lsf.id : $0.title == lsf.title }) {
				toDelete.append(lsf)
			}
		}

		folders.removeAll { toDelete.contains($0) }
	}


	// MARK: CustomStringConvertible

	var description: String {
		"[\(String(describing: type(of: self))) id=\(id != nil ? "\(id!)" : "(nil)"), title=\(title), parentfolder=\(parentFolder != nil ? "\(parentFolder!)" : "(nil)"), children=\(folders), bookmarks=\(bookmarks)]"
	}
}
