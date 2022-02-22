//
//  AppDelegate.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import AVFoundation
import IPtProxyUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, JAHPAuthenticatingHTTPProtocolDelegate, OnionManagerDelegate {

	@objc
	static let socksProxyPort = 39050

	@objc
	static let httpProxyPort = 0

	@objc
	class var shared: AppDelegate? {
		var delegate: UIApplicationDelegate?

		if Thread.isMainThread {
			delegate = UIApplication.shared.delegate
		}
		else {
			DispatchQueue.main.sync {
				delegate = UIApplication.shared.delegate
			}
		}

		return delegate as? AppDelegate
	}

	@objc
	let sslCertCache = NSCache<NSString, SSLCertificate>()

	@objc
	let certificateAuthentication = CertificateAuthentication()

	@objc
	let hstsCache = HstsCache.shared

	@objc
	let cookieJar = BetterCookieJar()

	@objc
	var browsingUi: BrowsingViewController?

	var testing: Bool {
		return NSClassFromString("XCTestProbe") != nil
			|| ProcessInfo.processInfo.environment["ARE_UI_TESTING"] != nil
	}

	var window: UIWindow?

	override var keyCommands: [UIKeyCommand]? {
		// If settings are up or something else, ignore shortcuts.
		if !(window?.rootViewController is BrowsingViewController)
			|| browsingUi?.presentedViewController != nil {

			return nil
		}

		var commands = [
			UIKeyCommand(input: "[", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Go Back", comment: "")),
			UIKeyCommand(input: "]", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Go Forward", comment: "")),
			UIKeyCommand(input: "b", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Show Bookmarks", comment: "")),
			UIKeyCommand(input: "l", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Focus URL Field", comment: "")),
			UIKeyCommand(input: "r", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Reload Tab", comment: "")),
			UIKeyCommand(input: "t", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Create New Tab", comment: "")),
			UIKeyCommand(input: "w", modifierFlags: .command, action: #selector(handle(_:)),
						 discoverabilityTitle: NSLocalizedString("Close Tab", comment: "")),
		]

		for i in 1 ... 10 {
			commands.append(UIKeyCommand(
				input: String(i % 10), modifierFlags: .command, action: #selector(handle(_:)),
				discoverabilityTitle: String(format: NSLocalizedString("Switch to Tab %d", comment: ""), i)))
		}

		if UIResponder.currentFirstResponder() is UIWebView {
			commands.append(contentsOf: allKeyBindings)
		}

		return commands
	}

	/**
	 Some sites do mobile detection by looking for Safari in the UA, so make us look like Mobile Safari

	 from "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H321"
	 to   "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
	 */
	let defaultUserAgent: String? = {
		var uaparts = UIWebView(frame: .zero)
			.stringByEvaluatingJavaScript(from: "navigator.userAgent")?
			.components(separatedBy: " ")

		// Assume Safari major version will match iOS major.
		let osv = UIDevice.current.systemVersion.components(separatedBy: ".")
		let index = (uaparts?.endIndex ?? 1) - 1
		uaparts?.insert("Version/\(osv.first ?? "0").0", at: index)

		// Now tack on "Safari/XXX.X.X" from WebKit version.
		for p in uaparts ?? [] {
			if p.contains("AppleWebKit/") {
				uaparts?.append(p.replacingOccurrences(of: "AppleWebKit", with: "Safari"))
				break
			}
		}

		return uaparts?.joined(separator: " ")
	}()

	private var inStartupPhase = true

	private let allKeyBindings: [UIKeyCommand] = {
		let modPermutations: [UIKeyModifierFlags] = [
			.alphaShift,
			.shift,
			.control,
			.alternate,
			.command,
			[.command, .alternate],
			[.command, .control],
			[.control, .alternate],
			[.control, .command],
			[.control, .alternate, .command],
			[]
		]

		var chars = "`1234567890-=\tqwertyuiop[]\\asdfghjkl;'\rzxcvbnm,./ "
		chars.append(UIKeyCommand.inputEscape)
		chars.append(UIKeyCommand.inputUpArrow)
		chars.append(UIKeyCommand.inputDownArrow)
		chars.append(UIKeyCommand.inputLeftArrow)
		chars.append(UIKeyCommand.inputRightArrow)

		var bindings = [UIKeyCommand]()

		for mod in modPermutations {
			for char in chars {
				bindings.append(UIKeyCommand(input: String(char), modifierFlags: mod, action: #selector(handle(_:))))
			}
		}

		return bindings
	}()

	private var alert: UIAlertController?

	/**
	Flag, if biometric/password authentication after activation was successful.

	Return to false immediately after positive check, otherwise, security issues will arise!
	*/
	private var verified = false


	// MARK: UIApplicationDelegate

	func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

		JAHPAuthenticatingHTTPProtocol.setDelegate(self)
		JAHPAuthenticatingHTTPProtocol.start()

		migrate()

		adjustMuteSwitchBehavior()

		DownloadHelper.deleteDownloadsDirectory()

		return true
	}

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

		if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
			handle(shortcut)
		}

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		application.ignoreSnapshotOnNextApplicationLaunch()
		browsingUi?.unfocusSearchField()

		BlurredSnapshot.create()
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		if !testing {
			HostSettings.store()

			// FIXES BUGS #311 and #325:
			// This was so slow, that even an explicit background task wasn't
			// good enough and iOS got impatient with us.
			// Fixed for now, as now only non-preloaded data is written to disk.
			// Left in a background task anyway, in case this list grows a lot
			// again under heavy usage and would then block restart again.
			DispatchQueue.global(qos: .background).async {
				let taskId = application.beginBackgroundTask(expirationHandler: nil)

				self.hstsCache.persist()

				application.endBackgroundTask(taskId)
			}
		}

		TabSecurity.handleBackgrounding()

		application.ignoreSnapshotOnNextApplicationLaunch()

		if OnionManager.shared.state != .stopped {
			OnionManager.shared.stopTor()
		}
	}

	private var openAfterRestore: URL? = nil

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
	{
		Settings.openNewUrlOnStart = url.withFixedScheme

		return true
	}

	func applicationDidBecomeActive(_ application: UIApplication) {

		// Note: If restart is slow (and even crashes), it could be, that
		// #applicationDidEnterBackground isn't finished, yet!

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
				applicationWillResignActive(application)
				applicationDidEnterBackground(application)
				applicationWillTerminate(application)

				exit(0)
			}

			// Always return here, as the SecureEnclave operations will always
			// trigger a user identification and therefore the app becomes inactive
			// and then active again. So #applicationDidBecomeActive will be
			// called again. Therefore, we store the result of the verification
			// in an object property and check that on re-entry.
			return
		}

		verified = false

		if inStartupPhase {
			show(MainViewController())

			inStartupPhase = false
		}
		else {
			let mgr = OnionManager.shared

			if (mgr.state != .started && mgr.state != .connected) {
				mgr.startTor(delegate: self)
			}
			else {
				self.torConnFinished()
			}
		}
	}

	func applicationWillTerminate(_ application: UIApplication) {
		cookieJar.clearAllNonWhitelistedData()
		DownloadHelper.deleteDownloadsDirectory()

		application.ignoreSnapshotOnNextApplicationLaunch()
	}

	func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {

		handle(shortcutItem) {
			completionHandler(true)
		}
	}

	func application(_ application: UIApplication, shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier) -> Bool {

		if extensionPointIdentifier == .keyboard {
			return Settings.thirdPartyKeyboards
		}

		return true
	}

	func application(_ application: UIApplication, shouldRestoreSecureApplicationState coder: NSCoder) -> Bool {
		return self.application(application, shouldRestoreApplicationState: coder)
	}

	func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {

		if testing {
			return false
		}

		if Settings.stateRestoreLock {
			print("[\(String(describing: type(of: self)))] Previous startup failed, not restoring application state.")

			Settings.stateRestoreLock = false

			return false
		}

		Settings.stateRestoreLock = true

		return true
	}

	func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
		return !testing && !TabSecurity.isClearOnBackground
	}

	func application(_ application: UIApplication, shouldSaveSecureApplicationState coder: NSCoder) -> Bool {
		return self.application(application, shouldSaveApplicationState: coder)
	}

	/**
	Unload all webviews of background tabs, if OS says, we're using too much memory.
	*/
	func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
		for tab in browsingUi?.tabs ?? [] {
			if tab != browsingUi?.currentTab {
				tab.empty()
			}
		}
	}


	// MARK: JAHPAuthenticatingHTTPProtocolDelegate

	func authenticatingHTTPProtocol(_ authenticatingHTTPProtocol: JAHPAuthenticatingHTTPProtocol?,
									logMessage message: String) {
		print("[JAHPAuthenticatingHTTPProtocol] \(message)")
	}

	func authenticatingHTTPProtocol(_ authenticatingHTTPProtocol: JAHPAuthenticatingHTTPProtocol,
									canAuthenticateAgainstProtectionSpace protectionSpace: URLProtectionSpace)
		-> Bool {

		return protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest
			|| protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic
	}

	func authenticatingHTTPProtocol(_ authenticatingHTTPProtocol: JAHPAuthenticatingHTTPProtocol,
									didReceive challenge: URLAuthenticationChallenge)
		-> JAHPDidCancelAuthenticationChallengeHandler? {

		let space = challenge.protectionSpace
		let storage = URLCredentialStorage.shared

		// If we have existing credentials for this realm, try them first.
		if challenge.previousFailureCount < 1,
			let credential = storage.credentials(for: space)?.first?.value {

			storage.set(credential, for: space)
			authenticatingHTTPProtocol.resolvePendingAuthenticationChallenge(with: credential)

			return nil
		}

		DispatchQueue.main.async {
			self.alert = AlertHelper.build(
				message: (space.realm?.isEmpty ?? true) ? space.host : "\(space.host): \"\(space.realm!)\"",
				title: NSLocalizedString("Authentication Required", comment: ""))

			AlertHelper.addTextField(self.alert!, placeholder:
				NSLocalizedString("Username", comment: ""))

			AlertHelper.addPasswordField(self.alert!, placeholder:
				NSLocalizedString("Password", comment: ""))

			self.alert?.addAction(AlertHelper.cancelAction { _ in
				challenge.sender?.cancel(challenge)
				authenticatingHTTPProtocol.client?.urlProtocol(
					authenticatingHTTPProtocol,
					didFailWithError: NSError(domain: NSCocoaErrorDomain,
											  code: NSUserCancelledError,
											  userInfo: [ORIGIN_KEY: true]))
			})

			self.alert?.addAction(AlertHelper.defaultAction(NSLocalizedString("Log In", comment: "")) { _ in
				// We only want one set of credentials per protectionSpace.
				// In case we stored incorrect credentials on the previous
				// login attempt, purge stored credentials for the
				// protectionSpace before storing new ones.
				for c in storage.credentials(for: space) ?? [:] {
					storage.remove(c.value, for: space)
				}

				let textFields = self.alert?.textFields

				let credential = URLCredential(user: textFields?.first?.text ?? "",
											   password: textFields?.last?.text ?? "",
											   persistence: .forSession)

				storage.set(credential, for: space)
				authenticatingHTTPProtocol.resolvePendingAuthenticationChallenge(with: credential)
			})

			self.window?.rootViewController?.top.present(self.alert!)
		}

		return nil
	}

	func authenticatingHTTPProtocol(_ authenticatingHTTPProtocol: JAHPAuthenticatingHTTPProtocol,
									didCancel challenge: URLAuthenticationChallenge) {

		if (alert?.isViewLoaded ?? false) && alert?.view.window != nil {
			alert?.dismiss(animated: false)
		}
	}


	// MARK: OnionManagerDelegate

	func torConnProgress(_ progress: Int) {
		// Ignored.
	}

	func torConnFinished() {
		DispatchQueue.main.async {
			BlurredSnapshot.remove()

			// Close modal dialogs, if there are URLs to open.
			if Settings.openNewUrlOnStart != nil {
				self.dismissModalsAndCall {
					self.browsingUi?.becomesVisible()
				}
			}
			else {
				self.browsingUi?.becomesVisible()
			}
		}
	}

	func torConnDifficulties() {
		// This should not happen, as Tor is expected to always restart
		// very quickly. Anyhow, show the UI at least.
		torConnFinished()
	}


	// MARK: Public Methods

	/**
	Setting `AVAudioSessionCategoryAmbient` will prevent audio from `UIWebView` from pausing
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

	func show(_ viewController: UIViewController?, _ completion: ((Bool) -> Void)? = nil) {
		if window == nil {
			window = UIWindow(frame: UIScreen.main.bounds)
			window?.backgroundColor = .accent
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

	/**
	Handle per-version upgrades or migrations.
	*/
	private func migrate() {
		let lastBuild = UserDefaults.standard.double(forKey: "last_build")

		let thisBuild = Double(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0

		// thisBuild is not necessarily bigger than lastBuild. Just different,
		// due to the way we create it in mk_build_versions.sh
		if lastBuild != thisBuild {
			print("[\(String(describing: type(of: self)))] migrating from build \(lastBuild) -> \(thisBuild)")

			Migration.migrate()

			UserDefaults.standard.set(thisBuild, forKey: "last_build")
		}
	}

	private func handle(_ shortcut: UIApplicationShortcutItem, completion: (() -> Void)? = nil) {
		if shortcut.type.contains("OpenNewTab") {
			Settings.openNewUrlOnStart = URL.blank

			completion?()
		}
		else if shortcut.type.contains("ClearData") {
			dismissModalsAndCall {
				self.browsingUi?.removeAllTabs()
				Settings.openTabs = nil
				self.cookieJar.clearAllNonWhitelistedData()
				completion?()
			}
		}
		else {
			print("[\(String(describing: type(of: self)))] Unable to handle shortcut type '\(shortcut.type)'!")
			completion?()
		}
	}

	/**
	In case, a modal view controller is overlaying the `BrowsingViewController`, we close it
	*before* adding a new tab.

	- parameter completion: Callback when dismiss is done or immediately when no dismiss was necessary.
	*/
	private func dismissModalsAndCall(completion: @escaping () -> Void) {
		if browsingUi?.presentedViewController != nil {
			browsingUi?.dismiss(animated: true, completion: completion)
		}
		// If there's no modal view controller, however, the completion block
		// would never be called.
		else {
			completion()
		}
	}

	@objc
	private func handle(_ keyCommand: UIKeyCommand) {
		if keyCommand.modifierFlags == .command {
			switch keyCommand.input {
			case "b":
				browsingUi?.showBookmarks()
				return

			case "l":
				browsingUi?.focusSearchField()
				return

			case "r":
				browsingUi?.currentTab?.refresh()
				return

			case "t":
				browsingUi?.addEmptyTabAndFocus()
				return

			case "w":
				browsingUi?.removeCurrentTab()
				return

			case "[":
				browsingUi?.currentTab?.goBack()
				return

			case "]":
				browsingUi?.currentTab?.goForward()
				return

			default:
				for i in 0 ... 9 {
					if keyCommand.input == String(i), let browsingUi = browsingUi {
						browsingUi.switchToTab(i == 0 ? browsingUi.tabs.count - 1 : i - 1)
						return
					}
				}
			}
		}

		browsingUi?.currentTab?.handleKeyCommand(keyCommand)
	}
}
