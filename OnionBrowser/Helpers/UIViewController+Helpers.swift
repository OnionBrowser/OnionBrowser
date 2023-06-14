//
//  UIViewController+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.12.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension UIViewController {

	public var top: UIViewController {
		if let vc = subViewController {
			return vc.top
		}

		return self
	}

	public var subViewController: UIViewController? {
		if let vc = self as? UINavigationController {
			return vc.topViewController
		}

		if let vc = self as? UISplitViewController {
			return vc.viewControllers.last
		}

		if let vc = self as? UITabBarController {
			return vc.selectedViewController
		}

		if let vc = presentedViewController {
			return vc
		}

		return nil
	}

	/**
	Presents a view controller modally animated.

	Does it as a popover, when a `sender` object is provided.

	- parameter vc: The view controller to present.
	- parameter sender: The `UIView` with which the user triggered this operation.
	- returns: `true` if view controller could be presented, `false`, if there's already one presenting.
	*/
	@discardableResult
	func present(_ vc: UIViewController, _ sender: UIView? = nil) -> Bool {
		guard self.presentedViewController == nil else {
			return false
		}

		if let sender = sender {
			vc.modalPresentationStyle = .popover
			vc.popoverPresentationController?.sourceView = sender.superview
			vc.popoverPresentationController?.sourceRect = sender.frame

			if let delegate = vc as? UIPopoverPresentationControllerDelegate {
				vc.popoverPresentationController?.delegate = delegate
			}
		}

		present(vc, animated: true)

		return true
	}
}
