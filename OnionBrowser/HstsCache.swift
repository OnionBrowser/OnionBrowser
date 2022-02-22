//
//  HstsCache.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 21.02.22.
//  Copyright © 2022 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

@objc
class HstsCache: NSObject {

	@objc
	static let hstsHeader = "Strict-Transport-Security"

	@objc
	static let shared = HstsCache()


	private static let preloadedFile = Bundle.main.path(forResource: "hsts_preload", ofType: "plist")
	private static let cacheFile = FileManager.default.docsDir?.appendingPathComponent("hsts_cache.plist")


	private let preloaded: [String: Entry]
	private var cached: [String: Entry]


	private override init() {
		if let preloadedFile = Self.preloadedFile {
			preloaded = Self.load(from: URL(fileURLWithPath: preloadedFile))
		}
		else {
			preloaded = [:]
		}

		cached = Self.load(from: Self.cacheFile)

		print("[\(String(describing: type(of: self)))] Locked and loaded with \(preloaded.count) preloaded and \(cached.count) cached hosts.")

		super.init()
	}


	func persist() {
		guard let cacheFile = Self.cacheFile else {
			return
		}

		let encoder = PropertyListEncoder()
		encoder.outputFormat = .xml

		do {
			let data = try encoder.encode(cached)

			try data.write(to: cacheFile)

			print("[\(String(describing: type(of: self)))]#persisted successfully.")
		}
		catch {
			print("[\(String(describing: type(of: self)))]#persist error=\(error)")
		}
	}

	@objc(rewriteURL:)
	func rewrite(url: URL) -> URL {
		guard url.scheme == "http",
			  let host = url.host?.lowercased(),
			  !NSString(string: host).isValidIPAddress()
		else {
			return url
		}

		var matchHost = host

		var entry = entry(for: host)

		if entry == nil {
			// For a host of x.y.z.example.com, try y.z.example.com, z.example.com, example.com, etc.
			let hostp = host.components(separatedBy: ".")

			for i in 1 ..< hostp.count - 1 {
				let wc = hostp[i ..< hostp.count].joined(separator: ".")

				entry = self.entry(for: wc)

				if entry?.allowSubdomains ?? false {
					matchHost = wc
					break
				}
				else {
					entry = nil
				}
			}
		}

		guard let entry = entry else {
			return url
		}

		if entry.expiration < Date() {
			print("[\(String(describing: type(of: self)))] entry for \(matchHost) expired at \(entry.expiration)")

			remove(for: matchHost)

			return url
		}

		var urlc = URLComponents(url: url, resolvingAgainstBaseURL: false)
		urlc?.scheme = "https"

		// 8.3.5: nullify port unless it's a non-standard one.
		if urlc?.port == 80 {
			urlc?.port = nil
		}

		let newUrl = urlc?.url ?? url

		print("[\(String(describing: type(of: self)))] rewrote \(url) to \(newUrl)")

		return newUrl
	}

	@objc
	func parseHstsHeader(_ header: String, for host: String) {
		if NSString(string: host).isValidIPAddress() {
			return
		}

		let host = host.lowercased()

		print("[\(String(describing: type(of: self)))]#parseHstsHeader:for: [\(host)] \(header)")

		let kvs = header.components(separatedBy: ";")

		var age: Int64 = 0
		var allowSubdomains: Bool?

		for kv in kvs {
			let kvparts = kv.components(separatedBy: "=")

			let key = kvparts.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
			let value = kvparts.count < 2 ? nil : kvparts.last?.trimmingCharacters(in: .whitespacesAndNewlines) .replacingOccurrences(of: "\"", with: "")

			switch key {
			case "max-age":
				age = Int64(value ?? "0") ?? 0

			case "includesubdomains":
				allowSubdomains = true

			case "preload", "", nil:
				// Ignore.
				break

			default:
				print("[\(String(describing: type(of: self)))] [\(host)] unknown parameter \"\(key!)\"")
			}
		}

		if age <= 0 {
			print("[\(String(describing: type(of: self)))] [\(host)] got max-age=0, deleting")

			remove(for: host)

			return
		}

		cached[host] = Entry(expiration: Date().addingTimeInterval(Double(age)), allowSubdomains: allowSubdomains)
	}

	@objc
	func _testingOnlyEntry(_ host: String) -> [String: Any]? {
		guard let entry = entry(for: host) else {
			return nil
		}

		var result: [String: Any] = [
			"expiration": entry.expiration
		]

		if let allowSubdomains = entry.allowSubdomains {
			result["allowSubdomains"] = allowSubdomains
		}

		return result
	}


	// MARK: Private Methods

	private func entry(for host: String) -> Entry? {
		if let entry = cached[host] {
			return entry.ignore == true ? nil : entry
		}

		return preloaded[host]
	}

	private func remove(for host: String) {
		if preloaded[host] != nil {
			cached[host] = Entry(ignore: true)
			return
		}

		cached[host] = nil
	}

	private class func load(from url: URL?) -> [String: Entry] {
		if let url = url {
			do {
				return try PropertyListDecoder().decode([String: Entry].self, from: Data(contentsOf: url))
			}
			catch {
				print("[\(String(describing: type(of: self)))]#init error=\(error)")
			}
		}

		return [:]
	}
}

struct Entry: Codable {

	enum CodingKeys: String, CodingKey {
		case expiration
		case allowSubdomains
		case ignore
	}

	private var _expiration: Date?
	var expiration: Date {
		get {
			return _expiration ?? Date(timeIntervalSinceNow: 60 * 60 * 24 * 365)
		}
		set {
			_expiration = newValue
		}
	}

	var allowSubdomains: Bool?

	var ignore: Bool?

	init(expiration: Date? = nil, allowSubdomains: Bool? = nil, ignore: Bool? = nil) {
		_expiration = expiration
		self.allowSubdomains = allowSubdomains
		self.ignore = ignore
	}

	init(from decoder: Decoder) throws {
		let container = try? decoder.container(keyedBy: CodingKeys.self)

		_expiration = try? container?.decode(Date.self, forKey: .expiration)

		allowSubdomains = try? container?.decode(Bool.self, forKey: .allowSubdomains)

		ignore = try? container?.decode(Bool.self, forKey: .ignore)
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		if let _expiration = _expiration {
			try container.encode(_expiration, forKey: .expiration)
		}

		if let allowSubdomains = allowSubdomains {
			try container.encode(allowSubdomains, forKey: .allowSubdomains)
		}

		if let ignore = ignore {
			try container.encode(ignore, forKey: .ignore)
		}
	}
}
