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

protocol TabDelegate: class {
	func updateChrome(_ sender: Tab?)

	func addNewTab(_ url: URL?, forRestoration: Bool,
				   animation: BrowsingViewController.Animation,
				   completion: ((Bool) -> Void)?) -> Tab?

	func removeTab(_ tab: Tab, focus: Tab?)

	func getTab(ipcId: String?) -> Tab?

	func getTab(hash: Int?) -> Tab?
}

@objcMembers
class Tab: UIView {

	weak var tabDelegate: TabDelegate?

	var title = URL.blank.absoluteString

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
				secureMode = .secureEV
			}
			else {
				secureMode = .secure
			}
		}
	}

	private(set) var secureMode = WebViewTabSecureMode.insecure

	@nonobjc
	var progress: Float = 0 {
		didSet {
			tabDelegate?.updateChrome(self)
		}
	}

	private(set) var history = [[String: String]]()

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
			webView.goBack()
		}
		else if let parentId = parentId {
			tabDelegate?.removeTab(self, focus: tabDelegate?.getTab(hash: parentId))
		}
	}

	func goForward() {
		webView.goForward()
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
	}
}
