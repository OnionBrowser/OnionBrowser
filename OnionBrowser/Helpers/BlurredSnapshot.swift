//
//  BlurredSnapshot.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 12.03.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BlurredSnapshot: NSObject {

	private static var view: UIView?

	/**
	Blur current window content to increase privacy when in background.

	Call this from AppDelegate#applicationWillResignActive:
	*/
	@objc class func create() {
		// Blur current content to increase privacy when in background.
		if view == nil,
			let window = AppDelegate.shared?.window,
			let view = window.snapshotView(afterScreenUpdates: false) {

			self.view = view

			let vev = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
			vev.frame = view.bounds

			view.addSubview(vev)
			window.addSubview(view)
		}
	}

	/**
	Remove blurred snapshot again when coming back from background.

	Call this from AppDelegate#applicationDidBecomeActive:
	*/
	@objc class func remove() {
		view?.removeFromSuperview()
		view = nil
	}
}
