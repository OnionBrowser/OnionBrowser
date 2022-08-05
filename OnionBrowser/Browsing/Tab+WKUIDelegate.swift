//
//  Tab+WKUIDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 05.08.22.
//  Copyright (c) 2012-2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import WebKit

extension Tab: WKUIDelegate {

	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
				 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView?
	{
		return tabDelegate?.addNewTab(navigationAction.request.mainDocumentURL, configuration: configuration)?.webView
	}

	func webViewDidClose(_ webView: WKWebView) {
		tabDelegate?.removeTab(self, focus: nil)
	}

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
				 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void)
	{
		if let tabDelegate = tabDelegate {
			let alert = AlertHelper.build(message: message, title: url.host, actions: [
				AlertHelper.defaultAction { _ in
					completionHandler()
				}
			])

			tabDelegate.present(alert, nil)
		}
		else {
			completionHandler()
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
				 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void)
	{
		if let tabDelegate = tabDelegate {
			let alert = AlertHelper.build(message: message, title: url.host, actions: [
				AlertHelper.defaultAction { _ in
					completionHandler(true)
				},
				AlertHelper.cancelAction { _ in
					completionHandler(false)
				}
			])

			tabDelegate.present(alert, nil)
		}
		else {
			completionHandler(false)
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
				 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
				 completionHandler: @escaping (String?) -> Void)
	{
		if let tabDelegate = tabDelegate {
			let alert = AlertHelper.build(
				message: prompt,
				title: url.host,
				actions: [
					AlertHelper.cancelAction() { _ in
						completionHandler(nil)
					}
				])

			AlertHelper.addTextField(alert, placeholder: defaultText)

			alert.addAction(AlertHelper.defaultAction { _ in
				completionHandler(alert.textFields?.first?.text)
			})

			tabDelegate.present(alert, nil)
		}
		else {
			completionHandler(nil)
		}
	}

	func webView(_ webView: WKWebView, contextMenuConfigurationForElement
				 elementInfo: WKContextMenuElementInfo,
				 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void)
	{
		// TODO
	}

	func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo,
				 willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating)
	{
		// TODO
	}

	func webView(_ webView: WKWebView, contextMenuDidEndForElement elementInfo: WKContextMenuElementInfo)
	{
		// TODO
	}

	func webView(_ webView: WKWebView, requestDeviceOrientationAndMotionPermissionFor origin: WKSecurityOrigin,
				 initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void)
	{
		decisionHandler(HostSettings.for(origin.host).orientationAndMotion ? .prompt : .deny)
	}

	func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
				 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
				 decisionHandler: @escaping (WKPermissionDecision) -> Void)
	{
		decisionHandler(HostSettings.for(origin.host).mediaCapture ? .prompt : .deny)
	}
}
