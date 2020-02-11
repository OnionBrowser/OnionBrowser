//
//  ProgressMessage.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.02.20.
//  Copyright © 2020 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

class ProgressMessage: NSObject, Message {

	static var supportsSecureCoding = true

	let progress: Float

	init(_ progress: Float) {
		self.progress = progress

		super.init()
	}

	required init?(coder: NSCoder) {
		progress = coder.decodeFloat(forKey: "progress")

		super.init()
	}

	func encode(with coder: NSCoder) {
		coder.encode(progress, forKey: "progress")
	}
}
