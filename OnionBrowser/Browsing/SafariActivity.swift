//
//  SafariActivity.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 30.10.26.
//  Copyright © 2026 Tigas Ventures, LLC (Mike Tigas).
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//


import UIKit

class SafariActivity: UIActivity {

	private var url: URL?

	override var activityType: UIActivity.ActivityType? {
		ActivityType(String(describing: type(of: self)))
	}

	override var activityTitle: String? {
		NSLocalizedString("Open in Safari", comment: "")
	}

	override var activityImage: UIImage? {
		UIImage(systemName: "safari")
	}

	override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
		activityItems.compactMap { $0 as? URL }.contains { url in
			UIApplication.shared.canOpenURL(url)
		}
	}

	override func prepare(withActivityItems activityItems: [Any]) {
		url = activityItems.first(where: { $0 is URL }) as? URL
	}

	override func perform() {
		guard let url else {
			return activityDidFinish(false)
		}

		UIApplication.shared.open(url) { [weak self] completed in
			self?.activityDidFinish(completed)
		}
	}
}
