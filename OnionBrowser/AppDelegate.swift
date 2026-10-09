//
//  AppDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 09.01.20.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import AVFoundation
import IPtProxyUI_iOS

@UIApplicationMain
class AppDelegate: NSObject, UIApplicationDelegate {

	@objc
	class var shared: AppDelegate? {
		var delegate: UIApplicationDelegate?

		Thread.performOnMain {
			delegate = UIApplication.shared.delegate
		}

		return delegate as? AppDelegate
	}

	/**
	 ATTENTION: Needs to be called from main thread!
	 */
	var sceneDelegates: [SceneDelegate] {
		UIApplication.shared.connectedScenes.compactMap {
			$0.delegate as? SceneDelegate
		}
	}

	/**
	 ATTENTION: Needs to be called from main thread!
	 */
	@objc
	var browsingUis: [BrowsingViewController] {
		sceneDelegates.compactMap { $0.browsingUi }
	}

	/**
	 ATTENTION: Needs to be called from main thread!
	 */
	var allOpenTabs: [Tab] {
		browsingUis.flatMap { $0.tabs }
	}

	var testing: Bool {
		return NSClassFromString("XCTestProbe") != nil
			|| ProcessInfo.processInfo.environment["ARE_UI_TESTING"] != nil
	}

	var firstScene = true

	private var backgroundTaskId: UIBackgroundTaskIdentifier?


	// MARK: UIApplicationDelegate

	func application(_ application: UIApplication, willFinishLaunchingWithOptions
					 launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool
	{
		adjustMuteSwitchBehavior()

		DownloadHelper.purge()

		Settings.stateLocation = FileManager.default.ptDir!

		_ = ContentRules.shared // Init as early as possible, since init is async!

		return true
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>)
	{
		application.ignoreSnapshotOnNextApplicationLaunch()
	}

	func applicationWillTerminate(_ application: UIApplication)
	{
		if !testing {
			HostSettings.store()
		}

		WebsiteStorage.shared.cleanup()

		DownloadHelper.purge()

		TorManager.shared.stop()

		application.ignoreSnapshotOnNextApplicationLaunch()
	}

	func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier
					 extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool
	{
		if extensionPointIdentifier == .keyboard {
			return Settings.thirdPartyKeyboards
		}

		return true
	}

	func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool
	{
		return self.application(application, shouldRestoreApplicationState: coder)
	}

	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool
	{
		if testing {
			return false
		}

		if Settings.stateRestoreLock {
			Log.debug(for: Self.self, "Previous startup failed, not restoring application state.")

			Settings.stateRestoreLock = false

			return false
		}

		Settings.stateRestoreLock = true

		return true
	}

	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool
	{
		return !testing && Settings.tabSecurity != .clearOnBackground
	}

	func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool
	{
		return self.application(application, shouldSaveApplicationState: coder)
	}

	/**
	 Unload all webviews of background tabs, if OS says, we're using too much memory.
	 */
	func applicationDidReceiveMemoryWarning(_ application: UIApplication)
	{
		for vc in browsingUis {
			for tab in vc.tabs {
				if tab != vc.currentTab {
					tab.empty()
				}
			}
		}
	}


	// MARK: Public Methods

	/**
	 Setting `AVAudioSessionCategoryAmbient` will prevent audio from `WKWebView` from pausing
	 already-playing audio from other apps.
	 */
	func adjustMuteSwitchBehavior() {
		let session = AVAudioSession.sharedInstance()

		if Settings.muteWithSwitch {
			try? session.setCategory(.ambient)
			try? session.setActive(false)
		}
		else {
			try? session.setCategory(.playback)
		}
	}

	func dismissModals<T: UIViewController>(of type: T.Type, in vcs: [UIViewController]? = nil) {
		for vc in vcs ?? browsingUis {
			if let pvc = vc.presentedViewController {
				if pvc is T {
					vc.dismiss(animated: true)
				}
				else if let navC = pvc as? UINavigationController {
					if navC.viewControllers.first is T {
						vc.dismiss(animated: true)
					}
					else if let i = navC.viewControllers.firstIndex(where: { $0 is T }) {
						navC.popToViewController(navC.viewControllers[i - 1], animated: true)
					}
				}
				else {
					dismissModals(of: type, in: [pvc])
				}
			}
		}
	}

	func maybeStopApp() {
		Thread.performOnMain {
			let sceneDelegates = self.sceneDelegates

			if sceneDelegates.isEmpty {
				// On an iPad. The last scene was just removed. Terminate.
				self.terminate()
			}
			else if sceneDelegates.count == 1 {
				// Only 1 scene left and we're in the background.
				// Keep alive as long as possible and then stop Tor properly,
				// before we have a dangling Tor which got its connections closed.
				self.endBackgroundTask()

				self.backgroundTaskId = UIApplication.shared.beginBackgroundTask(expirationHandler: self.terminate)
			}
		}
	}

	func dontStopApp() {
		endBackgroundTask()
	}

	private func terminate() {
		applicationWillTerminate(UIApplication.shared)

		endBackgroundTask()
	}

	private func endBackgroundTask() {
		if let taskId = backgroundTaskId {
			UIApplication.shared.endBackgroundTask(taskId)
			self.backgroundTaskId = nil
		}
	}
}
