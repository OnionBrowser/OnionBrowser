//
//  UIImage+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 01.04.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension UIImage {

	/**
	Tint this image with the given color and return it as new image.

	- parameter color: The color to tint this image in.
	- returns: a new image of this image tinted in the given color or self, if there was a render error.
	*/
	func tinted(with color: UIColor?) -> UIImage {
		let imageView = UIImageView(image: self.withRenderingMode(.alwaysTemplate))
		imageView.tintColor = color

		defer {
			UIGraphicsEndImageContext()
		}

		UIGraphicsBeginImageContextWithOptions(size, false, 0)

		guard let context = UIGraphicsGetCurrentContext() else {
			return self
		}

		imageView.layer.render(in: context)

		return UIGraphicsGetImageFromCurrentImageContext() ?? self
	}
	
	func topCropped(newSize: CGSize) -> UIImage? {
		let drawRect: CGRect

		if newSize.width > newSize.height {
			let ratio = newSize.width / size.width
			let delta = (ratio * size.height) - newSize.height

			drawRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height + delta)
		}
		else {
			let ratio = newSize.height / size.height
			let delta = (ratio * size.width) - newSize.width

			drawRect = CGRect(x: 0, y: 0, width: newSize.width + delta, height: newSize.height)
		}

		defer {
			UIGraphicsEndImageContext()
		}

		UIGraphicsBeginImageContextWithOptions(newSize, true, 0.0)

		draw(in: drawRect)

		return UIGraphicsGetImageFromCurrentImageContext()
	}
}
