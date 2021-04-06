//
//  FixedFormViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 08.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class FixedFormViewController: FormViewController {

	override func keyboardWillShow(_ notification: Notification) {
		// When showing inside a popover on iPad, the popover gets resized on
		// keyboard display, so we shall not do this inside the view.
		if popoverPresentationController != nil && UIDevice.current.userInterfaceIdiom == .pad {
			return
		}

		super.keyboardWillShow(notification)
	}
}
