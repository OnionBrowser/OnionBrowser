//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import QuickLook

protocol TabDelegate: class {
	func updateChrome(_ sender: Tab?)

	func addNewTab(_ url: URL?, forRestoration: Bool,
				   animation: BrowsingViewController.Animation,
				   completion: ((Bool) -> Void)?) -> Tab?

	func removeTab(_ tab: Tab, focus: Tab?)

	func getTab(ipcId: String?) -> Tab?

	func getTab(hash: Int?) -> Tab?

	func present(_ vc: UIViewController, _ sender: UIView?)
}

@objcMembers
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

	var url = URL.blank

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
			if sslCertificate?.isEV ?? false {
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
			tabDelegate?.updateChrome(self)
		}
	}

	static let historySize = 40
	var skipHistory = false
	var history = [[String: String]]()

	private lazy var webView: UIWebView = {
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

	var previewController: QLPreviewController?

	var downloadedFile: URL?


	init(restorationId: String?) {
		super.init(frame: .zero)

		setup(restorationId)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}


	// MARK: Public Methods

	func refresh() {
		needsRefresh = false
		skipHistory = true
		webView.reload()
	}

	func load(_ url: URL?, postParams: String? = nil) {
		var request: URLRequest?

		if let url = url?.withFixedScheme?.real {
			request = URLRequest(url: url)

			if let postParams = postParams {
				request?.httpMethod = "POST"
				request?.httpBody = postParams.data(using: .utf8)
			}
		}

		load(request)
	}

	func load(_ request: URLRequest?) {
		reset()

		if let request = request {
			if let url = request.url {
				self.url = url
			}

			DispatchQueue.main.async {
				self.webView.loadRequest(request)
			}
		}
	}

	func search(for query: String?) {
		guard let se = Settings.searchEngine,
			let searchUrl = se.searchUrl,
			let query = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return
		}

		let url: String
		var params: [String]?

		if let pp = se.postParams {
			url = searchUrl

			/* need to send this as a POST, so build our key val pairs */
			params = []

			for item in pp {
				guard let key = item.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
					continue
				}

				params?.append([key, String(format: item.value, query)].joined(separator: "="))
			}
		}
		else {
			url = String(format: searchUrl, query)
		}

		return load(URL(string: url), postParams: params?.joined(separator: "&"))
	}

	func reset() {
		webView.stopLoading()

		url = URL.blank
		applicableHttpsEverywhereRules.removeAllObjects()
		applicableUrlBlockerTargets.removeAllObjects()
		sslCertificate = nil
	}

	func goBack() {
		if webView.canGoBack {
			skipHistory = true
			webView.goBack()
		}
		else if let parentId = parentId {
			tabDelegate?.removeTab(self, focus: tabDelegate?.getTab(hash: parentId))
		}
	}

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


	// MARK: Private Methods

	private func setup(_ restorationId: String? = nil) {
		// Re-register user agent with our hash, which should only affect this UIWebView.
		UserDefaults.standard.register(defaults: ["UserAgent": "\(AppDelegate.shared()?.defaultUserAgent ?? "")/\(hash)"])

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		NotificationCenter.default.addObserver(
			self, selector: #selector(progressEstimateChanged(_:)),
			name: NSNotification.Name(rawValue: "WebProgressEstimateChangedNotification"),
			object: webView.value(forKeyPath: "documentView.webView"))

		// This doubles as a way to force the webview to initialize itself,
		// otherwise the UA doesn't seem to set right before refreshing a previous
		// restoration state.
		let hashInUa = stringByEvaluatingJavaScript(from: "navigator.userAgent")?.split(separator: "/").last

		if hashInUa?.compare(String(hash)) != ComparisonResult.orderedSame {
			print("[Tab \(url)] Aborting, not equal! hashInUa=\(String(describing: hashInUa)), hash=\(hash)")
			abort()
		}
	}

	@objc
	private func progressEstimateChanged(_ notification: Notification) {
		progress = Float(notification.userInfo?["WebProgressEstimatedProgressKey"] as? Float ?? 0)
	}


	deinit {
		cancelDownloadAndRemovePreview()

		let block = {
			self.webView.delegate = nil
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
