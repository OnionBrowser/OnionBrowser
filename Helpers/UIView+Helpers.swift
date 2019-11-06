//
//  UIView+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import Foundation

extension UIView {

	func add(to superview: UIView?) {
		if let superview = superview {
			translatesAutoresizingMaskIntoConstraints = false

			superview.addSubview(self)

			self.leadingAnchor.constraint(equalTo: superview.leadingAnchor).isActive = true
			self.trailingAnchor.constraint(equalTo: superview.trailingAnchor).isActive = true
			self.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
			self.bottomAnchor.constraint(equalTo: superview.bottomAnchor).isActive = true
		}
	}
}
