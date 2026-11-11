//
//  NcBookmark.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 23.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import FavIcon

/**
 https://nextcloud-bookmarks.readthedocs.io/en/latest/bookmark.html
 */
class NcBookmark: Codable, Equatable, CustomStringConvertible {

	enum CodingKeys: String, CodingKey {
		case id
		case url
		case title
		case desc = "description"
		case added
		case lastModified = "lastmodified"
		case folders

		// This is *not* part of Nextcloud bookmarks, but used internally.
		case iconName = "icon_name"
	}


	static let defaultIcon = UIImage(named: "default-icon")!


	static func == (lhs: NcBookmark, rhs: NcBookmark) -> Bool {
		if lhs.id != nil || rhs.id != nil {
			return lhs.id == rhs.id
		}

		return lhs.url == rhs.url
	}


	var id: Int?

	var url: String

	var title: String

	var desc: String

	var added: Int

	var lastModified: Int

	var folders: [Int]

	var iconName: String?


	private var _icon: UIImage?
	var icon: UIImage? {
		get {
			if _icon == nil,
			   let path = iconUrl?.path
			{
				_icon = UIImage(contentsOfFile: path)
			}

			return _icon
		}
		set {
			_icon = newValue

			// Remove old icon, if it gets deleted.
			if _icon == nil {
				if let url = iconUrl {
					do {
						try FileManager.default.removeItem(at: url)
					}
					catch {
						Log.error(for: Self.self, "\(error)")
					}
				}

				iconName = nil
				updateLastModified()
			}
			else {
				if iconName?.isEmpty ?? true {
					iconName = UUID().uuidString
				}

				if let url = iconUrl,
				   let data = _icon?.pngData()
				{
					do {
						try data.write(to: url)
						updateLastModified()
					}
					catch {
						Log.error(for: Self.self, "\(error)")
					}
				}
			}
		}
	}

	var iconUrl: URL? {
		guard let iconName, !iconName.isEmpty else {
			return nil
		}

		return NcBookmarks.rootDir?.appendingPathComponent(iconName)
	}


	init(
		id: Int? = nil,
		url: String,
		title: String,
		description: String = "",
		added: Int = Int(Date().timeIntervalSince1970),
		lastModified: Int = Int(Date().timeIntervalSince1970),
		folder: NcFolder = NcBookmarks.root,
		iconName: String? = nil,
	) {
		self.id = id
		self.url = url
		self.title = title
		self.desc = description
		self.added = added
		self.lastModified = lastModified
		self.folders = [folder.id ?? -1]
		self.iconName = iconName
	}


	// MARK: Public Methods

	/**
	 Upload to Nextcloud server, if configured.

	 Will take over any changes from Nextcloud.

	 - returns: true if anything changed.
	 */
	func upload() async throws -> Bool {
		if let update = try await NcServer.store(self) {
			id = update.id
			url = update.url
			title = update.title
			desc = update.desc
			added = update.added
			folders = update.folders

			if update.lastModified > lastModified {
				lastModified = update.lastModified
			}

			return true
		}

		return false
	}

	/**
	 Acquire an icon for the stored URL.

	 - returns: true if anything changed.
	 */
	func acquireIcon() async -> Bool {
		if let url = URL(string: url), icon == nil || Date(timeIntervalSince1970: TimeInterval(lastModified)) < Date() - 60 * 60 * 24 {
			let icon = await Self.icon(for: url)

			if self.icon != icon {
				self.icon = icon

				return true
			}
		}

		return false
	}

	func updateLastModified() {
		lastModified = Int(Date().timeIntervalSince1970)
	}

	class func icon(for url: URL) async -> UIImage? {
		FavIcon.downloadSession = TorManager.shared.session(timeout: 15)

		return await withCheckedContinuation { continuation in
			do {
				try FavIcon.downloadPreferred(url, width: 128, height: 128) { result in
					if case let .success(image) = result {
						continuation.resume(returning: image)
					}
					else {
						continuation.resume(returning: nil)
					}
				}
			}
			catch {
				Log.error(for: Self.self, "\(error)")

				continuation.resume(returning: nil)
			}
		}
	}


	// MARK: CustomStringConvertible

	var description: String {
		"[\(String(describing: type(of: self))) id=\(id != nil ? "\(id!)" : "(nil)"), url=\(url), title=\(title), desc=\(desc), added=\(added), lastModified=\(lastModified), folders=\(folders), iconName=\(iconName ?? "(nil)")]"
	}
}
