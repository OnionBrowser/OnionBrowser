//
//  AppDelegate.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import AVFoundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, JAHPAuthenticatingHTTPProtocolDelegate {

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
	let hstsCache = HSTSCache.retrieve()

	@objc
	let cookieJar = CookieJar()

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

		show(MainViewController())

		if let shortcut = launchOptions?[.shortcutItem] as? UIApplicationShortcutItem {
			handle(shortcut)
		}

		return true
	}

	func applicationWillResignActive(_ application: UIApplication) {
		application.ignoreSnapshotOnNextApplicationLaunch()
		browsingUi?.becomesInvisible()

		BlurredSnapshot.create()
	}

	func applicationDidEnterBackground(_ application: UIApplication) {
		if !testing {
			HostSettings.store()
			hstsCache?.persist()
		}

		TabSecurity.handleBackgrounding()

		application.ignoreSnapshotOnNextApplicationLaunch()

		if OnionManager.shared.state != .stopped {
			OnionManager.shared.stopTor()
		}
	}

	func applicationDidBecomeActive(_ application: UIApplication) {
		BlurredSnapshot.remove()

		let mgr = OnionManager.shared

		if (!inStartupPhase && mgr.state != .started && mgr.state != .connected) {
			// Difficult situation to add a delegate here, so we never did.
			// Turns out, it is no problem. Tor seems to always restart correctly.
			mgr.startTor(delegate: nil)
		}
		else {
			inStartupPhase = false
		}
	}

	func applicationWillTerminate(_ application: UIApplication) {
		cookieJar.clearAllNonWhitelistedData()
		DownloadHelper.deleteDownloadsDirectory()

		application.ignoreSnapshotOnNextApplicationLaunch()
	}

	func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {

		dismissModalsAndCall {
			self.browsingUi?.addNewTab(url.withFixedScheme)
		}

		return true
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

			self.browsingUi?.present(self.alert!)
		}

		return nil
	}

	func authenticatingHTTPProtocol(_ authenticatingHTTPProtocol: JAHPAuthenticatingHTTPProtocol,
									didCancel challenge: URLAuthenticationChallenge) {

		if (alert?.isViewLoaded ?? false) && alert?.view.window != nil {
			alert?.dismiss(animated: false)
		}
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

		window?.rootViewController?.restorationIdentifier = String(describing: type(of: viewController))
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
		let lastBuild = UserDefaults.standard.integer(forKey: "last_build")

		let fmt = NumberFormatter()
		fmt.numberStyle = .decimal

		let thisBuild = fmt.number(
			from: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")?.intValue ?? 0

		if lastBuild < thisBuild {
			print("[\(String(describing: type(of: self)))] migrating from build \(lastBuild) -> \(thisBuild)")

			Migration.migrate()

			UserDefaults.standard.set(thisBuild, forKey: "last_build")
		}
	}

	private func handle(_ shortcut: UIApplicationShortcutItem, completion: (() -> Void)? = nil) {
		if shortcut.type.contains("OpenNewTab") {
			dismissModalsAndCall {
				self.browsingUi?.addEmptyTabAndFocus()
				completion?()
			}
		}
		else if shortcut.type.contains("ClearData") {
			dismissModalsAndCall {
				self.browsingUi?.removeAllTabs()
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
