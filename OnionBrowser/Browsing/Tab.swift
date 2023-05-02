//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import QuickLook
import WebKit

protocol TabDelegate: AnyObject {
	func updateChrome()

	func addNewTab(_ url: URL?, configuration: WKWebViewConfiguration?) -> Tab?

	func addNewTab(_ url: URL?, forRestoration: Bool,
				   transition: BrowsingViewController.Transition,
				   configuration: WKWebViewConfiguration?,
				   completion: ((Bool) -> Void)?) -> Tab?

	func removeTab(_ tab: Tab, focus: Tab?)

	func getTab(ipcId: String?) -> Tab?

	func getTab(hash: Int?) -> Tab?

	func getIndex(of tab: Tab) -> Int?

	func present(_ vc: UIViewController, _ sender: UIView?)

	func unfocusSearchField()
}

class Tab: UIView {

	@objc
	enum SecureMode: Int {
		case insecure
		case mixed
		case secure
		case secureEv
	}

	/**
	 Some sites do mobile detection by looking for Safari in the UA, so make us look like Mobile Safari

	 from "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H321"
	 to   "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
	 */
	private static var defaultUserAgent = "" {
		didSet {
			var uaparts = defaultUserAgent.components(separatedBy: " ")

			// Assume Safari major version will match iOS major.
			let osv = UIDevice.current.systemVersion.components(separatedBy: ".")
			let index = (uaparts.endIndex) - 1
			uaparts.insert("Version/\(osv.first ?? "0").0", at: index)

			// Now tack on "Safari/XXX.X.X" from WebKit version.
			for p in uaparts {
				if p.contains("AppleWebKit/") {
					uaparts.append(p.replacingOccurrences(of: "AppleWebKit", with: "Safari"))
					break
				}
			}

			defaultUserAgent = uaparts.joined(separator: " ")
		}
	}


	weak var tabDelegate: TabDelegate?

	var title: String {
		if let downloadedFile = downloadedFile {
			return downloadedFile.lastPathComponent
		}

		if let title = webView.title {
			if !title.isEmpty {
				return title
			}
		}

		return BrowsingViewController.prettyTitle(url)
	}

	var parentId: Int?

	var ipcId: String?

	@objc
	var url = URL.start

	@objc
	var index: Int {
		return tabDelegate?.getIndex(of: self) ?? -1
	}

	private(set) var needsRefresh = false

	@objc(applicableURLBlockerTargets)
	var applicableUrlBlockerTargets = NSMutableDictionary()

	var tlsCertificate: SSLCertificate? {
		didSet {
			if tlsCertificate == nil {
				secureMode = .insecure
			}
			else if tlsCertificate?.isEV ?? false {
				secureMode = .secureEv
			}
			else {
				secureMode = .secure
			}
		}
	}

	var secureMode = SecureMode.insecure

	@nonobjc
	var progress: Float = 0 {
		didSet {
			DispatchQueue.main.async {
				self.tabDelegate?.updateChrome()
			}
		}
	}

	static let historySize = 40
	var skipHistory = false

	var history = [HistoryViewController.Item]()

	override var isUserInteractionEnabled: Bool {
		didSet {
			if previewController != nil {
				if isUserInteractionEnabled {
					overlay.removeFromSuperview()
				}
				else {
					overlay.add(to: self)
				}
			}
		}
	}

	private(set) var configuration: WKWebViewConfiguration!

	/**
	 https://www.hackingwithswift.com/articles/112/the-ultimate-guide-to-wkwebview
	 */
	private(set) lazy var webView: WKWebView = {
		let view = WKWebView(frame: .zero, configuration: configuration)

		view.uiDelegate = self
		view.navigationDelegate = self

		return view.add(to: self)
	}()

	var scrollView: UIScrollView {
		return webView.scrollView
	}

	var canGoBack: Bool {
		return  parentId != nil || webView.canGoBack
	}

	var canGoForward: Bool {
		return webView.canGoForward
	}

	var isLoading: Bool {
		// BUGFIX: Sometimes, isLoading still shows true, even if progress is already at 100%.
		// So check that, too, to fix reload/cancel button display.
		return webView.isLoading && progress < 1
	}

	var previewController: QLPreviewController?

	/**
	Add another overlay (a hack to create a transparant clickable view)
	to disable interaction with the file preview when used in the tab overview.
	*/
	private(set) lazy var overlay: UIView = {
		let view = UIView()
		view.backgroundColor = .white
		view.alpha = 0.11
		view.isUserInteractionEnabled = false

		return view
	}()

	var downloadedFile: URL?

	private(set) lazy var refresher: UIRefreshControl = {
		let refresher = UIRefreshControl()

		refresher.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull to Refresh Page", comment: ""))

		return refresher
	}()

	private var snapshot: UIImage?


	init(restorationId: String?, configuration: WKWebViewConfiguration? = nil) {
		super.init(frame: .zero)

		setup(restorationId, configuration: configuration)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?,
							   change: [NSKeyValueChangeKey : Any]?,
							   context: UnsafeMutableRawPointer?)
	{
		if keyPath == "estimatedProgress" {
			progress = Float(webView.estimatedProgress)
		}
	}

	// MARK: Public Methods

	@objc
	func refresh() {
		if url == URL.start {
			Bookmark.updateStartPage()
		}

		needsRefresh = false
		skipHistory = true
		webView.reload()
	}

	func stop() {
		webView.stopLoading()
	}

	@objc
	func load(_ url: URL?) {
		var request: URLRequest?

		if let url = url?.withFixedScheme?.real {
			request = URLRequest(url: url)
		}

		load(request)
	}

	func load(_ request: URLRequest?) {
		DispatchQueue.main.async {
			self.webView.stopLoading()
		}

		reset()

		var request = request ?? URLRequest(url: URL.start)

		// https://globalprivacycontrol.github.io/gpc-spec/
		if Settings.sendGpc {
			request.setValue("1", forHTTPHeaderField: "Sec-GPC")
		}

		if let url = request.url {
			if url == URL.start {
				Bookmark.updateStartPage()
			}
			else if let bookmark = Bookmark.all.first(where: { $0.url == url }) {
				DispatchQueue.global(qos: .utility).async {
					bookmark.acquireIcon { updated in
						if updated {
							Bookmark.store()
						}
					}
				}
			}

			self.url = url
		}

		DispatchQueue.main.async {
			var userAgent = HostSettings.for(request.url?.host).userAgent

			if userAgent.isEmpty {
				userAgent = Self.defaultUserAgent
			}

			if !userAgent.isEmpty {
				self.webView.customUserAgent = userAgent
			}

			self.webView.load(request)
		}
	}

	@objc
	func search(for query: String?) {
		return load(LiveSearchViewController.constructRequest(query))
	}

	func reset(_ url: URL? = nil) {
		applicableUrlBlockerTargets.removeAllObjects()
		tlsCertificate = nil
		self.url = url ?? URL.start
	}

	@objc
	func goBack() {
		if webView.canGoBack {
			skipHistory = true
			webView.goBack()
		}
		else if let parentId = parentId {
			tabDelegate?.removeTab(self, focus: tabDelegate?.getTab(hash: parentId))
		}
	}

	@objc
	func goForward() {
		if webView.canGoForward {
			skipHistory = true
			webView.goForward()
		}
	}

	func stringByEvaluatingJavaScript(from script: String, _ completion: @escaping (String?) -> Void) {
		webView.evaluateJavaScript(script) { result, error in
			let string = result as? String

			if let error = error {
				print("[\(String(describing: type(of: self)))]#stringByEvaluatingJavaScript error=\(error)")
			}

			completion(string)
		}
	}

	func stringByEvaluatingJavaScript(from script: String) -> String? {
		var string: String?

		let group = DispatchGroup()
		group.enter()

		webView.evaluateJavaScript(script) { result, error in
			string = result as? String

			if let error = error {
				print("[\(String(describing: type(of: self)))]#stringByEvaluatingJavaScript error=\(error)")
			}

			group.leave()
		}

		_ = group.wait(timeout: .now() + 2)

		return string
	}

	/**
	Call this before giving up the tab, otherwise memory leaks will occur!
	*/
	func close() {
		cancelDownload()

		let block = {
			NotificationCenter.default.removeObserver(self)

			self.tabDelegate = nil
			self.scrollView.delegate = nil
			self.webView.uiDelegate = nil
			self.webView.navigationDelegate = nil

			for gr in self.webView.gestureRecognizers ?? [] {
				self.webView.removeGestureRecognizer(gr)
			}

			self.stop()
			self.webView.loadHTMLString("", baseURL: nil)

			self.webView.removeFromSuperview()
			self.removeFromSuperview()
		}

		if Thread.isMainThread {
			block()
		}
		else {
			DispatchQueue.main.sync(execute: block)
		}
	}

	func empty() {
		let block = {
			self.stop()

			// Will empty the webView, but keep the URL and doesn't create a history entry.
			self.stringByEvaluatingJavaScript(from: "document.open()") { _ in }
			
			self.needsRefresh = true
		}

		if Thread.isMainThread {
			block()
		}
		else {
			DispatchQueue.main.sync(execute: block)
		}
	}
	
	func getSnapshot(size: CGSize) -> UIImage? {
		if snapshot == nil {
			let offset = scrollView.contentOffset
			let frame = scrollView.frame

			scrollView.contentOffset = .zero
			scrollView.frame = CGRect(
				x: 0, y: 0,
				width: scrollView.contentSize.width,
				height: scrollView.contentSize.height)

			snapshot = scrollView.layer.makeSnapshot(scale: 1.0)?.topCropped(newSize: size)

			scrollView.contentOffset = offset
			scrollView.frame = frame
		}

		return snapshot
	}

	func clearSnapshot() {
		snapshot = nil
	}
	
	
	// MARK: Private Methods

	private func setup(_ restorationId: String? = nil, configuration: WKWebViewConfiguration? = nil) {
		if configuration == nil {
			self.configuration = WKWebViewConfiguration()
			self.configuration.allowsAirPlayForMediaPlayback = true
			self.configuration.allowsInlineMediaPlayback = true
			self.configuration.allowsPictureInPictureMediaPlayback = true
		}
		else {
			self.configuration = configuration
		}

		setupJsInjections()

		if Self.defaultUserAgent.isEmpty {
			webView.evaluateJavaScript("navigator.userAgent") { result, error in
				if let error = error {
					print("[\(String(describing: type(of: self)))] evaluate 'navigator.userAgent' error: \(error)")
				}

				if let ua = result as? String, !ua.isEmpty {
					Self.defaultUserAgent = ua
				}
			}
		}

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

		// Immediately refresh the page if its host settings were changed, so
		// users sees the impact of their changes.
		NotificationCenter.default.addObserver(self, selector: #selector(hostSettingsChanged(_:)),
											   name: .hostSettingsChanged, object: nil)

		setupGestureRecognizers()
	}

	@objc
	private func hostSettingsChanged(_ notification: Notification) {
		let host = notification.object as? String

		// Refresh on default changes and specific changes for this host.
		if host == nil || host == self.url.host {
			self.refresh()
		}
	}


	deinit {
		close()
	}
}
