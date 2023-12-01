//
//  Tab+WKUIDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 05.08.22.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
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
		let alert = AlertHelper.build(
			message: message,
			title: frame.request.url?.host ?? url.host,
			actions: [
				AlertHelper.defaultAction { _ in
					completionHandler()
				}
			])

		guard tabDelegate?.present(alert, nil) ?? false else {
			return completionHandler()
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
				 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void)
	{
		let alert = AlertHelper.build(
			message: message,
			title: frame.request.url?.host ?? url.host,
			actions: [
				AlertHelper.defaultAction { _ in
					completionHandler(true)
				},
				AlertHelper.cancelAction { _ in
					completionHandler(false)
				}
			])

		guard tabDelegate?.present(alert, nil) ?? false else {
			return completionHandler(false)
		}
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
				 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
				 completionHandler: @escaping (String?) -> Void)
	{
		let alert = AlertHelper.build(
			message: prompt,
			title: frame.request.url?.host ?? url.host,
			actions: [
				AlertHelper.cancelAction() { _ in
					completionHandler(nil)
				}
			])

		AlertHelper.addTextField(alert, placeholder: defaultText)

		alert.addAction(AlertHelper.defaultAction { _ in
			completionHandler(alert.textFields?.first?.text)
		})

		guard tabDelegate?.present(alert, nil) ?? false else {
			return completionHandler(nil)
		}
	}

	func webView(_ webView: WKWebView, contextMenuConfigurationForElement
				 elementInfo: WKContextMenuElementInfo,
				 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void)
	{
		guard let url = elementInfo.linkURL else {
			return completionHandler(nil)
		}

		completionHandler(UIContextMenuConfiguration(
			identifier: nil,
			previewProvider: {
				let vc = UIViewController()

				let label = UILabel()
				label.translatesAutoresizingMaskIntoConstraints = false
				label.text = url.host
				label.font = .preferredFont(forTextStyle: .caption1)
				label.textColor = .systemGray

				vc.view.addSubview(label)
				label.topAnchor.constraint(equalTo: vc.view.topAnchor, constant: 16).isActive = true
				label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 16).isActive = true
				label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16).isActive = true

				let webView = WKWebView(frame: .zero, configuration: webView.configuration)
				webView.translatesAutoresizingMaskIntoConstraints = false
				webView.load(URLRequest(url: url))

				vc.view.addSubview(webView)
				webView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 16).isActive = true
				webView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor).isActive = true
				webView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor).isActive = true
				webView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor).isActive = true

				return vc
			},
			actionProvider: { (elements: [UIMenuElement]) -> UIMenu? in
				var elements = elements

				elements.insert(UIAction(
					title: NSLocalizedString("Open in a New Tab", comment: ""),
					image: UIImage(systemName: "plus.square.on.square"),
					handler: { _ in
						let child = self.tabDelegate?.addNewTab(url, configuration: nil)
						child?.parentId = self.hash
					}), at: 1)

				elements.insert(UIAction(
					title: NSLocalizedString("Open in Background Tab", comment: ""),
					image: UIImage(systemName: "rectangle.stack.badge.plus"),
					handler: { _ in
						let child = self.tabDelegate?.addNewTab(
							url, transition: .inBackground,
							configuration: nil, completion: nil)
						child?.parentId = self.hash
					}), at: 2)

				elements.insert(UIAction(
					title: NSLocalizedString("Open in Default Browser", comment: ""),
					image: UIImage(systemName: "arrow.up.forward.app"),
					handler: { _ in
						UIApplication.shared.open(url)
					}), at: 3)

				return UIMenu(title: "", children: elements)
			}))
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
