//
//  BrowsingViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 29.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

@objcMembers
class BrowsingViewController: UIViewController, UITextFieldDelegate, UIScrollViewDelegate {

	static let blankUrl = "about:blank"

    @IBOutlet weak var addressBar: UIView!
    @IBOutlet weak var securityBt: UIButton!
    @IBOutlet weak var encryptionBt: UIButton!
    @IBOutlet weak var addressFl: UITextField!
    @IBOutlet weak var reloadBt: UIButton!
    @IBOutlet weak var torBt: UIButton!

    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var containerBottomConstraint2Toolbar: NSLayoutConstraint!

    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var backBt: UIBarButtonItem!
    @IBOutlet weak var frwrdBt: UIBarButtonItem!
    @IBOutlet weak var actionBt: UIBarButtonItem!
    @IBOutlet weak var bookmarksBt: UIBarButtonItem!
    @IBOutlet weak var tabsBt: UIBarButtonItem!
    @IBOutlet weak var settingsBt: UIBarButtonItem!

	private(set) var tabs = [WebViewTab]()

	private var currentTabIndex = -1

	private var currentTab: WebViewTab? {
		return currentTabIndex < 0 || currentTabIndex >= tabs.count ? nil : tabs[currentTabIndex]
	}

	private lazy var toolbarHeight = toolbar.bounds.height

	private lazy var toolbarHeightConstraint: NSLayoutConstraint = {
		let constrain = toolbar.heightAnchor.constraint(equalToConstant: toolbarHeight)

		constrain.isActive = true

		return constrain
	}()

    private lazy var containerBottomConstraint2Superview: NSLayoutConstraint
        = container.bottomAnchor.constraint(equalTo: view.bottomAnchor)

    override func viewDidLoad() {
        super.viewDidLoad()

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			attach(webView: tab.webView)
		}

		updateChrome()
	}

	private lazy var insecureIcon = UIImage(named: "insecure")
	private lazy var secureIcon = UIImage(named: "secure")


    // MARK: Actions
    @IBAction func addressbarAction(_ sender: UIButton) {
        switch sender {
        case securityBt:
            break

        case encryptionBt:
			guard let certificate = currentTab?.sslCertificate,
				let vc = SSLCertificateViewController(sslCertificate: certificate) else {

				return
			}

			vc.title = currentTab?.url.host

			let navC = UINavigationController(rootViewController: vc)
			navC.modalPresentationStyle = .popover
			navC.popoverPresentationController?.sourceView = sender.superview
			navC.popoverPresentationController?.sourceRect = sender.frame

			present(navC, animated: true)

        case reloadBt:
            currentTab?.refresh()

        default:
            break
        }
    }

    @IBAction func toolbarAction(_ sender: UIBarButtonItem) {
        switch sender {
        case backBt:
			currentTab?.goBack()

        case frwrdBt:
			currentTab?.goForward()

        case actionBt:
			guard let currentTab = currentTab else {
				return
			}

			let avc = UIActivityViewController(activityItems: [currentTab],
											   applicationActivities: [TUSafariActivity()])

			avc.popoverPresentationController?.barButtonItem = sender

			present(avc, animated: true)

        case bookmarksBt:
            let vc = BookmarksViewController.instantiate()
            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.barButtonItem = sender

            present(vc, animated: true)

        case tabsBt:
            break

        default:
            let vc = SettingsViewController.instantiate()
            vc.modalPresentationStyle = .popover
            vc.popoverPresentationController?.barButtonItem = sender

            present(vc, animated: true)
        }
    }


	// MARK: UITextFieldDelegate

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()

		var url = URL(string: addressFl.text ?? BrowsingViewController.blankUrl) ?? URL(string: BrowsingViewController.blankUrl)!

		// Scheme defaults to "file". That's something, we definitely don't want here.
		if url.scheme?.lowercased() != "http" || url.scheme?.lowercased() != "https" {
			var urlc = URLComponents(url: url, resolvingAgainstBaseURL: true)
			urlc?.scheme = "http"
			url = urlc?.url ?? url
		}

		debug("#textFieldShouldReturn url=\(url)")

		if let currentTab = currentTab {
			currentTab.load(url)
		}
		else {
			addNewTab(forURL: url)
		}

		return true
	}


	// MARK: UIScrollViewDelegate

	func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		showToolbar()
	}

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let velocity = scrollView.panGestureRecognizer.velocity(in: scrollView).y

		if velocity == 0 {
			return
		}

		showToolbar(velocity > 0)
	}


	// MARK: Old WebViewController interface

	func viewIsVisible() {
		debug("#viewIsVisible")

		if tabs.count < 1 {
			addNewTab(forURL: URL(string: "http://3heens4xbedlj57xwcggjsdglot7e36p4rogy642xokemfo2duh6bbyd.onion/"))
		}
	}

	func viewIsNoLongerVisible() {
		debug("#viewIsNoLongerVisible")

		if addressFl.isFirstResponder {
			addressFl.resignFirstResponder()
		}
	}

	func webViewTabs() -> [WebViewTab] {
		debug("#webViewTabs")

		return tabs
	}

    @discardableResult
	func addNewTab(forURL url: URL?) -> WebViewTab? {
		debug("#addNewTabForURL url=\(String(describing: url))")

		return addNewTab(for: url, forRestoration: false, with: .default, withCompletionBlock: nil)
	}

	@discardableResult
	@objc(addNewTabForURL:forRestoration:withAnimation:withCompletionBlock:)
	func addNewTab(for url: URL?, forRestoration restoration: Bool,
				   with animation: WebViewTabAnimation, withCompletionBlock completion: ((Bool) -> Void)?) -> WebViewTab? {

		debug("#addNewTab url=\(String(describing: url)), restoration=\(restoration), animation=\(animation), completion=\(String(describing: completion))")

		let tab = WebViewTab(frame: .zero, withRestorationIdentifier: restoration ? url?.absoluteString : nil)

		if let tab = tab {
			tab.load(url)

			tabs.append(tab)
            currentTabIndex = tabs.firstIndex(of: tab) ?? -1

			for otherTab in tabs {
				otherTab.webView.isHidden = otherTab != tab
			}

			tab.webView.translatesAutoresizingMaskIntoConstraints = false
			tab.webView.scrollView.delegate = self

			attach(webView: tab.webView)
		}

		updateChrome()

		completion?(true)

		return tab
	}

	func addNewTabFromToolbar(_ toolbar: Any?) {
		debug("#addNewTabFromToolbar toolbar=\(String(describing: toolbar))")
	}

	func switchToTab(_ tabNumber: NSNumber) {
		debug("#switchToTab tabNumber=\(tabNumber)")

		let index = tabNumber.intValue

		if index < 0 || index >= tabs.count {
			return
		}

		let focussing = tabs[index]

		for tab in tabs {
			tab.webView.isHidden = tab != focussing
		}

		updateChrome()
	}

	func removeTab(_ tabNumber: NSNumber) {
		debug("#removeTab tabNumber=\(tabNumber)")

		removeTab(tabNumber, andFocusTab: nil)
	}

	func removeTab(_ tabNumber: NSNumber, andFocusTab toFocus: NSNumber? = nil) {
		debug("#removeTab tabNumber=\(tabNumber) toFocus=\(String(describing: toFocus))")

		let rIdx = tabNumber.intValue
		let removing = rIdx > -1 && rIdx < tabs.count ? tabs[rIdx] : nil
		let fIdx = toFocus?.intValue
		let focussing = fIdx != nil && fIdx! > -1 && fIdx! < tabs.count ? tabs[fIdx!] : nil

		if let removing = removing {
			(focussing ?? tabs.last)?.webView.isHidden = false
			removing.webView.removeFromSuperview()
			tabs.remove(at: rIdx)

			updateChrome()
		}
		else if focussing != nil {
			switchToTab(toFocus!)
		}
	}

	func removeAllTabs() {
		debug("#removeAllTabs")

		for tab in tabs {
			tab.webView.removeFromSuperview()
		}

		tabs.removeAll()
	}

	func curWebViewTab() -> WebViewTab? {
		debug("#curWebViewTab")

		return currentTab
	}

	func showBookmarks() {
		debug("#showBookmarks")
	}

	func hideBookmarks() {
		debug("#hideBookmarks")
	}

	func hideSearchResults() {
		debug("#hideSearchResults")
	}

	@objc(prepareForNewURLFromString:)
	func prepareForNewUrl(from string: String) {
		debug("#prepareForNewURL string=\(string)")
	}

	func focusUrlField() {
		debug("#focusUrlField")

		addressFl.becomeFirstResponder()
	}

	func unfocusUrlField() {
		debug("#unfocusUrlField")

		addressFl.resignFirstResponder()
	}

	func dismissPopover() {
		debug("#dismissPopover")
	}

	func forceRefresh() {
		debug("#forceRefresh")
	}

	func settingsButton() -> UIView? {
		debug("#settingsButton")

		return nil
	}

	func updateProgress() {
		debug("#updateProgress")

		if let progress = progress {
			progress.progress = currentTab?.progress.floatValue ?? 1

			if progress.progress >= 1 {
				if !progress.isHidden {
					UIView.transition(with: view, duration: 0.25,
									  options: .transitionCrossDissolve,
									  animations: { progress.isHidden = true })
				}
			}
			else {
				if progress.isHidden {
					UIView.transition(with: view, duration: 0.25,
									  options: .transitionCrossDissolve,
									  animations: { progress.isHidden = false })
				}
			}
		}

		updateChrome()
	}

	func webViewTouched() {
		debug("#webViewTouched")

        if addressFl.isFirstResponder {
            addressFl.resignFirstResponder()
        }
	}


	// MARK: Private Methods

	private func debug(_ msg: String) {
		print("[\(String(describing: type(of: self)))] \(msg)")
	}

    private func showToolbar(_ show: Bool = true, _ animated: Bool = true) {
		if show != toolbar.isHidden {
			return
		}

        if show {
            toolbar.isHidden = false
			toolbarHeightConstraint.constant = toolbarHeight
			containerBottomConstraint2Superview.isActive = false

			// This goes away when deactivated for an unkown reason.
			if containerBottomConstraint2Toolbar == nil {
				containerBottomConstraint2Toolbar = container.bottomAnchor.constraint(equalTo: toolbar.topAnchor)
			}

			containerBottomConstraint2Toolbar?.isActive = true

			if animated {
				UIView.animate(withDuration: 0.25) {
					self.view.layoutIfNeeded()
				}
			}
        }
        else {
            toolbarHeightConstraint.constant = 0

			 // This goes away when deactivated for an unkown reason.
            containerBottomConstraint2Toolbar?.isActive = false

			containerBottomConstraint2Superview.isActive = true

			if animated {
				UIView.animate(withDuration: 0.25,
							   animations: { self.view.layoutIfNeeded() })
				{ _ in
					// Need to delay this a little, otherwise animation isn't seen,
					// because isHidden becomes in effect before the animation,
					// regardless, if we only do this in the completed callback.
					DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
						self.toolbar.isHidden = true
					}
				}
			}
			else {
				toolbar.isHidden = true
			}
		}
    }

	private func attach(webView: UIWebView) {
		if let container = container {
			container.addSubview(webView)
			webView.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
			webView.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true
			webView.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
			webView.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
		}
	}

	private func updateChrome() {
		// The last non-hidden is the one which is on top.
		guard let tab = tabs.last(where: { !$0.webView.isHidden }) else {
			securityBt.setTitle(nil, for: .normal)
			encryptionBt.isHidden = true
			reloadBt.isEnabled = false
			torBt.isEnabled = false
			backBt.isEnabled = false
			frwrdBt.isEnabled = false
			actionBt.isEnabled = false

			return
		}

		if !addressFl.isFirstResponder {
			addressFl.text = tab.url.absoluteString
		}

		let securityId: String

		switch SecurityPreset(HostSettings(orDefaultsForHost: tab.url.host)) {

		case .insecure:
			securityId = "1"

		case .medium:
			securityId = "2"

		case .secure:
			securityId = "3"

		default:
			securityId = SecurityPreset.custom.description.first?.uppercased() ?? "C"
		}

		let encryptionIcon: UIImage?

		switch tab.secureMode {
		case .secure, .secureEV:
			encryptionIcon = secureIcon

		default:
			encryptionIcon = insecureIcon
		}

		securityBt.setTitle(securityId, for: .normal)
		encryptionBt.setImage(encryptionIcon, for: .normal)
		encryptionBt.isHidden = false
		reloadBt.isEnabled = true
		torBt.isEnabled = false
		backBt.isEnabled = tab.canGoBack()
		frwrdBt.isEnabled = tab.canGoForward()
		actionBt.isEnabled = true
	}
}
