//
//  BrowsingViewController+Tabs.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension BrowsingViewController {

	@objc func showAllTabs() {
		UIView.animate(withDuration: 0.75) {
//			for i in (0 ..< self.tabs.count).reversed() {
//				guard let webView = self.tabs[i].webView else {
//					continue
//				}
//
//				self.debug("i=\(i)")
//
//				let layer = webView.layer
//
//				webView.isHidden = false
//
//				layer.borderColor = UIColor.black.cgColor
//				layer.borderWidth = 1
//
//				var transform = CATransform3DIdentity
//				transform = CATransform3DTranslate(transform, 0, 0, CGFloat(10 * (i + 1)))
//				transform = CATransform3DRotate(transform, 0.5, 0.25, 0, 0)
//				transform.m34 = -1 / 500 // Add perspective.
////				layer.sublayerTransform = transform
//				layer.transform = transform
//
//				self.debug("transform=\(transform)")
//
//				layer.shadowColor = UIColor.black.cgColor
//				layer.shadowOpacity = 0.5
//				layer.shadowOffset = CGSize(width: -1, height: 1)
//				layer.shadowRadius = 16
//				layer.shadowPath = UIBezierPath(rect: webView.bounds).cgPath
//			}

			self.container.backgroundColor = .darkGray
		}

		showSearchBar(false)
		switchToolbar(main: false)
	}

	@objc func newTab() {
		hideTabs()

		addNewTab(for: nil, forRestoration: false, with: .default) { _ in
			self.searchFl.becomeFirstResponder()
		}
	}

	@objc func hideTabs() {
		UIView.animate(withDuration: 0.75) {
			self.currentTab?.webView.layer.transform = CATransform3DIdentity

			if #available(iOS 13.0, *) {
				self.container.backgroundColor = .systemBackground
			}
			else {
				self.container.backgroundColor = .white
			}
		}

		for tab in self.tabs {
			if tab != currentTab {
				UIView.transition(with: container, duration: 0.25,
								  options: .transitionCrossDissolve,
								  animations: { tab.webView.isHidden = true })
			}
		}

		showSearchBar()
		switchToolbar()
	}

    private func showSearchBar(_ show: Bool = true, _ animated: Bool = true) {
		if show != searchBar.isHidden {
			return
		}

        if show {
            searchBar.isHidden = false
			searchBarHeightConstraint.constant = searchBarHeight

			if animated {
				UIView.animate(withDuration: 0.25) {
					self.view.layoutIfNeeded()
				}
			}
        }
        else {
            searchBarHeightConstraint.constant = 0

			if animated {
				UIView.animate(withDuration: 0.25,
							   animations: { self.view.layoutIfNeeded() })
				{ _ in
					// Need to delay this a little, otherwise animation isn't seen,
					// because isHidden becomes in effect before the animation,
					// regardless, if we only do this in the completed callback.
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						self.searchBar.isHidden = true
					}
				}
			}
			else {
				searchBar.isHidden = true
			}
		}
    }

	private func switchToolbar(main: Bool = true) {
		mainTools.isHidden = !main
		tabsTools.isHidden = main

		if main {
			if #available(iOS 13.0, *) {
				toolbar.backgroundColor = .systemBackground
			}
			else {
				toolbar.backgroundColor = .white
			}
		}
		else {
			toolbar.backgroundColor = .darkGray
		}
	}
}
