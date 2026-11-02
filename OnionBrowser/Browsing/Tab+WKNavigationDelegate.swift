//
//  Tab+WKNavigationDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 27.07.22.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

@preconcurrency import WebKit
import OrbotKit

extension Tab: WKNavigationDelegate {

	private static let universalLinksWorkaroundKey = "yayprivacy"


	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
				 preferences: WKWebpagePreferences,
				 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void)
	{
		guard let result = BaseNavigationDelegate.webView(webView, decidePolicyFor: navigationAction, preferences: preferences)
		else {
			return decisionHandler(.cancel, preferences)
		}

		let url = result.url

		if let rule = UrlBlocker.shared.blockRule(for: url, withMain: self.url) {
			applicableUrlBlockerRules.insert(rule)

			return decisionHandler(.cancel, preferences)
		}

		let navigationType = navigationAction.navigationType

		// Try to prevent universal links from triggering by refusing the initial request and starting a new one.
		let iframe = url.absoluteString != navigationAction.request.mainDocumentURL?.absoluteString

		if result.hs.universalLinkProtection {
			if iframe {
				Log.debug(for: Self.self, "[Tab \(index)] not doing universal link workaround for iframe \(url).")
			}
			else if navigationType == .backForward {
				Log.debug(for: Self.self, "[Tab \(index)] not doing universal link workaround for back/forward navigation to \(url).")
			}
			else if navigationType == .formSubmitted {
				Log.debug(for: Self.self, "[Tab \(index)] not doing universal link workaround for form submission to \(url).")
			}
			else if (url.isHttp || url.isHttps)
						&& (URLProtocol.property(forKey: Tab.universalLinksWorkaroundKey, in: navigationAction.request) == nil)
			{
				if let tr = navigationAction.request as? NSMutableURLRequest {
					URLProtocol.setProperty(true, forKey: Tab.universalLinksWorkaroundKey, in: tr)

					Log.debug(for: Self.self, "[Tab \(index)] doing universal link workaround for \(url).")

					load(tr as URLRequest)

					return decisionHandler(.cancel, preferences)
				}
			}
		}
		else {
			Log.debug(for: Self.self, "[Tab \(index)] not doing universal link workaround for \(url) due to HostSettings.")
		}

		if !iframe {
			reset(navigationAction.request.mainDocumentURL)
		}

		if navigationAction.shouldPerformDownload {
			decisionHandler(.download, preferences)
		}
		else {
			cancelDownload()

			decisionHandler(.allow, preferences)
		}
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
				 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void)
	{
		let url = webView.url

		// Redirect to provided Onion-Location, if any available, and
		// - was not already served over an onion site,
		// - was served over HTTPS,
		// - isn't switched off by the user,
		// - is a valid URL with http: or https: protocol and a .onion hostname,
		//
		// https://community.torproject.org/onion-services/advanced/onion-location/
		if !(url?.isOnion ?? false)
			&& (url?.isHttps ?? false)
			&& HostSettings.for(url?.host).followOnionLocationHeader,
		   let headers = (navigationResponse.response as? HTTPURLResponse)?.allHeaderFields,
		   let olHeader = headers.first(where: { ($0.key as? String)?.lowercased() == "onion-location" })?.value as? String,
		   let onionLocation = URL(string: olHeader),
		   (onionLocation.isHttp || onionLocation.isHttps)
			&& onionLocation.isOnion
		{
			Log.debug(for: Self.self, "Redirect to Onion-Location=\(onionLocation.absoluteString)")

			decisionHandler(.cancel)

			Task {
				await MainActor.run {
					load(onionLocation)
				}
			}

			return
		}


		if navigationResponse.canShowMIMEType {
			decisionHandler(.allow)
		}
		else {
			decisionHandler(.download)
		}
	}

	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
		url = webView.url ?? URL.start

		tabDelegate?.updateChrome()
	}

	func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
		download.delegate = self
	}

	func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
		download.delegate = self
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
		Task {
			// If we have JavaScript blocked, these will be empty.
			var finalUrl = await stringByEvaluatingJavaScript(from: "window.location.href")

			if finalUrl?.isEmpty ?? true {
				finalUrl = webView.url?.absoluteString
			}

			url = URL(string: finalUrl ?? URL.start.absoluteString) ?? URL.start

			if !skipHistory {
				while history.count > Tab.historySize {
					history.remove(at: 0)
				}

				if history.isEmpty || history.last?.url.absoluteString != finalUrl,
				   let cleanUrl = url.clean
				{
					history.append(HistoryViewController.Item(url: cleanUrl, title: title))
				}
			}

			skipHistory = false

			if let trust = webView.serverTrust {
				tlsCertificate = TlsCertificate.load(trust: trust)
			}
		}
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
		handle(error: error, webView, navigation)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
		handle(error: error, webView, navigation)
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
				 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
	{
		handle(challenge: challenge, completionHandler)
	}

	func handle(challenge: URLAuthenticationChallenge, _ completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
	{
		let space = challenge.protectionSpace

		switch space.authenticationMethod {
		case NSURLAuthenticationMethodHTTPBasic, NSURLAuthenticationMethodHTTPDigest:
			let storage = URLCredentialStorage.shared

			// If we have existing credentials for this realm, try them first.
			if challenge.previousFailureCount < 1,
				let credential = storage.credentials(for: space)?.first?.value
			{
				completionHandler(.useCredential, credential)
			}
			else {
				let alert = AlertHelper.build(
					message: (space.realm?.isEmpty ?? true) ? space.host : "\(space.host): \"\(space.realm!)\"",
					title: NSLocalizedString("Authentication Required", comment: ""),
					actions: [AlertHelper.cancelAction { _ in
						completionHandler(.rejectProtectionSpace, nil)
					}])

				AlertHelper.addTextField(alert, placeholder:
					NSLocalizedString("Username", comment: ""))

				AlertHelper.addPasswordField(alert, placeholder:
					NSLocalizedString("Password", comment: ""))

				alert.addAction(AlertHelper.defaultAction(NSLocalizedString("Log In", comment: "")) { _ in
					// We only want one set of credentials per protectionSpace.
					// In case we stored incorrect credentials on the previous
					// login attempt, purge stored credentials for the
					// protectionSpace before storing new ones.
					for c in storage.credentials(for: space) ?? [:] {
						storage.remove(c.value, for: space)
					}

					let textFields = alert.textFields

					let credential = URLCredential(user: textFields?.first?.text ?? "",
												   password: textFields?.last?.text ?? "",
												   persistence: .forSession)

					storage.set(credential, for: space)

					completionHandler(.useCredential, credential)
				})

				Task {
					await MainActor.run {
						guard tabDelegate?.present(alert, nil) ?? false else {
							return completionHandler(.rejectProtectionSpace, nil)
						}
					}
				}
			}

		default:
			let credential = BaseNavigationDelegate.handle(challenge: challenge)
			completionHandler(credential != nil ? .useCredential : .performDefaultHandling, credential)
		}
	}

	func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge,
				 shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void)
	{
		if let decision = BaseNavigationDelegate.shouldAllowDeprecatedTls(challenge) {
			return decisionHandler(decision)
		}

		let space = challenge.protectionSpace

		let msg = NSLocalizedString("The encryption method for this server is outdated.", comment: "")
			+ "\n\n"
			+ String(
				format: NSLocalizedString(
					"You might be connecting to a server that is pretending to be \"%@\" which could put your confidential information at risk.",
					comment: "Placeholder is server domain"),
				space.host)

		let alert = AlertHelper.build(message: msg, actions: [
			AlertHelper.defaultAction() { _ in
				decisionHandler(false)
			},
			AlertHelper.destructiveAction(NSLocalizedString("Ignore for this host", comment: "")) { _ in
				let hs = HostSettings.for(space.host)
				hs.ignoreTlsErrors = true
				hs.save().store()

				decisionHandler(true)
			}
		])

		guard tabDelegate?.present(alert, nil) ?? false else {
			return decisionHandler(false)
		}
	}


	// MARK: Private Methods

	/**
	 TLS testing site: https://badssl.com/
	 */
	private func handle(error: Error, _ webView: WKWebView, _ navigation: WKNavigation?) {
		var failedUrl = url

		if let url = webView.url {
			self.url = url
			self.progress = 1
		}

		let error = error as NSError

		if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
			return
		}

		// "The operation couldn't be completed. (Cocoa error 3072.)" - useless
		if error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError {
			return
		}

		// "Frame load interrupted" - not very helpful.
		if error.domain == "WebKitErrorDomain" && error.code == 102 {
			return
		}

		var isTLSError = false
		var msg = error.localizedDescription

		// https://opensource.apple.com/source/libsecurity_ssl/libsecurity_ssl-36800/lib/SecureTransport.h
		if error.domain == NSOSStatusErrorDomain {
			switch (error.code) {
			case Int(errSSLProtocol): /* -9800 */
				msg = NSLocalizedString("TLS protocol error", comment: "")
				isTLSError = true

			case Int(errSSLNegotiation): /* -9801 */
				msg = NSLocalizedString("TLS handshake failed", comment: "")
				isTLSError = true

			case Int(errSSLXCertChainInvalid): /* -9807 */
				msg = NSLocalizedString("TLS certificate chain verification error (self-signed certificate?)", comment: "")
				isTLSError = true

			case -1202:
				isTLSError = true

			default:
				break
			}
		}

		if error.domain == NSURLErrorDomain && error.code == -1202 {
			isTLSError = true
		}

		if !isTLSError {
			msg += "\n(code: \(error.code), domain: \(error.domain))"
		}

		// Get the URL of the *failed* request from the error, in case that one has a different opinion.
		if let u = error.userInfo[NSURLErrorFailingURLErrorKey] as? String,
		   let u = URL(string: u)
		{
			failedUrl = u
		}

		msg += "\n\n\(failedUrl.absoluteString)"

		Log.error(for: Self.self, "[Tab \(index)] showing error dialog: \(msg) (\(error)")

		var alert = AlertHelper.build(message: msg)

		if isTLSError, let host = failedUrl.host {
			alert.addAction(AlertHelper.destructiveAction(
				NSLocalizedString("Ignore for this host", comment: ""),
				handler: { _ in
					let hs = HostSettings.for(host)
					hs.ignoreTlsErrors = true
					hs.save().store()

					// Retry the failed request.
					self.load(failedUrl)
				}))
		}

		// This error shows up, when a Onion v3 service needs authentication.
		// Allow the user to enter an authentication key in that case.
		if error.domain == NSURLErrorDomain
			&& (error.code == NSURLErrorNetworkConnectionLost /* iOS 14/15 */ || error.code == NSURLErrorNotConnectedToInternet /* iOS 13 */),
		   let host = failedUrl.host,
		   failedUrl.isOnion
		{
			msg += "\n\n"
			msg += String(format: NSLocalizedString(
				"This site may need authentication. If you received an authentication key for this site, add it to %@!",
				comment: "Placeholder is 'Orbot'"),
						  OrbotKit.orbotName)

			alert = AlertHelper.build(message: msg, actions: [
				AlertHelper.cancelAction(),
				AlertHelper.defaultAction(String(
					format: NSLocalizedString("Add to %@", comment: "Placeholder is 'Orbot'"),
					OrbotKit.orbotName)
				) { [weak self] _ in
					Task {
						await OrbotKit.shared.open(.addAuth(url: host, key: ""))
					}

					let alert2 = AlertHelper.build(
						message: String(
							format: NSLocalizedString(
								"Retry after you added the authentication key to %@.",
								comment: "Placeholder is 'Orbot'"),
							OrbotKit.orbotName),
						actions: [
							AlertHelper.cancelAction(),
							AlertHelper.defaultAction(NSLocalizedString("Retry", comment: ""), handler: { _ in
								Task { @MainActor in
									self?.load(failedUrl)
								}
							})
						])

					self?.tabDelegate?.present(alert2, nil)
				}
			])
		}

		tabDelegate?.present(alert, nil)

		self.webView(webView, didFinish: navigation)
	}
}
