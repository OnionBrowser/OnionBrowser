//
//  Tab.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

protocol TabDelegate: class {
	func updateChrome(_ sender: Tab?)
}

@objcMembers
class Tab: UIWebView, UIWebViewDelegate {

	weak var tabDelegate: TabDelegate?

	var title = URL.blank.absoluteString

	private(set) var url = URL.blank

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

	private(set) var progress: Float = 0 {
		didSet {
			tabDelegate?.updateChrome(self)
		}
	}

	private(set) var history = [[String: String]]()


	init(restorationId: String?) {
		super.init(frame: .zero)

		setup(restorationId)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}


	// MARK: UIWebViewDelegate

	func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
		return true
	}


	// MARK: Public Methods

	func refresh() {
		needsRefresh = false
		reload()
	}

	func load(_ url: URL?, postParams: String? = nil) {
		reset()

		if let url = url?.real {
			self.url = url

			DispatchQueue.main.async {
				var request = URLRequest(url: self.url)

				if let postParams = postParams {
					request.httpMethod = "POST"
					request.httpBody = postParams.data(using: .utf8)
				}

				self.loadRequest(request)
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


	// MARK: Private Methods

	private func reset() {
		stopLoading()

		url = URL.blank
		applicableHttpsEverywhereRules.removeAllObjects()
		applicableUrlBlockerTargets.removeAllObjects()
		sslCertificate = nil
	}

	private func setup(_ restorationId: String? = nil) {
		// Re-register user agent with our hash, which should only affect this UIWebView.
		UserDefaults.standard.register(defaults: ["UserAgent": "\(AppDelegate.shared()?.defaultUserAgent ?? "")/\(hash)"])

		if restorationId != nil {
			restorationIdentifier = restorationId
			needsRefresh = true
		}

		delegate = self
		scalesPageToFit = true
		allowsInlineMediaPlayback = true
	}
}
