//
//  Tab+UIWebViewDelegate.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI
import Tor

extension Tab: UIWebViewDelegate {

	/**
	Must match injected.js
	*/
	private static let validParams = ["hash", "hostname", "href", "pathname",
									  "port", "protocol", "search", "username",
									  "password", "origin"]

	private static let universalLinksWorkaroundKey = "yayprivacy"


	/**
	This will only fire for top-level requests (and iframes), not page elements.
	*/
	func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
		guard let url = request.url else {
			return false
		}

		if url.scheme?.lowercased() == "endlessipc" {
			return handleIpc(url, navigationType)
		}

		// Try to prevent universal links from triggering by refusing the initial request and starting a new one.
		let iframe = url.absoluteString != request.mainDocumentURL?.absoluteString

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
			else if (url.scheme?.lowercased().hasPrefix("http") ?? false) && (URLProtocol.property(forKey: Tab.universalLinksWorkaroundKey, in: request) == nil) {
				if let tr = request as? NSMutableURLRequest {
					URLProtocol.setProperty(true, forKey: Tab.universalLinksWorkaroundKey, in: tr)

					print("[Tab \(index)] doing universal link workaround for \(url).")

					load(tr as URLRequest)

					return false
				}
			}
		}
		else {
			print("[Tab \(index)] not doing universal link workaround for \(url) due to HostSettings.")
		}

		if !iframe {
			reset(request.mainDocumentURL)
		}
		cancelDownload()

		return true
	}

	func webViewDidStartLoad(_ webView: UIWebView) {
		progress = 0.1
	}

	func webViewDidFinishLoad(_ webView: UIWebView) {
		progress = 1

		// If we have JavaScript blocked, these will be empty.
		var finalUrl = stringByEvaluatingJavaScript(from: "window.location.href")

		if finalUrl?.isEmpty ?? true {
			finalUrl = webView.request?.mainDocumentURL?.absoluteString
		}

		url = URL(string: finalUrl!) ?? URL.start

		if !skipHistory {
			while history.count > Tab.historySize {
				history.remove(at: 0)
			}

			if history.isEmpty || history.last?.url.absoluteString != finalUrl,
				let cleanUrl = url.clean {

				history.append(HistoryViewController.Item(url: cleanUrl, title: title))
			}
		}

		skipHistory = false
	}

	func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
		if let url = webView.request?.url {
			self.url = url
		}

		progress = 0

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

		if let ok = error.userInfo[ORIGIN_KEY] as? NSNumber,
			!ok.boolValue {

			print("[Tab \(index)] not showing dialog for non-origin error: \(msg) (\(error))")

			return webViewDidFinishLoad(webView)
		}

		print("[Tab \(index)] showing error dialog: \(msg) (\(error)")

		var alert = AlertHelper.build(message: msg)

		// self.url will hold the URL of the UIWebView which is the last
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
			msg += NSLocalizedString("This site may need authentication. If you received an authentication key for this site, please enter it here:", comment: "")

			alert = AlertHelper.build(message: msg, actions: [
				AlertHelper.defaultAction() { _ in
					guard let key = alert.textFields?.first?.text, !key.isEmpty else {
						return
					}

					OnionManager.shared.onionAuth?.set(TorAuthKey(private: key, forDomain: url))

					OnionManager.shared.reloadTor()

					// Retry after 1 second to give Tor some time to load the new auth key!
					DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
						self.load(url)
					}
				}
			])

			AlertHelper.addTextField(alert, placeholder: NSLocalizedString("Onion Service v3 Auth Key", comment: ""))
		}

		tabDelegate?.present(alert, nil)

		webViewDidFinishLoad(webView)
	}


	// MARK: Private Methods

	/**
	Handles all IPC calls from JavaScript.

	Calls look like this: `endlessipc://<action>[/<param1>][/<param2>][?<value>]`

	- parameter URL: The IPC URL
	- parameter navigationType: The navigation type as given by webView:shouldStartLoadWith:navigationType:
	- returns: false always, which can be used as a return for #webView:shouldStartLoadWith:navigationType:, because IPC calls should never allow any further loading.
	*/
	private func handleIpc(_ url: URL, _ navigationType: UIWebView.NavigationType) -> Bool {

		let action = url.host
		let param1 = url.pathComponents.count > 1 ? url.pathComponents[1] : nil
		let param2 = url.pathComponents.count > 2 ? url.pathComponents[2] : nil
		let value = url.query?.replacingOccurrences(of: "+", with: " ").removingPercentEncoding

		if action == "console.log" {
			print("[Tab \(index)] [console.\(param1 ?? "log")] \(value ?? "(nil)")")
			// No callback needed.
			return false
		}

		print("[Tab \(index)] [IPC]: action=\(action ?? "(nil)"), param1=\(param1 ?? "(nil)"), param2=\(param2 ?? "(nil)"), value=\(value ?? "(nil)")")

		switch action {
		case "noop":
			ipcCallback("")

			return false

		case "window.open":
			// Only allow windows to be opened from mouse/touch events, like a normal browser's popup blocker.
			if navigationType == .linkClicked {
				let child = tabDelegate?.addNewTab(nil)
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

			return false

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

			return false

		case "showDonate":
			let navC = AppDelegate.shared?.browsingUi?.showSettings()
			navC?.pushViewController(DonationViewController(), animated: false)

			return false

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

				return false
			}

			switch action {
			case "fakeWindow.setName":
				// Setters, just write into target webview.
				if let value = value?.escapedForJavaScript {
					tab.stringByEvaluatingJavaScript(from: "window.name = \"\(value)\";")
				}

				ipcCallback("")

			case "fakeWindow.setLocation":
				if let value = value?.escapedForJavaScript {
					tab.stringByEvaluatingJavaScript(from: "window.location = \"\(value)\";")
				}

				ipcCallback("")

			case "fakeWindow.setLocationParam":
				if let param2 = param2, Tab.validParams.contains(param2),
					let value = value?.escapedForJavaScript {

					tab.stringByEvaluatingJavaScript(from: "window.location.\(param2) = \"\(value)\";")
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

		return false
	}

	private func ipcCallback(_ payload: String) {
		let callback = "(function() { \(payload) __endless.ipcDone = (new Date()).getTime(); })();"

		print("[Tab \(index)] [IPC]: calling back with: \(callback)")

		stringByEvaluatingJavaScript(from: callback)
	}
}
