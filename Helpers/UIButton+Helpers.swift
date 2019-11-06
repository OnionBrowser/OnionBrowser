//
//  UIButton+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import Foundation

extension UIButton {

	func setTitle(_ title: String?) {
		setTitle(title, for: .normal)
		setTitle(title, for: .highlighted)
		setTitle(title, for: .disabled)
		setTitle(title, for: .focused)
		setTitle(title, for: .selected)
	}
}
