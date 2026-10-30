//
//  MozillaBookmarks.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 19.11.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import SwiftSoup

class MozillaBookmarks {

	class func export(_ folder: NcFolder) throws -> URL {
		var result = """
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<html>
	<head>
		<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
		<meta http-equiv="Content-Security-Policy" content="default-src 'self'; script-src 'none'; img-src data: *; object-src 'none'">
		<title>\(Bundle.main.displayName) \(NSLocalizedString("Bookmarks", comment: ""))</title>
	</head>
	<body>

"""

		result += render(folder, level: folder.id == -1 ? 1 : 2)

		result += """
	</body>
</html>

"""

//		print(result)

		let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).last!
			.appendingPathComponent("\(NSLocalizedString("Bookmarks", comment: "")).html")

		try result.write(to: url, atomically: true, encoding: .utf8)

		return url
	}

	class func `import`(_ content: String) async throws {
		let document = try SwiftSoup.parse(content)

		let dts = try document.select("body > dl > dt")

		try `import`(dts, into: NcBookmarks.root)

		NcBookmarks.store()

		try await NcServer.sync()
	}

	// MARK: Private Methods

	private class func `import`(_ dts: Elements, into folder: NcFolder) throws {
		for dt in dts {
			if let header = try dt.select("h1, h2, h3, h4, h5, h6").first() {
				let ncFolder = NcFolder(
					id: Int(try header.attr("id")),
					title: try header.text(),
					parentFolder: folder.id)

				folder.folders.append(ncFolder)

				try `import`(dt.select("dl > dt"), into: ncFolder)
			}
			else {
				for bookmark in try dt.select("a") {
					let ncBookmark = NcBookmark(
						id: Int(try bookmark.attr("id")),
						url: try bookmark.attr("href"),
						title: try bookmark.text(),
						added: Int(try bookmark.attr("add_date")) ?? Int(Date().timeIntervalSince1970),
						lastModified: Int(try bookmark.attr("last_modified")) ?? Int(Date().timeIntervalSince1970),
						folder: folder)

					let iconData = try bookmark.attr("icon")

					if iconData.starts(with: "data:image/png;base64,") {
						let iconData = String(iconData.dropFirst(22))

						if !iconData.isEmpty, let data = Data(base64Encoded: iconData) {
							ncBookmark.icon = UIImage(data: data)
						}
					}

					folder.bookmarks.append(ncBookmark)
				}
			}
		}
	}


	private class func render(_ folder: NcFolder, level: UInt8) -> String {
		var prefix = String(repeating: "\t", count: Int(level) + 1)

		var idAttr = ""

		if let id = folder.id {
			idAttr = " id=\"\(id)\""
		}

		var title = folder.title

		if title.isEmpty {
			title = NSLocalizedString("Bookmarks", comment: "")
		}

		var result = ""

		if level > 1 {
			result += "\(prefix)<dt>\n"

			prefix = String(repeating: "\t", count: Int(level) + 2)
		}

		result += "\(prefix)<h\(level)\(idAttr)>\(title)</h\(level)>\n"
		result += "\(prefix)<dl><p>\n"

		for folders in folder.folders {
			result += render(folders, level: level + 1)
		}

		if !folder.bookmarks.isEmpty {
			for bookmark in folder.bookmarks {
				result += render(bookmark, level: level + (level > 1 ? 1 : 0))
			}
		}

		result += "\(prefix)</p></dl>\n"

		if level > 1 {
			prefix = String(repeating: "\t", count: Int(level) + 1)
			result += "\(prefix)</dt>\n"
		}

		return result
	}

	private class func render(_ bookmark: NcBookmark, level: UInt8) -> String {
		let prefix = String(repeating: "\t", count: Int(level) + 2)

		var idAttr = ""

		if let id = bookmark.id {
			idAttr = " id=\"\(id)\""
		}

		var iconAttr = ""

		if let iconUrl = bookmark.iconUrl,
		   let data = try? Data(contentsOf: iconUrl)
		{
			iconAttr = " icon=\"data:image/png;base64,\(data.base64EncodedString())\""
		}

		var title = bookmark.title

		if title.isEmpty {
			title = URL(string: bookmark.url)?.host ?? ""
		}

		return "\(prefix)<dt><a\(idAttr) href=\"\(bookmark.url)\" add_date=\"\(bookmark.added)\" last_modified=\"\(bookmark.lastModified)\"\(iconAttr)>\(title)</a></dt>\n"
	}
}
