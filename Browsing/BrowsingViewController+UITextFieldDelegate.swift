//
//  BrowsingViewController+UITextFieldDelegate.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import Foundation

extension BrowsingViewController: UITextFieldDelegate {

	private static let creditsUrl = Bundle.main.url(forResource: "credits", withExtension: "html")
	private static let secureIcon = UIImage(named: "secure")
	private static let insecureIcon = UIImage(named: "insecure")


	// MARK: UITextFieldDelegate

	func textFieldDidBeginEditing(_ textField: UITextField) {
		debug("#textFieldDidBeginEditing")

		updateSearchField()
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let search = searchFl.text

		DispatchQueue.main.async {
			textField.resignFirstResponder()

			// User is shifting to a new place. Probably a good time to clear old data.
			AppDelegate.shared()?.cookieJar.clearAllNonWhitelistedData()

			if let url = self.parseSearch(search) {
				self.debug("#textFieldShouldReturn url=\(url)")

				if let currentTab = self.currentTab {
					currentTab.load(url)
				}
				else {
					self.addNewTab(forURL: url)
				}
			}
			else {
				self.debug("#textFieldShouldReturn search=\(String(describing: search))")

				if self.currentTab == nil {
					self.addNewTab(forURL: nil)
				}

				self.currentTab?.search(for: search)
			}
		}

		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
		debug("#textFieldDidEndEditing")

		updateSearchField()
	}


	// MARK: Public Methods

	/**
	Renders the `searchFl` depending on if it currently has focus.
	*/
	func updateSearchField() {
		if searchFl.isFirstResponder {
			if searchFl.textAlignment == .natural {
				// Seems already set correctly. Don't mess with it, while user
				// edits it actively!
				return
			}

			if currentTab?.url == BrowsingViewController.creditsUrl {
				searchFl.text = ABOUT_ONION_BROWSER
			}
			else {
				searchFl.text = currentTab?.url?.absoluteString
			}

			// .unlessEditing would be such a great state, if it wouldn't show
			// while editing an empty field. Argh.
			searchFl.leftViewMode = .never
			searchFl.rightViewMode = .never

			searchFl.textAlignment = .natural
		}
		else {
			if currentTab?.url == BrowsingViewController.creditsUrl {
				searchFl.text = ABOUT_ONION_BROWSER
			}
			else if currentTab?.url?.absoluteString != BrowsingViewController.blankUrl,
				let host = currentTab?.url?.host {

				searchFl.text = host.replacingOccurrences(of: #"^www\d*\."#, with: "", options: .regularExpression)
			}
			else {
				searchFl.text = currentTab?.url?.absoluteString
			}

			searchFl.leftViewMode = encryptionBt.image(for: .normal) == nil ? .never : .always
			searchFl.rightViewMode = searchFl.text?.isEmpty ?? true ? .never : .always

			searchFl.textAlignment = .center
		}
	}

	/**
	Updates the `encryptionBt`:
	- Show a closed lock icon, when `WebViewTabSecureMode` is `.secure` or `.secureEV`.
	- Show a open lock icon, when mode is `.mixed`.
	- Show no icon, when mode is `.insecure`.
	*/
	func updateEncryptionBt(_ mode: WebViewTabSecureMode) {
		let encryptionIcon: UIImage?

		switch mode {
		case .secure, .secureEV:
			encryptionIcon = BrowsingViewController.secureIcon

		case .mixed:
			encryptionIcon = BrowsingViewController.insecureIcon

		default:
			encryptionIcon = nil
		}

		encryptionBt.setImage(encryptionIcon, for: .normal)
		searchFl.leftViewMode = searchFl.isFirstResponder || encryptionIcon == nil ? .never : .always
	}


	// MARK: Private Methods

	/**
	Parse a user search.

	- parameter search: The user entry, which could be a (semi-)valid URL or a search engine query.
	- returns: A parsed (and fixed) URL or `nil`, in which case you should treat the string as a search engine query.
	*/
	private func parseSearch(_ search: String?) -> URL? {
		// Must not be empty, must not be the explicit blank page.
		if let search = search,
			!search.isEmpty
				&& search.caseInsensitiveCompare(BrowsingViewController.blankUrl) != .orderedSame {

			// If credits page, return that.
			if search.caseInsensitiveCompare(ABOUT_ONION_BROWSER) == .orderedSame {
				return URL(string: ABOUT_ONION_BROWSER)
			}

			if search.range(of: #"\s+"#, options: .regularExpression) != nil
				|| !search.contains(".") {
				// Search contains spaces or contains no dots. That's really a search!
				return nil
			}

			// We rely on URLComponents parsing style! *Don't* change to URL!
			if let urlc = URLComponents(string: search) {
				let scheme = urlc.scheme?.lowercased() ?? ""

				if scheme.isEmpty {
					// Set missing scheme to HTTP.
					return URL(string: "http://\(search)")
				}

				if scheme != "about" && scheme != "file" {
					if urlc.host?.isEmpty ?? true
						&& urlc.path.range(of: #"^\d+"#, options: .regularExpression) != nil {

						// A scheme, no host, path begins with numbers. Seems like "example.com:1234" was parsed wrongly.
						return URL(string: "http://\(search)")
					}

					// User has simply entered a valid URL?!?
					return urlc.url
				}

				// Someone wants to try something here. No way.
			}

			// Unparsable. Return blank page.
		}

		return URL(string: BrowsingViewController.blankUrl)
	}
}
