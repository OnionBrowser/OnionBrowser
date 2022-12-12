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

struct SearchEngine: Equatable {

	enum EngineType: Int {
		case builtIn
		case custom
	}


	let name: String

	let type: EngineType

	var details: Details? {
		switch type {
		case .builtIn:
			return Settings.builtInSearchEngines[name]

		case .custom:
			return Settings.customSearchEngines[name]
		}
	}


	func set(details: Details?) {
		switch type {
		case .custom:
			Settings.customSearchEngines[name] = details

		default:
			// Default engines cannot be changed.
			break
		}
	}


	struct Details: Codable {

		enum CodingKeys: String, CodingKey {
			case searchUrl = "search_url"
			case homepageUrl = "homepage_url"
			case autocompleteUrl = "autocomplete_url"
			case postParams = "post_params"
		}


		let searchUrl: String?

		let homepageUrl: String?

		let autocompleteUrl: String?

		let postParams: [String: String]?


		init(searchUrl: String? = nil, homepageUrl: String? = nil, autocompleteUrl: String? = nil, postParams: [String : String]? = nil) {
			self.searchUrl = searchUrl
			self.homepageUrl = homepageUrl
			self.autocompleteUrl = autocompleteUrl
			self.postParams = postParams
		}

		init(from dict: [String: Any]) {
			searchUrl = dict[CodingKeys.searchUrl.rawValue] as? String
			homepageUrl = dict[CodingKeys.homepageUrl.rawValue] as? String
			autocompleteUrl = dict[CodingKeys.autocompleteUrl.rawValue] as? String
			postParams = dict[CodingKeys.postParams.rawValue] as? [String: String]
		}


		func toDict() -> [String: Any] {
			var dict = [String: Any]()

			if let searchUrl = searchUrl {
				dict[CodingKeys.searchUrl.rawValue] = searchUrl
			}

			if let homepageUrl = homepageUrl {
				dict[CodingKeys.homepageUrl.rawValue] = homepageUrl
			}

			if let autocompleteUrl = autocompleteUrl {
				dict[CodingKeys.autocompleteUrl.rawValue] = autocompleteUrl
			}

			if let postParams = postParams {
				dict[CodingKeys.postParams.rawValue] = postParams
			}

			return dict
		}
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
			UserDefaults.standard.bool(forKey: "state_restore_lock")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "state_restore_lock")
		}
	}

	class var didIntro: Bool {
		get {
			UserDefaults.standard.bool(forKey: "did_intro")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_intro")
		}
	}

	class var bookmarkFirstRunDone: Bool {
		get {
			UserDefaults.standard.bool(forKey: "did_first_run_bookmarks")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_first_run_bookmarks")
		}
	}

	class var bookmarksMigratedToOnionV3: Bool {
		get {
			UserDefaults.standard.bool(forKey: "bookmarks_migrated_to_onion_v3")
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
			UserDefaults.standard.stringArray(forKey: "custom_bridges")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "custom_bridges")
		}
	}


	class var searchEngine: SearchEngine {
		get {
			let type = SearchEngine.EngineType(rawValue: UserDefaults.standard.integer(forKey: "search_engine_type")) ?? .builtIn

			let name = UserDefaults.standard.object(forKey: "search_engine") as? String

			if name == nil, let defaultEngine = searchEngines.first {
				return defaultEngine
			}

			return SearchEngine(name: name ?? "", type: type)
		}
		set {
			UserDefaults.standard.set(newValue.name, forKey: "search_engine")
			UserDefaults.standard.set(newValue.type.rawValue, forKey: "search_engine_type")
		}
	}

	class var searchEngines: [SearchEngine] {
		return builtInSearchEngines.keys.sorted().map { SearchEngine(name: $0, type: .builtIn) }
			+ customSearchEngines.keys.sorted().map({ SearchEngine(name: $0, type: .custom) })
	}

	fileprivate static let builtInSearchEngines: [String: SearchEngine.Details] = {
		if let url = Bundle.main.url(forResource: "SearchEngines.plist", withExtension: nil),
		   let data = try? Data(contentsOf: url),
		   let searchEngines = try? PropertyListDecoder().decode([String: SearchEngine.Details].self, from: data)
		{
			return searchEngines
		}

		return [:]
	}()

	fileprivate class var customSearchEngines: [String: SearchEngine.Details] {
		get {
			(UserDefaults.standard.object(forKey: "custom_search_engines") as? [String: [String: Any]])?.mapValues({
				SearchEngine.Details(from: $0)
			}) ?? [:]
		}
		set {
			UserDefaults.standard.set(newValue.mapValues({ $0.toDict() }), forKey: "custom_search_engines")
		}
	}

	class var searchLive: Bool {
		get {
			UserDefaults.standard.bool(forKey: "search_engine_live")
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
			UserDefaults.standard.bool(forKey: "send_dnt")
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

	class var hideContent: Bool {
	 get {
		 UserDefaults.standard.object(forKey: "hide_content") == nil
			 ? true
			 : UserDefaults.standard.bool(forKey: "hide_content")
	 }
	 set {
		 UserDefaults.standard.set(newValue, forKey: "hide_content")
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
			UserDefaults.standard.bool(forKey: "disable_bookmarks_on_start_page")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "disable_bookmarks_on_start_page")
		}
	}

	class var thirdPartyKeyboards: Bool {
		get {
			UserDefaults.standard.bool(forKey: "third_party_keyboards")
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
			UserDefaults.standard.stringArray(forKey: "advanced_tor_conf")
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
			UserDefaults.standard.string(forKey: "nextcloud_server")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_server")
		}
	}

	class var nextcloudUsername: String? {
		get {
			UserDefaults.standard.string(forKey: "nextcloud_username")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_username")
		}
	}

	class var nextcloudPassword: String? {
		get {
			UserDefaults.standard.string(forKey: "nextcloud_password")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_password")
		}
	}
}
