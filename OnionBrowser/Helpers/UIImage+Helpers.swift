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

		UIGraphicsBeginImageContextWithOptions(size, false, 0)

		var tintedImage: UIImage? = nil

		if let context = UIGraphicsGetCurrentContext() {
			imageView.layer.render(in: context)

			tintedImage = UIGraphicsGetImageFromCurrentImageContext()

			UIGraphicsEndImageContext()
		}

		return tintedImage ?? self
	}
	
	func topCropped(newSize:CGSize) -> UIImage? {
		var ratio: CGFloat = 0
		var delta: CGFloat = 0
		var drawRect = CGRect()

		if newSize.width > newSize.height {
			ratio = newSize.width / size.width
			delta = (ratio * size.height) - newSize.height
			drawRect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height + delta)
		} else {
			ratio = newSize.height / size.height
			delta = (ratio * size.width) - newSize.width
			drawRect = CGRect(x: 0, y: 0, width: newSize.width + delta, height: newSize.height)
		}
		defer {
			UIGraphicsEndImageContext()
		}
		
		UIGraphicsBeginImageContextWithOptions(newSize, true, 0.0)
		draw(in: drawRect)
		let newImage = UIGraphicsGetImageFromCurrentImageContext()
		
		return newImage
	}
}
