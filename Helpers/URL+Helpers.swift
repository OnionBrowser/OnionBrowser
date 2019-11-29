//
//  URL+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 21.11.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension URL {

	static let blank = URL(string: "about:blank")!
	static let aboutOnionBrowser = URL(string: "about:onion-browser")!
	static let credits = Bundle.main.url(forResource: "credits", withExtension: "html")


	var withFixedScheme: URL? {
		switch scheme?.lowercased() {
		case "onionhttp":
			var urlc = URLComponents(url: self, resolvingAgainstBaseURL: true)
			urlc?.scheme = "http"

			return urlc?.url

		case "onionhttps":
			var urlc = URLComponents(url: self, resolvingAgainstBaseURL: true)
			urlc?.scheme = "https"

			return urlc?.url

		default:
			return self
		}
	}

	var real: URL? {
		switch self {
		case URL.aboutOnionBrowser:
			return URL.credits

		default:
			return self
		}
	}
}

@objc
extension NSURL {

	var withFixedScheme: NSURL? {
		return (self as URL).withFixedScheme as NSURL?
	}
}
