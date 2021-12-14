//
//  Settings.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI

@objcMembers
class SearchEngine: NSObject {

	let name: String

	let searchUrl: String?

	let homepageUrl: String?

	let autocompleteUrl: String?

	let postParams: [String: String]?

	init(_ name: String, _ data: [String: Any]) {
		self.name = name

		searchUrl = data["search_url"] as? String

		homepageUrl = data["homepage_url"] as? String

		autocompleteUrl = data["autocomplete_url"] as? String

		postParams = data["post_params"] as? [String: String]
	}
}

@objcMembers
class Settings: NSObject {

	enum TlsVersion: String, CustomStringConvertible {
		case tls10 = "tls_10"
		case tls12 = "tls_12"
		case tls13 = "tls_13"

		var description: String {
			switch self {
			case .tls10:
				return NSLocalizedString("TLS 1.3, 1.2, 1.1 or 1.0", comment: "Minimal TLS version")

			case .tls12:
				return NSLocalizedString("TLS 1.3 or 1.2", comment: "Minimal TLS version")

			default:
				return NSLocalizedString("TLS 1.3 Only", comment: "Minimal TLS version")
			}
		}

		var `protocol`: SSLProtocol {
			switch self {
			case .tls10:
				return .tlsProtocol1

			case .tls12:
				return .tlsProtocol12

			default:
				return .tlsProtocol13
			}
		}
	}

	private static let transportTranslationTable = [
		// Type .none is identical in IPtProxyUI and OnionBrowser.
		0: 0,

		// Type .obfs4 is identical in IPtProxyUI and OnionBrowser.
		1: 1,

		// Deprecated legacy type .meekamazon. Retaining this number for future use if meek-amazon comes back.
		2: 0,

		/**
		Deprecated legacy type .meekazure. Retaining this number for future use if meek-azure comes back.

		Microsoft announced to start blocking domain fronting:
		[Microsoft: Securing our approach to domain fronting within Azure](https://www.microsoft.com/security/blog/2021/03/26/securing-our-approach-to-domain-fronting-within-azure/)
		*/
		3: 0,

		// Type .snowflake is 4 in OnionBrowser and 2 in IPtProxyUI.
		4: 2,

		// Type .snowflakeAmp is 5 in OnionBrowser and 4 in IPtProxyUI.
		5: 4,

		// Type .custom is 99 in OnionBrowser and 3 in IPtProxyUI.
		99: 3]


	class var stateRestoreLock: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "state_restore_lock")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "state_restore_lock")
		}
	}

	class var didIntro: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "did_intro")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_intro")
		}
	}

	class var bookmarkFirstRunDone: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "did_first_run_bookmarks")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_first_run_bookmarks")
		}
	}

	class var bookmarksMigratedToOnionV3: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "bookmarks_migrated_to_onion_v3")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "bookmarks_migrated_to_onion_v3")
		}
	}

	class var transport: Transport {
		get {
			let obRaw = UserDefaults.standard.integer(forKey: "use_bridges")

			guard let iptRaw = transportTranslationTable[obRaw] else {
				return .none
			}

			return Transport(rawValue: iptRaw) ?? .none
		}
		set {
			let iptRaw = newValue.rawValue

			let obRaw = transportTranslationTable.first(where: { $0.value == iptRaw })?.key ?? 0

			UserDefaults.standard.set(obRaw, forKey: "use_bridges")
		}
	}

	class var customBridges: [String]? {
		get {
			return UserDefaults.standard.stringArray(forKey: "custom_bridges")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "custom_bridges")
		}
	}


	class var searchEngineName: String {
		get {
			return UserDefaults.standard.object(forKey: "search_engine") as? String
				?? allSearchEngineNames.first
				?? ""
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "search_engine")
		}
	}

	class var searchEngine: SearchEngine? {
		return allSearchEngines[searchEngineName]
	}

	class var allSearchEngineNames: [String] {
		return allSearchEngines.keys.sorted()
	}

	private static let allSearchEngines: [String: SearchEngine] = {
		if let path = Bundle.main.path(forResource: "SearchEngines", ofType: "plist"),
			let data = NSDictionary(contentsOfFile: path) as? [String: [String: Any]] {

			var searchEngines = [String: SearchEngine]()

			for engine in data {
				searchEngines[engine.key] = SearchEngine(engine.key, engine.value)
			}

			return searchEngines
		}

		return [:]
	}()

	class var searchLive: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "search_engine_live")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "search_engine_live")
		}
	}

	class var searchLiveStopDot: Bool {
		get {
			// Defaults to true!
			if UserDefaults.standard.object(forKey: "search_engine_stop_dot") == nil {
				return true
			}

			return UserDefaults.standard.bool(forKey: "search_engine_stop_dot")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "search_engine_stop_dot")
		}
	}

	class var sendDnt: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "send_dnt")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "send_dnt")
		}
	}

	class var tlsVersion: TlsVersion {
		get {
			if let value = UserDefaults.standard.object(forKey: "tls_version") as? String,
				let version = TlsVersion(rawValue: value) {

				return version
			}

			return .tls10
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: "tls_version")
		}
	}

	/**
	Proxy getter for Objective-C.
	*/
	class var minimumSupportedProtocol: SSLProtocol {
		return tlsVersion.protocol
	}

	class var tabSecurity: TabSecurity.Level {
		get {
			if let value = UserDefaults.standard.object(forKey: "tab_security") as? String,
				let level = TabSecurity.Level(rawValue: value) {

				return level
			}

			return .clearOnBackground
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: "tab_security")
		}
	}

	class var openTabs: [URL]? {
		get {
			if let data = UserDefaults.standard.object(forKey: "open_tabs") as? Data {
				return try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [URL]
			}

			return nil
		}
		set {
			if let newValue = newValue {
				let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
				UserDefaults.standard.set(data, forKey: "open_tabs")
			}
			else {
				UserDefaults.standard.removeObject(forKey: "open_tabs")
			}
		}
	}

	class var muteWithSwitch: Bool {
		get {
			// Defaults to true!
			if UserDefaults.standard.object(forKey: "mute_with_switch") == nil {
				return true
			}

			return UserDefaults.standard.bool(forKey: "mute_with_switch")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "mute_with_switch")

			AppDelegate.shared?.adjustMuteSwitchBehavior()
		}
	}

	class var disableBookmarksOnStartPage: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "disable_bookmarks_on_start_page")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "disable_bookmarks_on_start_page")
		}
	}

	class var thirdPartyKeyboards: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "third_party_keyboards")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "third_party_keyboards")
		}
	}

	class var cookieAutoSweepInterval: TimeInterval {
		get {
			// Defaults to 30 minutes.
			if UserDefaults.standard.object(forKey: "old_data_sweep_mins") == nil {
				return 30 * 60
			}

			return UserDefaults.standard.double(forKey: "old_data_sweep_mins") * 60
		}
		set {
			UserDefaults.standard.set(newValue / 60, forKey: "old_data_sweep_mins")
			
			AppDelegate.shared?.cookieJar.oldDataSweepTimeout = NSNumber(value: newValue / 60)
		}
	}

	class var advancedTorConf: [String]? {
		get {
			return UserDefaults.standard.stringArray(forKey: "advanced_tor_conf")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "advanced_tor_conf")
		}
	}

	class var openNewUrlOnStart: URL? {
		get {
			if let url = UserDefaults.standard.string(forKey: "open_new_url_on_start") {
				return URL(string: url)
			}

			return nil
		}
		set {
			UserDefaults.standard.set(newValue?.absoluteString, forKey: "open_new_url_on_start")
		}
	}

	class var nextcloudServer: String? {
		get {
			return UserDefaults.standard.string(forKey: "nextcloud_server")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_server")
		}
	}

	class var nextcloudUsername: String? {
		get {
			return UserDefaults.standard.string(forKey: "nextcloud_username")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_username")
		}
	}

	class var nextcloudPassword: String? {
		get {
			return UserDefaults.standard.string(forKey: "nextcloud_password")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_password")
		}
	}
}
