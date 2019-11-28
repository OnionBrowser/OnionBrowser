//
//  BrowsingViewController+Toolbar.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension BrowsingViewController: UIScrollViewDelegate {

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


	// MARK: Actions

	@IBAction func showHistory(_ sender: UIGestureRecognizer) {
		sender.isEnabled = false

		if currentTab?.history.count ?? 0 > 1 {
			present(HistoryViewController.instantiate(currentTab!), backBt)
		}

		sender.isEnabled = true
	}


	// MARK: Public Methods

    func showToolbar(_ show: Bool = true, _ animated: Bool = true) {
		if show != toolbar.isHidden {
			return
		}

        if show {
            toolbar.isHidden = false
			toolbarHeightConstraint.constant = toolbarHeight
			containerBottomConstraint2Superview.isActive = false

			// This goes away when deactivated for an unkown reason.
			if containerBottomConstraint2Toolbar == nil {
				containerBottomConstraint2Toolbar = container.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
			}

			containerBottomConstraint2Toolbar?.isActive = true

			if animated {
				UIView.animate(withDuration: 0.25) {
					self.view.layoutIfNeeded()
				}
			}
        }
        else {
            toolbarHeightConstraint.constant = 0

			 // This goes away when deactivated for an unkown reason.
            containerBottomConstraint2Toolbar?.isActive = false

			containerBottomConstraint2Superview.isActive = true

			if animated {
				UIView.animate(withDuration: 0.25,
							   animations: { self.view.layoutIfNeeded() })
				{ _ in
					// Need to delay this a little, otherwise animation isn't seen,
					// because isHidden becomes in effect before the animation,
					// regardless, if we only do this in the completed callback.
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						self.toolbar.isHidden = true
					}
				}
			}
			else {
				toolbar.isHidden = true
			}
		}
    }
}
