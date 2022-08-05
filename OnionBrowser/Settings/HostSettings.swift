//
//  HostSettings.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.12.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension NSNotification.Name {
	static let hostSettingsChanged = NSNotification.Name(rawValue: HostSettings.hostSettingsChanged)
}

class HostSettings: NSObject {

	static let hostSettingsChanged = "host_settings_changed"

	private static let fileUrl: URL? = {
		return FileManager.default.docsDir?.appendingPathComponent("host_settings.plist")
	}()

	// Keys are left as-is to maintain backwards compatibility.

	private static let defaultHost = "__default"
	private static let `true` = "1"
	private static let `false` = "0"
	private static let ignoreTlsErrorsKey = "ignore_tls_errors"
	private static let whitelistCookiesKey = "whitelist_cookies"
	private static let universalLinkProtectionKey = "universal_link_protection"
	private static let followOnionLocationHeaderKey = "follow_onion_location_header"
	private static let userAgentKey = "user_agent"
	private static let javaScriptKey = "javascript"
	private static let orientationAndMotionKey = "orientation_and_motion"
	private static let mediaCaptureKey = "media_capture"

	private static var _raw: [String: [String: String]]?
	private static var raw: [String: [String: String]] {
		get {
			if _raw == nil, let url = fileUrl {
				_raw = NSDictionary(contentsOf: url) as? [String: [String: String]]

				// Fix later introduced setting, which defaults to true.
				if _raw?[HostSettings.defaultHost]?[followOnionLocationHeaderKey] == nil {
					_raw?[HostSettings.defaultHost]?[followOnionLocationHeaderKey] = HostSettings.true
				}
			}

			return _raw ?? [:]
		}
		set {
			_raw = newValue
		}
	}

	static var hosts: [String] {
		return raw.keys.filter({ $0 != HostSettings.defaultHost }).sorted()
	}

	/**
	- returns: The default settings. If nothing stored, yet, will return a full set of (unpersisted) defaults.
	*/
	class func forDefault() -> HostSettings {
		return `for`(nil)
	}

	/**
	- If the host is nil or empty, will return default settings.
	- If there are stored settings for the host, will return these.
	- If there are no settings stored for the host, will return a new (unpersisted) object with empty settings,
		which will automatically walk up the domain levels in search of a setting and finally end at the default
		settings.

	- parameter host: The host name. Can be `nil` which will return the default settings.
	- returns: Settings for the given host.
	*/
	class func `for`(_ host: String?) -> HostSettings {
		// If no host given, return default host settings.
		guard let host = host, !host.isEmpty else {
			// If user-customized default host settings available, return these.
			if has(defaultHost) {
				return HostSettings(for: defaultHost, raw: raw[defaultHost]!)
			}

			// ...else return hardcoded defaults.
			return HostSettings(for: defaultHost, withDefaults: true)
		}

		// If user-customized settings for this host available, return these.
		if has(host) {
			return HostSettings(for: host, raw: raw[host]!)
		}

		// ...else return new empty settings for this host which will trigger
		// fall through logic to higher domain levels or default host settings.
		return HostSettings(for: host, withDefaults: false)
	}

	/**
	Check, if we have explicit settings for a given host.

	This will *not* check the domain level hirarchy!

	- parameter host: The host name.
	- returns: true, if we have explicit settings for that host, false, if not.
	*/
	class func has(_ host: String?) -> Bool {
		return !(host?.isEmpty ?? true) && raw.keys.contains(host!)
	}

	/**
	Remove settings for a specific host.

	You are not allowed to remove the default host settings!

	- parameter host: The host name.
	- returns: Class for fluency.
	*/
	@discardableResult
	class func remove(_ host: String) -> HostSettings.Type {
		if host != defaultHost && has(host) {
			raw.removeValue(forKey: host)

			DispatchQueue.main.async {
				NotificationCenter.default.post(name: .hostSettingsChanged, object: host)
			}
		}

		return self
	}

	/**
	Persists all settings to disk.
	*/
	class func store() {
		if let url = fileUrl {
			(raw as NSDictionary).write(to: url, atomically: true)
		}
	}

	private var raw: [String: String]

	/**
	The host name these settings apply to.
	*/
	let host: String

	/**
	True, if TLS errors should be ignored. Will walk up the domain levels ending at the default settings,
	if not explicitly set for this host.

	Setting this will always set the value explicitly for this host.
	*/
	var ignoreTlsErrors: Bool {
		get {
			return get(HostSettings.ignoreTlsErrorsKey) == HostSettings.true
		}
		set {
			raw[HostSettings.ignoreTlsErrorsKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	/**
	True, if cookies for this host should be whitelisted. Will walk up the domain levels ending at the default settings,
	if not explicitly set for this host.

	Setting this will always set the value explicitly for this host.
	*/
	var whitelistCookies: Bool {
		get {
			return get(HostSettings.whitelistCookiesKey) == HostSettings.true
		}
		set {
			raw[HostSettings.whitelistCookiesKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	/**
	True, if universal link protection should be applied. Will walk up the domain levels ending at the default settings,
	if not explicitly set for this host.

	Setting this will always set the value explicitly for this host.
	*/
	var universalLinkProtection: Bool {
		get {
			return get(HostSettings.universalLinkProtectionKey) == HostSettings.true
		}
		set {
			raw[HostSettings.universalLinkProtectionKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	var followOnionLocationHeader: Bool {
		get {
			get(HostSettings.followOnionLocationHeaderKey) == HostSettings.true
		}
		set {
			raw[HostSettings.followOnionLocationHeaderKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	/**
	User Agent string to use. Will walk up the domain levels ending at the default settings,
	if not explicitly set for this host.

	Setting this will always set the value explicitly for this host.
	*/
	var userAgent: String {
		get {
			return get(HostSettings.userAgentKey)
		}
		set {
			raw[HostSettings.userAgentKey] = newValue
		}
	}

	/**
	 True, if JavaScript should be allowed.

	Setting this will always set the value explicitly for this host.
	*/
	var javaScript: Bool {
		get {
			return get(HostSettings.javaScriptKey) == HostSettings.true
		}
		set {
			raw[HostSettings.javaScriptKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	var orientationAndMotion: Bool {
		get {
			return get(HostSettings.orientationAndMotionKey) == HostSettings.true
		}
		set {
			raw[HostSettings.orientationAndMotionKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	var mediaCapture: Bool {
		get {
			return get(HostSettings.mediaCaptureKey) == HostSettings.true
		}
		set {
			raw[HostSettings.mediaCaptureKey] = newValue
				? HostSettings.true
				: HostSettings.false
		}
	}

	/**
	Will be used by `HostSettings.for()`.

	- parameter host: The host name.
	- parameter raw: The raw stored data as a dictionary.
	*/
	private init(for host: String, raw: [String: String]) {
		self.host = host
		self.raw = raw
	}

	/**
	Create a new HostSettings. It is not added to the persistent configuration until you call #save!

	If you create default host settings, all settings will always be created hard, regardless of the `withDefaults`
	flag.

	- parameter host: The host name.
	- parameter withDefaults: When true, all settings from the default host will be copied, when false,
		settings will not be set at all and you will be able to override specific things while the (ever changing)
		default host settings will still apply for the rest.
	*/
	@objc
	init(for host: String, withDefaults: Bool) {
		self.host = host

		if host == HostSettings.defaultHost {
			raw = [
				Self.ignoreTlsErrorsKey: Self.false,
				Self.whitelistCookiesKey: Self.false,
				Self.universalLinkProtectionKey: Self.true,
				Self.followOnionLocationHeaderKey: Self.true,
				Self.userAgentKey: "",
				Self.javaScriptKey: Self.true,
				Self.orientationAndMotionKey: Self.true,
				Self.mediaCaptureKey: Self.true,
			]
		}
		else {
			if withDefaults {
				raw = HostSettings.forDefault().raw
			}
			else {
				raw = [:]
			}
		}
	}

	/**
	Add this host's settings to the persistent data store and post  the
	`NSNotification.Name.hostSettingsChanged`.

	Call #store afterwards to persist all settings to disk!

	- returns: The object's type so you can chain #store to it, if you want.
	*/
	@discardableResult
	@objc
	func save() -> HostSettings.Type {
		HostSettings.raw[host] = raw

		let host = self.host == HostSettings.defaultHost ? nil : self.host

		DispatchQueue.main.async {
			NotificationCenter.default.post(name: .hostSettingsChanged, object: host)
		}

		return type(of: self)
	}

	/**
	Walk up the chain of hosts from `z.y.x.example.com` up to `example.com` to find a dedicated setting.
	If none found, return the setting of the default host.

	- parameter key: The setting's key.
	- returns: A string containing the searched setting.
	*/
	private func get(_ key: String) -> String {
		if let value = raw[key] {
			return value
		}

		// Stop endless recursion. This might happen if you search for
		// a setting which is not defined.
		if host == HostSettings.defaultHost {
			return ""
		}

		// Don't ommit empty subsequences to cater to hosts which containing
		// a leading period, like ".example.com". This mostly happens with cookie handling.
		var parts = host.split(separator: ".", omittingEmptySubsequences: false)

		while parts.count > 1 {
			parts.removeFirst()

			let superhost = parts.joined(separator: ".")

			if HostSettings.has(superhost) {
				return HostSettings.for(superhost).get(key)
			}
		}

		return HostSettings.forDefault().get(key)
	}
}
