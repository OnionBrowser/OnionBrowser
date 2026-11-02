//
//  SceneDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
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

	private var firstRun = true

	private var launchUrls: Set<UIOpenURLContext>?


	func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
			   options connectionOptions: UIScene.ConnectionOptions)
	{
		guard let scene = scene as? UIWindowScene else {
			return
		}

		window = UIWindow(frame: scene.coordinateSpace.bounds)
		window?.windowScene = scene

		if !connectionOptions.urlContexts.isEmpty {
			launchUrls = connectionOptions.urlContexts
		}

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
		else if Settings.tabSecurity == .forgetOnShutdown {
			// We still need to clean up website storage.
			// There was no trigger if the app was just sent into the background and forgotten.
			// AppDelegate.applicationWillTerminate() mostly won't be called.
			WebsiteStorage.shared.cleanup()
		}

		AppDelegate.shared?.firstScene = false


		if let shortcut = connectionOptions.shortcutItem {
			handle(shortcut, starting: true)
		}
	}

	func sceneDidBecomeActive(_ scene: UIScene) {
		AppDelegate.shared?.dontStopApp()

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

		Task {
			let vc = await OrbotManager.shared.checkStatus()

			show(vc)
		}
	}

	func windowScene(_ windowScene: UIWindowScene,
					 performActionFor shortcutItem: UIApplicationShortcutItem,
					 completionHandler: @escaping (Bool) -> Void)
	{
		handle(shortcutItem, starting: false, completionHandler)
	}

	func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
		handle(urlContexts: URLContexts)
	}

	func sceneWillResignActive(_ scene: UIScene) {
		browsingUi.unfocusSearchField()

		// A scene doesn't always need to be restored. It can still be in RAM,
		// when the user comes back.
		// In that case, we need to make sure, the tabs are gone when
		// the scene is becoming active again.
		if Settings.tabSecurity == .clearOnBackground {
			browsingUi.removeAllTabs()
		}

		if Settings.hideContent {
			BlurredSnapshot.create(window)
		}

		// Prepare to stop Tor properly, in case we get shut down.
		AppDelegate.shared?.maybeStopApp()
	}

	func sceneDidDisconnect(_ scene: UIScene) {
		// Stop app, if no other scenes around anymore.
		AppDelegate.shared?.maybeStopApp()
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

	@MainActor
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
				if let launchUrls = self?.launchUrls {
					self?.handle(urlContexts: launchUrls)
					self?.launchUrls = nil
				}

				self?.browsingUi.becomesVisible()

				// Seems, we're running via Tor. Set up bookmarks, if not done, yet.
				if self?.firstRun ?? false {
					self?.firstRun = false

					NcBookmarks.firstRunSetup()
					NcBookmarks.migrateToV3()

					if let vc = self?.browsingUi {
						UpdateAdvertisement.lockdownMode(vc)
					}
				}

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
				// This will only work on an iPad. On an iPhone, this will trigger
				// "Invalid attempt to call -[UIApplication requestSceneSessionDestruction:] from an unsupported device."
				// In that case, we'll just remove all tabs from the scene ourselves.
				UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil) { _ in
					(scene.delegate as? SceneDelegate)?.browsingUi.removeAllTabs()
				}
			}

			WebsiteStorage.shared.cleanup()

			completion?(true)
		}
		else {
			Log.debug(for: Self.self, "Unable to handle shortcut type '\(shortcut.type)'!")
			completion?(false)
		}
	}

	private func handle(urlContexts: Set<UIOpenURLContext>) {
		for context in urlContexts {
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
}
