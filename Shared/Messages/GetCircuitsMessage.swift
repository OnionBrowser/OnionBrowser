//
//  GetCircuitsMessage.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 11.02.20.
//  Copyright © 2020 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

class GetCircuitsMessage: NSObject, Message {

	static var supportsSecureCoding = true

	override init() {
		super.init()
	}

	required init?(coder: NSCoder) {
		super.init()
	}

	func encode(with coder: NSCoder) {
	}
}
