//
//  ClearHistoryIntent.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 22.10.25.
//  Copyright © 2025 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import AppIntents

@available(iOS 18.0, *)
@AppIntent(schema: .browser.clearHistory)
struct ClearHistoryIntent: AppIntent {

	static var openAppWhenRun = true


	@Parameter
	var timeFrame: ClearHistoryTimeFrame


	@MainActor
	func perform() async throws -> some IntentResult {
		for scene in UIApplication.shared.connectedScenes {
			// This will only work on an iPad. On an iPhone, this will trigger
			// "Invalid attempt to call -[UIApplication requestSceneSessionDestruction:] from an unsupported device."
			// In that case, we'll just remove all tabs from the scene ourselves.
			UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil) { _ in
				(scene.delegate as? SceneDelegate)?.browsingUi.removeAllTabs()
			}
		}

		WebsiteStorage.shared.cleanup()

		return .result()
	}
}

@available(iOS 18.0, *)
@AppEnum(schema: .browser.clearHistoryTimeFrame)
enum ClearHistoryTimeFrame: String, AppEnum {

	case allTime

	static var caseDisplayRepresentations: [ClearHistoryTimeFrame: DisplayRepresentation] = [
		.allTime: "Forever" ]
}
