//
//  Tab+WKScriptMessageHandler.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 08.08.22.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import WebKit

extension Tab: WKScriptMessageHandler {

	private static let errorScript = """
		window.onerror = function(msg, url, line) {
			window.webkit.messageHandlers.error.postMessage({
				"msg": msg,
				"url": url,
				"line": line
			});
		};
	"""

	private static let logScript = """
		(function() {
			let old = {};

			let appLog = function(severity, args) {
				window.webkit.messageHandlers.log.postMessage({
					"severity": severity,
					"arguments": (args.length < 2) ? args[0] : Array.from(args)
				});
			};

			["log", "debug", "info", "warn", "error"].forEach(function(fn) {
				old[fn] = console[fn];

				console[fn] = function() {
					old[fn].apply(null, arguments);

					appLog(fn, arguments);
				};
			});
		})();
	"""

	private static let donateScript = """
		window.showDonate = function() {
			window.webkit.messageHandlers.showDonate.postMessage(null);
		};
	"""

	private static let gpcScript = """
		navigator.globalPrivacyControl = true;
	"""


	func setupJsInjections(_ configuration: WKWebViewConfiguration) {
		// Disabled for now. One or both of these seem to cause random crashes.
//		register(script: Self.errorScript, for: "error", in: configuration)
//		register(script: Self.logScript, for: "log", in: configuration)
		register(script: Self.donateScript, for: "showDonate", forMainFrameOnly: true, in: configuration)

		if Settings.sendGpc {
			register(script: Self.gpcScript, in: configuration)
		}
	}


	// MARK: WKScriptMessageHandlerWithReply

	func userContentController(_ userContentController: WKUserContentController,
							   didReceive message: WKScriptMessage)
	{
		switch message.name {
		case "error":
			let args = message.body as? NSDictionary

			print("[Tab \(index)] error in \"\(args?["url"] ?? "(nil)")\" on line \(args?["line"] ?? "-1"): \(args?["msg"] ?? "(no message)")")

		case "log":
			let args = message.body as? NSDictionary

			print("[Tab \(index)] [\(args?["severity"] as? String ?? "log")] \(args?["arguments"] ?? "(nil)")")

		case "showDonate":
			let navC = sceneDelegate?.browsingUi.showSettings()
			navC?.pushViewController(DonationViewController(), animated: false)

		default:
			break
		}
	}


	// MARK: Private Methods

	private func register(script: String, for name: String? = nil, forMainFrameOnly: Bool = false, in configuration: WKWebViewConfiguration) {
		Thread.performOnMain(async: true) {
			configuration.userContentController.addUserScript(WKUserScript(
				source: script, injectionTime: .atDocumentStart, forMainFrameOnly: forMainFrameOnly))

			if let name = name {
				configuration.userContentController.add(self, name: name)
			}
		}
	}
}
