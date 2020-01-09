//
//  UIColor+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
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
     Red error view background, code #FB5427
     */
    @objc
    static var error = UIColor.init(named: "Error")

    /**
     Green connected indicator line, code #7ED321
     */
    @objc
    static var ok = UIColor(named: "Ok")
}
