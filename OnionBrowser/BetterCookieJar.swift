//
//  BetterCookieJar.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 30.09.21.
//  Copyright © 2021 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BetterCookieJar: CookieJar {

	func clearAllNonWhitelistedData() {
		clearAllNonWhitelistedCookies(olderThan: 0)
		clearAllNonWhitelistedLocalStorage(olderThan: 0)
		clearAllNonWhitelistedAuthKeys(olderThan: 0)
	}

	func clearAllOldNonWhitelistedData() {
		let timeout = oldDataSweepTimeout.doubleValue * 60

		clearAllNonWhitelistedCookies(olderThan: timeout)
		clearAllNonWhitelistedLocalStorage(olderThan: timeout)
		clearAllNonWhitelistedAuthKeys(olderThan: timeout)
	}

	private func clearAllNonWhitelistedCookies(olderThan timeout: TimeInterval) {
		for cookie in self.cookieStorage.cookies ?? [] {
			guard !isHostWhitelisted(cookie.domain) else {
				continue
			}

			if !inUse(cookie.domain, timeout) {
				cookieStorage.deleteCookie(cookie)
			}
		}
	}

	private func clearAllNonWhitelistedLocalStorage(olderThan timeout: TimeInterval) {
		guard let allFiles = localStorageFiles() as? [String: String] else {
			return
		}

		// Sort filenames by length descending, so we're always deleting files in a dir before the dir itself.
		let files = allFiles.keys.sorted(by: { $0.count > $1.count })

		for file in files {
			guard let host = allFiles[file],
				  !isHostWhitelisted(host)
			else {
				continue
			}

			if !inUse(host, timeout) {
				try? FileManager.default.removeItem(atPath: file)
			}
		}
	}

	private func clearAllNonWhitelistedAuthKeys(olderThan timeout: TimeInterval) {
		guard let onionAuth = OnionManager.shared.onionAuth else {
			return
		}

		for key in onionAuth.keys {
			guard let host = key.onionAddress?.host,
				  !isHostWhitelisted(host)
			else {
				continue
			}

			if !inUse(host, timeout) {
				onionAuth.removeKey(at: onionAuth.keys.firstIndex(of: key)!)
			}
		}
	}

	private func inUse(_ host: String, _ timeout: TimeInterval) -> Bool {
		guard timeout > 0 else {
			return false
		}

		let now = Date()

		for tabHash in dataAccesses.allKeys {
			if let lastAccess = (dataAccesses[tabHash] as? NSMutableDictionary)?[host] as? NSNumber,
			   now.timeIntervalSince(Date(timeIntervalSince1970: lastAccess.doubleValue)) < timeout
			{
				return true
			}
		}

		return false
	}
}
