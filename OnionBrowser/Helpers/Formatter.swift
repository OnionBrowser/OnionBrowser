//
//  Formatter.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class Formatter: NSObject {

	class func localize(_ value: Int) -> String {
		return NumberFormatter.localizedString(from: NSNumber(value: value), number: .none)
	}
}
