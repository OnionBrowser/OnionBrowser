//
//  UIButton+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension UIButton {

	func setTitle(_ title: String?) {
		setTitle(title, for: .normal)
		setTitle(title, for: .highlighted)
		setTitle(title, for: .disabled)
		setTitle(title, for: .focused)
		setTitle(title, for: .selected)
	}
}
