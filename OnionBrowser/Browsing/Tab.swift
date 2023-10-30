//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import QuickLook
import WebKit

protocol TabDelegate: AnyObject {
	func updateChrome()

	func addNewTab(_ url: URL?, configuration: WKWebViewConfiguration?) -> Tab?

	func addNewTab(_ url: URL?,
				   transition: BrowsingViewController.Transition,
				   configuration: WKWebViewConfiguration?,
				   completion: ((Bool) -> Void)?) -> Tab?

	func removeTab(_ tab: Tab, focus: Tab?)

	func getTab(ipcId: String?) -> Tab?

	func getTab(hash: Int?) -> Tab?

	func getIndex(of tab: Tab) -> Int?

	@discardableResult
	func present(_ vc: UIViewController, _ sender: UIView?) -> Bool

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

		if let title = webView?.title, !title.isEmpty {
			return title
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

	var needsRefresh = false

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

	private var _conf: WKWebViewConfiguration?
	private var conf: WKWebViewConfiguration {
		get {
			if let conf = _conf {
				return conf
			}

			let conf = WKWebViewConfiguration()
			conf.allowsAirPlayForMediaPlayback = true
			conf.allowsInlineMediaPlayback = true
			conf.allowsPictureInPictureMediaPlayback = true

			// BUGFIX #438: Popups already have a configuration from their parent tab,
			// injecting this a second time crashes the app.
			setupJsInjections(conf)

			return conf
		}
		set {
			_conf = newValue
		}
	}
	/**
	 https://www.hackingwithswift.com/articles/112/the-ultimate-guide-to-wkwebview
	 */
	private(set) var webView: WKWebView?

	var scrollView: UIScrollView? {
		return webView?.scrollView
	}

	weak var scrollViewDelegate: UIScrollViewDelegate?

	var canGoBack: Bool {
		return  parentId != nil || webView?.canGoBack ?? false
	}

	var canGoForward: Bool {
		return webView?.canGoForward ?? false
	}

	var isLoading: Bool {
		// BUGFIX: Sometimes, isLoading still shows true, even if progress is already at 100%.
		// So check that, too, to fix reload/cancel button display.
		return (webView?.isLoading ?? false) && progress < 1
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

	private var closing = false


	init(restorationId: String?, configuration: WKWebViewConfiguration? = nil) {
		super.init(frame: .zero)

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		if let configuration = configuration {
			conf = configuration
		}

		setup()
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
			progress = Float(webView?.estimatedProgress ?? 0)
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

		if webView?.url != nil {
			webView?.reload()
		}
		else {
			load(url)
		}
	}

	func stop() {
		webView?.stopLoading()

		// Seems not to update correctly via the #observeValue path.
		progress = 1
	}

	@objc
	func load(_ url: URL?) {
		var request: URLRequest?

		if let url = url?.withFixedScheme?.real, !url.absoluteString.isEmpty {
			request = URLRequest(url: url)
		}

		load(request)
	}

	func load(_ request: URLRequest?) {
		DispatchQueue.main.async {
			self.webView?.stopLoading()
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
				self.webView?.customUserAgent = userAgent
			}

			self.webView?.load(request)
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
		if webView?.canGoBack ?? false {
			skipHistory = true
			webView?.goBack()
		}
		else if let parentId = parentId {
			tabDelegate?.removeTab(self, focus: tabDelegate?.getTab(hash: parentId))
		}
	}

	@objc
	func goForward() {
		if webView?.canGoForward ?? false {
			skipHistory = true
			webView?.goForward()
		}
	}

	func toggleFind() {
		if #available(iOS 16.0, *) {
			webView?.isFindInteractionEnabled = !((webView?.isFindInteractionEnabled ?? false) && webView?.findInteraction?.isFindNavigatorVisible ?? false)

			if webView?.isFindInteractionEnabled ?? false {
				webView?.findInteraction?.presentFindNavigator(showingReplace: false)
			}
		}
	}

	func stringByEvaluatingJavaScript(from script: String, _ completion: @escaping (String?) -> Void) {
		guard let webView = webView else {
			return completion(nil)
		}

		webView.evaluateJavaScript(script) { result, error in
			let string = result as? String

			if let error = error {
				print("[\(String(describing: type(of: self)))]#stringByEvaluatingJavaScript error=\(error)")
			}

			completion(string)
		}
	}

	/**
	Call this before giving up the tab, otherwise memory leaks will occur!
	*/
	func close() {
		// Avoid closing loops which might crash the app.
		if closing {
			return
		}

		closing = true

		cancelDownload()

		Thread.performOnMain {
			self.tabDelegate = nil

			self.destructWebView()

			self.removeFromSuperview()
		}
	}

	func empty() {
		Thread.performOnMain {
			self.stop()

			// Will empty the webView, but keep the URL and doesn't create a history entry.
			self.stringByEvaluatingJavaScript(from: "document.open()") { _ in }
			
			self.needsRefresh = true
		}
	}
	
	func getSnapshot(size: CGSize) -> UIImage? {
		if snapshot == nil, let scrollView = scrollView {
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

	func reinitWebView() {
		destructWebView()
		setup()

		needsRefresh = true
	}

	
	// MARK: Private Methods

	private func setup() {
		if #available(iOS 17.0, *), Settings.useBuiltInTor == true {
			if let proxy = TorManager.shared.torSocks5 {
				conf.websiteDataStore.proxyConfigurations.removeAll()
				conf.websiteDataStore.proxyConfigurations.append(ProxyConfiguration(socksv5Proxy: proxy))
			}
			else {
				// Delay setup until we have Tor available and somebody tells us.
				return
			}
		}

		webView = WKWebView(frame: .zero, configuration: conf)

#if DEBUG
		if #available(iOS 16.4, *) {
			webView?.isInspectable = true
		}
#endif

		webView?.uiDelegate = self
		webView?.navigationDelegate = self
		webView?.scrollView.delegate = scrollViewDelegate

		webView?.add(to: self)

		webView?.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

		setupGestureRecognizers()

		if Self.defaultUserAgent.isEmpty {
			stringByEvaluatingJavaScript(from: "navigator.userAgent") { ua in
				if let ua = ua, !ua.isEmpty {
					Self.defaultUserAgent = ua
				}
			}
		}

		// Immediately refresh the page if its host settings were changed, so
		// users sees the impact of their changes.
		NotificationCenter.default.addObserver(self, selector: #selector(hostSettingsChanged),
											   name: .hostSettingsChanged, object: nil)
	}

	private func destructWebView() {
		NotificationCenter.default.removeObserver(self)

		self.scrollView?.delegate = nil
		self.webView?.uiDelegate = nil
		self.webView?.navigationDelegate = nil

		self.removeGestureRecognizers()

		self.stop()
		self.webView?.loadHTMLString("", baseURL: nil)

		self.webView?.removeFromSuperview()
		self.webView = nil
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
