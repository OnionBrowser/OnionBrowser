//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import QuickLook

protocol TabDelegate: AnyObject {
	func updateChrome()

	func addNewTab(_ url: URL?) -> Tab?

	func addNewTab(_ url: URL?, forRestoration: Bool,
				   transition: BrowsingViewController.Transition,
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


	weak var tabDelegate: TabDelegate?

	var title: String {
		if let downloadedFile = downloadedFile {
			return downloadedFile.lastPathComponent
		}

		if let title = stringByEvaluatingJavaScript(from: "document.title") {
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

	@objc(applicableHTTPSEverywhereRules)
	var applicableHttpsEverywhereRules = NSMutableDictionary()

	@objc(applicableURLBlockerTargets)
	var applicableUrlBlockerTargets = NSMutableDictionary()

	@objc(SSLCertificate)
	var sslCertificate: SSLCertificate? {
		didSet {
			if sslCertificate == nil {
				secureMode = .insecure
			}
			else if sslCertificate?.isEV ?? false {
				secureMode = .secureEv
			}
			else {
				secureMode = .secure
			}
		}
	}

	@objc
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

	private(set) lazy var webView: UIWebView = {
		let view = UIWebView()

		view.delegate = self
		view.scalesPageToFit = true
		view.allowsInlineMediaPlayback = true

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
		return webView.isLoading
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


	init(restorationId: String?) {
		super.init(frame: .zero)

		setup(restorationId)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
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

		let request = request ?? URLRequest(url: URL.start)

		if let url = request.url {
			if url == URL.start {
				Bookmark.updateStartPage()
			}

			self.url = url
		}

		DispatchQueue.main.async {
			self.webView.loadRequest(request)
		}
	}

	@objc
	func search(for query: String?) {
		return load(LiveSearchViewController.constructRequest(query))
	}

	func reset(_ url: URL? = nil) {
		applicableHttpsEverywhereRules.removeAllObjects()
		applicableUrlBlockerTargets.removeAllObjects()
		sslCertificate = nil
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

	@discardableResult
	func stringByEvaluatingJavaScript(from script: String) -> String? {
		return webView.stringByEvaluatingJavaScript(from: script)
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
			self.webView.delegate = nil

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
			self.stringByEvaluatingJavaScript(from: "document.open()")
			
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

	private func setup(_ restorationId: String? = nil) {
		// Re-register user agent with our hash, which should only affect this UIWebView.
		UserDefaults.standard.register(defaults: ["UserAgent": "\(AppDelegate.shared?.defaultUserAgent ?? "")/\(hash)"])

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		NotificationCenter.default.addObserver(
			self, selector: #selector(progressEstimateChanged(_:)),
			name: NSNotification.Name(rawValue: "WebProgressEstimateChangedNotification"),
			object: webView.value(forKeyPath: "documentView.webView"))

		// Immediately refresh the page if its host settings were changed, so
		// users sees the impact of their changes.
		NotificationCenter.default.addObserver(self, selector: #selector(hostSettingsChanged(_:)),
											   name: .hostSettingsChanged, object: nil)

		// This doubles as a way to force the webview to initialize itself,
		// otherwise the UA doesn't seem to set right before refreshing a previous
		// restoration state.
		let hashInUa = stringByEvaluatingJavaScript(from: "navigator.userAgent")?.split(separator: "/").last

		if hashInUa?.compare(String(hash)) != ComparisonResult.orderedSame {
			print("[Tab \(index)] Aborting, not equal! hashInUa=\(String(describing: hashInUa)), hash=\(hash)")
			abort()
		}

		setupGestureRecognizers()
	}

	@objc
	private func progressEstimateChanged(_ notification: Notification) {
		clearSnapshot()

		progress = Float(notification.userInfo?["WebProgressEstimatedProgressKey"] as? Float ?? 0)
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
