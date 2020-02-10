//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import QuickLook
import WebKit

protocol TabDelegate: class {
	func updateChrome(_ sender: Tab?)

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
				self.tabDelegate?.updateChrome(self)
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

	/**
	https://www.hackingwithswift.com/articles/112/the-ultimate-guide-to-wkwebview
	*/
	private(set) lazy var webView: WKWebView = {
		let conf = WKWebViewConfiguration()
		conf.allowsAirPlayForMediaPlayback = true
		conf.allowsInlineMediaPlayback = true
		conf.allowsPictureInPictureMediaPlayback = true

		let view = WKWebView(frame: .zero, configuration: conf)

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


	init(restorationId: String?) {
		super.init(frame: .zero)

		setup(restorationId)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?,
							   change: [NSKeyValueChangeKey : Any]?,
							   context: UnsafeMutableRawPointer?) {
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

		let request = request ?? URLRequest(url: URL.start)

		if let url = request.url {
			if url == URL.start {
				Bookmark.updateStartPage()
			}

			self.url = url
		}

		DispatchQueue.main.async {
			self.webView.load(request)
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
		var done = false
		var string: String?

		webView.evaluateJavaScript(script) { result, error in
			string = result as? String

			if let error = error {
				print("[\(String(describing: type(of: self)))]#stringByEvaluatingJavaScript error=\(error)")
			}

			done = true
		}

		while !done {
			Thread.sleep(forTimeInterval: 0.2)
		}

		return string
	}


	// MARK: Private Methods

	private func setup(_ restorationId: String? = nil) {
		// Re-register user agent with our hash, which should only affect this UIWebView.
		UserDefaults.standard.register(defaults: ["UserAgent": "\(AppDelegate.shared?.defaultUserAgent ?? "")/\(hash)"])

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

		// Immediately refresh the page if its host settings were changed, so
		// users sees the impact of their changes.
		NotificationCenter.default.addObserver(forName: .hostSettingsChanged,
											   object: nil, queue: .main)
		{ notification in
			let host = notification.object as? String

			// Refresh on default changes and specific changes for this host.
			if host == nil || host == self.url.host {
				self.refresh()
			}
		}

		webView.customUserAgent = AppDelegate.shared?.defaultUserAgent

		setupGestureRecognizers()
	}


	deinit {
		cancelDownload()

		let block = {
			self.webView.uiDelegate = nil
			self.webView.navigationDelegate = nil
			self.webView.stopLoading()

			for gr in self.webView.gestureRecognizers ?? [] {
				self.webView.removeGestureRecognizer(gr)
			}

			self.removeFromSuperview()
		}

		if Thread.isMainThread {
			block()
		}
		else {
			DispatchQueue.main.sync(execute: block)
		}
	}
}
