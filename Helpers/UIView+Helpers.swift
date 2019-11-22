//
//  UIView+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
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

	/**
	Creates a transition animation of type `transitionCrossDissolve` with length 0.5 seconds for this
	view as the container.

	If this view is currently hidden, calls the callbacks directly without any animation.

	- parameter animations: A block object that contains the changes you want to make to the specified view.
		This block takes no parameters and has no return value.
	- parameter completion: A block object to be executed when the animation sequence ends.
		This block has no return value and takes a single Boolean argument that indicates whether or not the
		animations actually finished before the completion handler was called.
	*/
	func transition(_ animations: @escaping (() -> Void), _ completion: ((Bool) -> Void)? = nil) {
		if isHidden {
			animations()
			completion?(true)
		}
		else {
			UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve,
							  animations: animations, completion: completion)
		}
	}
}
