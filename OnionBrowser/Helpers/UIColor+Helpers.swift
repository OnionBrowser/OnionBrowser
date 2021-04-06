//
//  UIColor+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

public extension UIColor {

    /**
     Background, dark purple, code #3F2B4F
     */
    @objc
    static var accent = UIColor(named: "Accent")

    /**
     Intro progress bar background, darker purple, code #352144
     */
    @objc
    static var accentDark = UIColor(named: "AccentDark")

    /**
     Background for connecting view, light Tor purple, code #A577BB
     */
    @objc
    static var accentLight = UIColor(named: "AccentLight")

    /**
     Background for security level shield, bronze, code #E37C00 and #A05E0C (dark mode)
     */
    @objc
    static var bronze = UIColor(named: "Bronze")

    /**
     Red error view background, code #FB5427
     */
    @objc
    static var error = UIColor(named: "Error")

    /**
     Background for security level shield, gold, code #FFD300 and #D5A900 (dark mode)
     */
    @objc
    static var gold = UIColor(named: "Gold")

    /**
     Green connected indicator line, code #7ED321
     */
    @objc
    static var ok = UIColor(named: "Ok")

    /**
     Background for security level shield, silver, code #CFCFCF and #6F6F6F (dark mode)
     */
    @objc
    static var silver = UIColor(named: "Silver")
}
