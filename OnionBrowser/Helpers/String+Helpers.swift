//
//  String+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension String {

	var escapedForJavaScript: String? {
		// Wrap in an array.
		let array = [self];

		// Encode to JSON.
		if let json = try? JSONEncoder().encode(array),
			let s = String(data: json, encoding: .utf8) {

			// Then chop off the enclosing brackets and quotes. ["..."]
			return String(s.dropFirst(2).dropLast(2))
		}

		return nil
	}
}
