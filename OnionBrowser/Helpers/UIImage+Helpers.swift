//
//  UIImage+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 01.04.20.
//  Copyright © 2020 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
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
}
