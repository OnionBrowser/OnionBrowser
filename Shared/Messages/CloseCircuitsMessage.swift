//
//  CloseCircuitsMessage.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 11.02.20.
//  Copyright © 2020 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

class CloseCircuitsMessage: NSObject, Message {

	static var supportsSecureCoding = true

	let circuits: [TorCircuit]

	init(_ circuits: [TorCircuit]) {
		self.circuits = circuits

		super.init()
	}

	required init?(coder: NSCoder) {
		circuits = coder.decodeObject(of: [NSArray.self, TorCircuit.self],
									  forKey: "circuits") as? [TorCircuit] ?? []

		super.init()
	}

	func encode(with coder: NSCoder) {
		coder.encode(circuits, forKey: "circuits")
	}
}
