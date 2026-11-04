//
//  BrowsingViewController+Toolbar.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension BrowsingViewController: UIScrollViewDelegate, UIGestureRecognizerDelegate {

	// MARK: UIScrollViewDelegate

	func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		showToolbar()
	}

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y

		if velocity == 0 {
			return
		}

		showToolbar(velocity > 0)
	}


	// MARK: UIGestureRecognizerDelegate

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		// Stop the system gesture recognizer from triggering a short tap
		// on the back button, when our long tap gesture will soon trigger the
		// display of the HistoryViewController.
		return gestureRecognizer is UILongPressGestureRecognizer
	}


	// MARK: Actions

	@IBAction func showHistory(_ sender: UIGestureRecognizer) {
		sender.isEnabled = false

		if currentTab?.history.count ?? 0 > 1 {
			present(HistoryViewController.instantiate(currentTab!), backBt)
		}

		sender.isEnabled = true
	}


	// MARK: Public Methods

	/**
	Shows or hides the floating bottom bar by sliding it off the screen.
	The page keeps its size, it scrolls under the bar anyway.
	*/
	func showToolbar(_ show: Bool = true, _ animated: Bool = true) {
		guard let toolbar = toolbar else {
			return
		}

		// Don't hide the bar while an address is typed.
		if !show && (searchFl?.isFirstResponder ?? false) {
			return
		}

		let currentlyShown = toolbar.transform.isIdentity

		if show == currentlyShown {
			return
		}

		let distance = toolbar.bounds.height + 60

		let change = {
			toolbar.transform = show ? .identity : CGAffineTransform(translationX: 0, y: distance)
		}

		if animated {
			UIView.animate(withDuration: 0.25, animations: change)
		}
		else {
			change()
		}
	}
}
