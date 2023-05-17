//
//  SceneDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit


class SceneDelegate: UIResponder, UIWindowSceneDelegate {

	// MARK: UIWindowSceneDelegate

	var window: UIWindow?

	@objc
	private(set) lazy var browsingUi: BrowsingViewController = {
		BrowsingViewController()
	}()


	/**
	 Flag, if biometric/password authentication after activation was successful.

	 Return to false immediately after positive check, otherwise, security issues will arise!
	 */
	private var verified = false


	func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
			   options connectionOptions: UIScene.ConnectionOptions)
	{
		guard let scene = scene as? UIWindowScene else {
			return
		}

		window = UIWindow(frame: scene.coordinateSpace.bounds)
		window?.windowScene = scene

		if Settings.tabSecurity == .alwaysRemember
			|| (
				Settings.tabSecurity == .forgetOnShutdown
				&& !(AppDelegate.shared?.firstScene ?? false)
			),
		   let activity = session.stateRestorationActivity,
		   activity.activityType == Bundle.main.activityType
		{
			browsingUi.decodeRestorableState(with: activity)
		}
		// Migrate from version 2.
		else if AppDelegate.shared?.firstScene ?? false
					&& !(Settings.openTabs?.isEmpty ?? true)
		{
			if Settings.tabSecurity == .alwaysRemember {
				browsingUi.decodeRestorableState(Settings.openTabs, nil)
			}

			// Never to be used again.
			Settings.openTabs = nil
		}

		AppDelegate.shared?.firstScene = false


		if let shortcut = connectionOptions.shortcutItem {
			handle(shortcut, starting: true)
		}
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		if !verified, let privateKey = SecureEnclave.loadKey() {
			var counter = 0

			repeat {
				let nonce = SecureEnclave.getNonce()

				verified = SecureEnclave.verify(
					nonce, signature: SecureEnclave.sign(nonce, with: privateKey),
					with: SecureEnclave.getPublicKey(privateKey))

				counter += 1
			} while !verified && counter < 3

			if !verified {
				sceneWillResignActive(scene)

				UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
			}

			// Always return here, as the SecureEnclave operations will always
			// trigger a user identification and therefore the app becomes inactive
			// and then active again. So #sceneDidBecomeActive will be
			// called again. Therefore, we store the result of the verification
			// in an object property and check that on re-entry.
			return
		}

		verified = false

		BlurredSnapshot.remove()

		let vc = OrbotManager.shared.checkStatus()

		show(vc)

		// Seems, we're running via Tor. Set up bookmarks, if not done, yet.
		if vc == nil {
			Bookmark.firstRunSetup()
			Bookmark.migrateToV3()
		}
	}

	func windowScene(_ windowScene: UIWindowScene,
					 performActionFor shortcutItem: UIApplicationShortcutItem,
					 completionHandler: @escaping (Bool) -> Void)
	{
		handle(shortcutItem, starting: false, completionHandler)
	}

	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		for context in URLContexts {
			if let urlc = URLComponents(url: context.url, resolvingAgainstBaseURL: true),
			   urlc.scheme == "onionbrowser"
			{
				if urlc.path == "token-callback" {
					let token = urlc.queryItems?.first(where: { $0.name == "token" })?.value

					Settings.orbotApiToken = token?.isEmpty ?? true ? Settings.orbotAccessDenied : token
				}
				else if urlc.path == "main" {
					// Ignore. We just returned from Orbot.
					// Do nothing more than already done: show the app.
				}
			}
			else {
				browsingUi.addNewTab(context.url.withFixedScheme)
			}
		}
	}

	func sceneWillResignActive(_ scene: UIScene) {
		browsingUi.unfocusSearchField()

		if Settings.hideContent {
			BlurredSnapshot.create(window)
		}
	}

	func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
		guard Settings.tabSecurity != .clearOnBackground,
			  !browsingUi.tabs.isEmpty,
			  let type = Bundle.main.activityType
		else {
			return nil
		}

		let activity = NSUserActivity(activityType: type)

		browsingUi.encodeRestorableState(with: activity)

		return activity
	}


	// MARK: Public Methods

	func show(_ viewController: UIViewController? = nil, _ completion: ((Bool) -> Void)? = nil) {
		if window == nil {
			window = UIWindow(frame: UIScreen.main.bounds)
			window?.backgroundColor = .accent
		}

		var viewController = viewController
		var completion = completion

		if viewController == nil || viewController is BrowsingViewController {
			viewController = browsingUi

			let outerCompletion = completion

			completion = { [weak self] finished in
				self?.browsingUi.becomesVisible()

				outerCompletion?(finished)
			}
		}

		if viewController?.restorationIdentifier == nil {
			viewController?.restorationIdentifier = String(describing: type(of: viewController))
		}

		window?.rootViewController = viewController
		window?.makeKeyAndVisible()

		UIView.transition(with: window!, duration: 0.3, options: .transitionCrossDissolve,
						  animations: {}, completion: completion)
	}


	// MARK: Private Methods

	private func handle(_ shortcut: UIApplicationShortcutItem, starting: Bool, _ completion: ((_ succeeded: Bool) -> Void)? = nil) {
		if shortcut.type.contains("OpenNewTab")
		{
			// Ignore, if we're currently starting, otherwise we'll crash for
			// an undebuggable reason. (Debugger cannot connect before crash.)
			// Since when starting with a shortcut, there seems to be no NSUserAction,
			// it's essentially a new tab, anyway.
			// The user loses their old tabs, though. Uuups.
			if !starting {
				browsingUi.addEmptyTabAndFocus()
			}

			completion?(true)
		}
		else if shortcut.type.contains("ClearData")
		{
			for scene in UIApplication.shared.connectedScenes {
				UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil)
			}

			WebsiteStorage.shared.cleanup()


			completion?(true)
		}
		else {
			print("[\(String(describing: type(of: self)))] Unable to handle shortcut type '\(shortcut.type)'!")
			completion?(false)
		}
	}
}
