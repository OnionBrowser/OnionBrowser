//
//  Tab+WKDelegates.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 27.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import WebKit

extension Tab: WKUIDelegate, WKNavigationDelegate {

	// WKUIDelegate

	func webViewDidClose(_ webView: WKWebView) {
		AppDelegate.shared?.browsingUi?.removeTab(self)
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
				 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {

		if let controller = AppDelegate.shared?.browsingUi {
			AlertHelper.present(controller, message: message, title: url.host, actions: [
				AlertHelper.defaultAction { _ in
					completionHandler()
				}
			])
		}
		else {
			completionHandler()
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
				 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {

		if let controller = AppDelegate.shared?.browsingUi {
			AlertHelper.present(controller, message: message, title: url.host, actions: [
				AlertHelper.defaultAction { _ in
					completionHandler(true)
				},
				AlertHelper.cancelAction { _ in
					completionHandler(false)
				}
			])
		}
		else {
			completionHandler(false)
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
				 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
				 completionHandler: @escaping (String?) -> Void) {

		if let controller = AppDelegate.shared?.browsingUi {
			let alert = AlertHelper.build(message: prompt, title: url.host)

			AlertHelper.addTextField(alert, placeholder: defaultText)

			alert.addAction(AlertHelper.defaultAction { _ in
				completionHandler(alert.textFields?.first?.text)
			})

			alert.addAction(AlertHelper.cancelAction() { _ in
				completionHandler(nil)
			})

			controller.present(alert)
		}
		else {
			completionHandler(nil)
		}
	}

	// WKNavigationDelegate

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
				 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

		if let url = navigationAction.request.url,
			let blocker = URLBlocker.blockingTarget(for: url, fromMainDocumentURL: self.url) {
			
			self.applicableUrlBlockerTargets[blocker] = true

			return decisionHandler(.cancel)
		}

		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		url = webView.url ?? URL.start

		tabDelegate?.updateChrome()
	}
}
