//
//  Tab+Gestures.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 27.11.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension Tab {

	func setupGestureRecognizers() {
		guard let webView = webView else {
			return
		}

		let isRtl = UIView.userInterfaceLayoutDirection(for: webView.semanticContentAttribute) == .rightToLeft

		// Swipe to go back one page.
		let swipeBack = UISwipeGestureRecognizer(target: self, action: #selector(goBack))
		swipeBack.direction = isRtl ? .left : .right
		webView.addGestureRecognizer(swipeBack)

		// Swipe to go forward one page.
		let swipeForward = UISwipeGestureRecognizer(target: self, action: #selector(goForward))
		swipeForward.direction = isRtl ? .right : .left
		webView.addGestureRecognizer(swipeForward)

		// Pull down to refresh.
		refresher.addTarget(self, action: #selector(refresherTriggered), for: .valueChanged)
		scrollView?.addSubview(refresher)
	}

	func removeGestureRecognizers() {
		for gr in webView?.gestureRecognizers ?? [] {
			webView?.removeGestureRecognizer(gr)
		}
	}


	// MARK: Private Methods

	@objc
	private func refresherTriggered() {
		refresh()

		// Delay just so it confirms to the user that something happened.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.refresher.endRefreshing()
		}
	}
}
