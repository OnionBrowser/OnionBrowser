//
//  CALayer+Helpers.swift
//  OnionBrowser2
//
//  Created by alexey kosylo on 29/04/2022.
//  Copyright © 2022 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension CALayer {

	func makeSnapshot(scale: CGFloat = UIScreen.main.scale) -> UIImage? {
		UIGraphicsBeginImageContextWithOptions(frame.size, false, scale)

		defer {
			UIGraphicsEndImageContext()
		}

		guard let context = UIGraphicsGetCurrentContext() else {
			return nil
		}

		render(in: context)

		return UIGraphicsGetImageFromCurrentImageContext()
	}
}
