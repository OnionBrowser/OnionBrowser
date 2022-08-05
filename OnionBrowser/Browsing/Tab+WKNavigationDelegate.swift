//
//  Tab+WKNavigationDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 27.07.22.
//  Copyright (c) 2012-2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import WebKit
import OrbotKit

extension Tab: WKNavigationDelegate {

	/**
	Must match injected.js
	*/
	private static let validParams = ["hash", "hostname", "href", "pathname",
									  "port", "protocol", "search", "username",
									  "password", "origin"]

	private static let universalLinksWorkaroundKey = "yayprivacy"


	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
				 preferences: WKWebpagePreferences,
				 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void)
	{
		guard let url = navigationAction.request.url else {
			return decisionHandler(.cancel, preferences)
		}

		if let blocker = URLBlocker.blockingTarget(for: url, fromMainDocumentURL: self.url) {

			self.applicableUrlBlockerTargets[blocker] = true

			return decisionHandler(.cancel, preferences)
		}

		let navigationType = navigationAction.navigationType

		if url.scheme?.lowercased() == "endlessipc" {
			handleIpc(url, navigationType)

			return decisionHandler(.cancel, preferences)
		}

		// Try to prevent universal links from triggering by refusing the initial request and starting a new one.
		let iframe = url.absoluteString != navigationAction.request.mainDocumentURL?.absoluteString

		if HostSettings.for(url.host).universalLinkProtection {
			if iframe {
				print("[Tab \(index)] not doing universal link workaround for iframe \(url).")
			}
			else if navigationType == .backForward {
				print("[Tab \(index)] not doing universal link workaround for back/forward navigation to \(url).")
			}
			else if navigationType == .formSubmitted {
				print("[Tab \(index)] not doing universal link workaround for form submission to \(url).")
			}
			else if (url.scheme?.lowercased().hasPrefix("http") ?? false) && (URLProtocol.property(forKey: Tab.universalLinksWorkaroundKey, in: navigationAction.request) == nil) {
				if let tr = navigationAction.request as? NSMutableURLRequest {
					URLProtocol.setProperty(true, forKey: Tab.universalLinksWorkaroundKey, in: tr)

					print("[Tab \(index)] doing universal link workaround for \(url).")

					load(tr as URLRequest)

					return decisionHandler(.cancel, preferences)
				}
			}
		}
		else {
			print("[Tab \(index)] not doing universal link workaround for \(url) due to HostSettings.")
		}

		if !iframe {
			reset(navigationAction.request.mainDocumentURL)
		}

		preferences.allowsContentJavaScript = HostSettings.for(url.host).javaScript

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
		if !(url?.host?.lowercased().hasSuffix(".onion") ?? false)
			&& url?.scheme?.lowercased() == "https"
			&& HostSettings.for(url?.host).followOnionLocationHeader,
		   let headers = (navigationResponse.response as? HTTPURLResponse)?.allHeaderFields,
		   let olHeader = headers.first(where: { ($0.key as? String)?.lowercased() == "onion-location" })?.value as? String,
		   let onionLocation = URL(string: olHeader),
		   ["http", "https"].contains(onionLocation.scheme?.lowercased())
			&& onionLocation.host?.lowercased().hasSuffix(".onion") ?? false
		{
			print("[\(String(describing: type(of: self)))] Redirect to Onion-Location=\(onionLocation.absoluteString)")

			decisionHandler(.cancel)

			DispatchQueue.main.async { [weak self] in
				self?.load(onionLocation)
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
		// If we have JavaScript blocked, these will be empty.
		stringByEvaluatingJavaScript(from: "window.location.href") { [weak self] (finalUrl) in
			var finalUrl = finalUrl

			if finalUrl?.isEmpty ?? true {
				finalUrl = webView.url?.absoluteString
			}

			self?.url = URL(string: finalUrl ?? URL.start.absoluteString) ?? URL.start

			if !(self?.skipHistory ?? true) {
				while self?.history.count ?? 0 > Tab.historySize {
					self?.history.remove(at: 0)
				}

				if self?.history.isEmpty ?? true || self?.history.last?.url.absoluteString != finalUrl,
				   let cleanUrl = self?.url.clean
				{
					self?.history.append(HistoryViewController.Item(url: cleanUrl, title: self?.title))
				}
			}

			self?.skipHistory = false
		}
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
		handle(error: error, navigation)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
		handle(error: error, navigation)
	}

	func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
				 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
	{
		let space = challenge.protectionSpace

		switch space.authenticationMethod {
		case NSURLAuthenticationMethodServerTrust:
			if let serverTrust = space.serverTrust,
			   HostSettings.for(space.host).ignoreTlsErrors
			{
				completionHandler(.useCredential, URLCredential(trust: serverTrust))
			}
			else {
				completionHandler(.performDefaultHandling, nil)
			}

			if let trust = challenge.protectionSpace.serverTrust {
				tlsCertificate = SSLCertificate(secTrustRef: trust)
			}

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

				DispatchQueue.main.async { [weak self] in
					self?.tabDelegate?.present(alert, nil)
				}
			}

		default:
			completionHandler(.performDefaultHandling, nil)
		}
	}

	// TODO
//	func webView(_ webView: WKWebView, authenticationChallenge challenge: URLAuthenticationChallenge,
//				 shouldAllowDeprecatedTLS decisionHandler: @escaping (Bool) -> Void)
//	{
//		// TODO
//	}


	// MARK: Private Methods

	private func handle(error: Error, _ navigation: WKNavigation?) {
		if let url = webView.url {
			self.url = url
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

		let url = error.userInfo[NSURLErrorFailingURLStringErrorKey] as? String

		if let url = url {
			msg += "\n\n\(url)"
		}

		print("[Tab \(index)] showing error dialog: \(msg) (\(error)")

		var alert = AlertHelper.build(message: msg)

		// self.url will hold the URL of the WKWebView which is the last
		// *successful* request.
		// We need the URL of the *failed* request, which should be in
		// `error`'s `userInfo` dictionary.
		if isTLSError, let u = url, let url = URL(string: u), let host = url.host {
			alert.addAction(AlertHelper.destructiveAction(
				NSLocalizedString("Ignore for this host", comment: ""),
				handler: { _ in
					let hs = HostSettings.for(host)
					hs.ignoreTlsErrors = true
					hs.save().store()

					// Retry the failed request.
					self.load(url)
				}))
		}

		// This error shows up, when a Onion v3 service needs authentication.
		// Allow the user to enter an authentication key in that case.
		if error.domain == NSURLErrorDomain
			&& (error.code == NSURLErrorNetworkConnectionLost /* iOS 14/15 */ || error.code == NSURLErrorNotConnectedToInternet /* iOS 13 */),
			let u = url, let url = URL(string: u), let host = url.host,
		   host.lowercased().hasSuffix(".onion")
		{
			msg += "\n\n"
			msg += NSLocalizedString("This site may need authentication. If you received an authentication key for this site, add it to Orbot!", comment: "")

			alert = AlertHelper.build(message: msg, actions: [
				AlertHelper.cancelAction(),
				AlertHelper.defaultAction(NSLocalizedString("Add to Orbot", comment: "")) { [weak self] _ in
					OrbotKit.shared.open(.addAuth(url: host, key: ""))

					let alert2 = AlertHelper.build(
						message: NSLocalizedString("Retry after you added the authentication key to Orbot.", comment: ""),
						actions: [
							AlertHelper.cancelAction(),
							AlertHelper.defaultAction(NSLocalizedString("Retry", comment: ""), handler: { _ in
								DispatchQueue.main.async {
									self?.load(url)
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

	/**
	Handles all IPC calls from JavaScript.

	Calls look like this: `endlessipc://<action>[/<param1>][/<param2>][?<value>]`

	- parameter URL: The IPC URL
	- parameter navigationType: The navigation type as given by webView:shouldStartLoadWith:navigationType:
	*/
	private func handleIpc(_ url: URL, _ navigationType: WKNavigationType) {

		let action = url.host
		let param1 = url.pathComponents.count > 1 ? url.pathComponents[1] : nil
		let param2 = url.pathComponents.count > 2 ? url.pathComponents[2] : nil
		let value = url.query?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding

		if action == "console.log" {
			print("[Tab \(index)] [console.\(param1 ?? "log")] \(value ?? "(nil)")")
			// No callback needed.
			return
		}

		print("[Tab \(index)] [IPC]: action=\(action ?? "(nil)"), param1=\(param1 ?? "(nil)"), param2=\(param2 ?? "(nil)"), value=\(value ?? "(nil)")")

		switch action {
		case "noop":
			ipcCallback("")

			return

		case "window.open":
			// Only allow windows to be opened from mouse/touch events, like a normal browser's popup blocker.
			if navigationType == .linkActivated {
				let child = tabDelegate?.addNewTab(nil, configuration: nil)
				child?.parentId = hash
				child?.ipcId = param1

				if let param1 = param1?.escapedForJavaScript {
					ipcCallback("__endless.openedTabs[\"\(param1)\"].opened = true;")
				}
				else {
					ipcCallback("")
				}
			}
			else {
				// TODO: Show a "popup blocked" warning?
				print("[Tab \(index)] blocked non-touch window.open() (nav type \(navigationType))");

				if let param1 = param1?.escapedForJavaScript {
					ipcCallback("__endless.openedTabs[\"\(param1)\"].opened = false;")
				}
				else {
					ipcCallback("")
				}
			}

			return

		case "window.close":
			let alert = AlertHelper.build(
				message: NSLocalizedString("Allow this page to close its tab?", comment: ""),
				title: NSLocalizedString("Confirm", comment: ""),
				actions: [
					AlertHelper.defaultAction(handler: { _ in self.tabDelegate?.removeTab(self, focus: nil) }),
					AlertHelper.cancelAction()
			])

			tabDelegate?.present(alert, nil)

			ipcCallback("")

			return

		case "showDonate":
			let navC = AppDelegate.shared?.browsingUi?.showSettings()
			navC?.pushViewController(DonationViewController(), animated: false)

			return

		default:
			break
		}

		if action?.hasPrefix("fakeWindow.") ?? false {
			guard let tab = tabDelegate?.getTab(ipcId: param1) else {
				if let param1 = param1?.escapedForJavaScript {
					ipcCallback("delete __endless.openedTabs[\"\(param1)\"];")
				}
				else {
					ipcCallback("")
				}

				return
			}

			switch action {
			case "fakeWindow.setName":
				// Setters, just write into target webview.
				if let value = value?.escapedForJavaScript {
					tab.stringByEvaluatingJavaScript(from: "window.name = \"\(value)\";") { _ in }
				}

				ipcCallback("")

			case "fakeWindow.setLocation":
				if let value = value?.escapedForJavaScript {
					tab.stringByEvaluatingJavaScript(from: "window.location = \"\(value)\";") { _ in }
				}

				ipcCallback("")

			case "fakeWindow.setLocationParam":
				if let param2 = param2, Tab.validParams.contains(param2),
					let value = value?.escapedForJavaScript {

					tab.stringByEvaluatingJavaScript(from: "window.location.\(param2) = \"\(value)\";") { _ in }
				}
				else {
					print("[Tab \(index)] window.\(param2 ?? "(nil)") not implemented");
				}

				ipcCallback("")

			case "fakeWindow.close":
				tabDelegate?.removeTab(tab, focus: nil)

				ipcCallback("")

			default:
				break
			}
		}

		return
	}

	private func ipcCallback(_ payload: String) {
		let callback = "(function() { \(payload) __endless.ipcDone = (new Date()).getTime(); })();"

		print("[Tab \(index)] [IPC]: calling back with: \(callback)")

		stringByEvaluatingJavaScript(from: callback) { _ in }
	}
}
