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
class BrowsingViewController: UIViewController {

	static let blankUrl = "about:blank"

    @IBOutlet weak var searchBar: UIView!
    @IBOutlet weak var searchBarHeightConstraint: NSLayoutConstraint! {
        didSet {
            searchBarHeight = searchBarHeightConstraint.constant
        }
    }
    @IBOutlet weak var securityBt: UIButton!
	@IBOutlet weak var searchFl: UITextField! {
		didSet {
			searchFl.leftView = encryptionBt
			searchFl.rightView = reloadBt
		}
	}

	lazy var encryptionBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		return button
	}()

	private lazy var reloadBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
		button.setImage(UIImage(named: "reload"), for: .normal)

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		return button
	}()

    @IBOutlet weak var torBt: UIButton! {
        didSet {
            torBt.addTarget(self, action: #selector(showBridgeSelection), for: .touchUpInside)
        }
    }
    @IBOutlet weak var progress: UIProgressView!
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var containerBottomConstraint2Toolbar: NSLayoutConstraint!

	@IBOutlet weak var tabsCollection: UICollectionView! {
		didSet {
			tabsCollection.dragInteractionEnabled = true
		}
	}

    @IBOutlet weak var toolbar: UIView!
    @IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint! {
        didSet {
            toolbarHeight = toolbarHeightConstraint.constant
        }
    }
    @IBOutlet weak var mainTools: UIStackView!
    @IBOutlet weak var tabsTools: UIView!
    @IBOutlet weak var backBt: UIButton!
    @IBOutlet weak var frwrdBt: UIButton!
    @IBOutlet weak var actionBt: UIButton!
    @IBOutlet weak var bookmarksBt: UIButton!
	@IBOutlet weak var tabsBt: UIButton! {
		didSet {
			tabsBt.setTitleColor(tabsBt.tintColor, for: .normal)

			tabsBt.addTarget(self, action: #selector(showAllTabs), for: .touchUpInside)
		}
	}
    @IBOutlet weak var settingsBt: UIButton!
	@IBOutlet weak var addNewTabBt: UIButton! {
		didSet {
			addNewTabBt.addTarget(self, action: #selector(newTab), for: .touchUpInside)
		}
	}
	@IBOutlet weak var hideTabsBt: UIButton! {
		didSet {
			hideTabsBt.addTarget(self, action: #selector(hideTabs), for: .touchUpInside)
		}
	}

	var tabs = [WebViewTab]()

	private var currentTabIndex = -1
	var currentTab: WebViewTab? {
		get {
			return currentTabIndex < 0 || currentTabIndex >= tabs.count ? tabs.last : tabs[currentTabIndex]
		}
		set {
			if let tab = newValue {
				currentTabIndex = tabs.firstIndex(of: tab) ?? -1
			}
			else {
				currentTabIndex = -1
			}
		}
	}

    var searchBarHeight: CGFloat!
    var toolbarHeight: CGFloat!

    lazy var containerBottomConstraint2Superview: NSLayoutConstraint
        = container.bottomAnchor.constraint(equalTo: view.bottomAnchor)

    override func viewDidLoad() {
        super.viewDidLoad()

        tabsCollection.register(TabCell.nib, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			tab.webView.add(to: container)
		}

		updateChrome()
	}


    // MARK: Actions

	@IBAction func action(_ sender: UIButton) {
        switch sender {
        case securityBt:
			// TODO: What to implement here?
            break

        case encryptionBt:
			guard let certificate = currentTab?.sslCertificate,
				let vc = SSLCertificateViewController(sslCertificate: certificate) else {

				return
			}

			vc.title = currentTab?.url.host
			present(UINavigationController(rootViewController: vc), sender)

        case reloadBt:
            currentTab?.refresh()

        case backBt:
			currentTab?.goBack()

        case frwrdBt:
			currentTab?.goForward()

        case actionBt:
			guard let currentTab = currentTab else {
				return
			}

			present(UIActivityViewController(activityItems: [currentTab],
                                             applicationActivities: [TUSafariActivity()]),
                    sender)

		case tabsBt:
			break

        case bookmarksBt:
            present(BookmarksViewController.instantiate(), sender)

        case settingsBt:
            present(SettingsViewController.instantiate(), sender)

		default:
            break
        }
    }


	// MARK: Old WebViewController interface

	func viewIsVisible() {
		debug("#viewIsVisible")

		if tabs.count < 1 {
			addNewTab(forURL: URL(string: "https://www.golem.de/")) //"http://3heens4xbedlj57xwcggjsdglot7e36p4rogy642xokemfo2duh6bbyd.onion/"))
		}
	}

	func viewIsNoLongerVisible() {
		debug("#viewIsNoLongerVisible")

		if searchFl.isFirstResponder {
			searchFl.resignFirstResponder()
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
			if let url = url {
				tab.load(url)
			}

			tabs.append(tab)

			tab.webView.scrollView.delegate = self
			tab.webView.isHidden = true
			tab.webView.add(to: container)

			let completion = { (finished: Bool) in
				self.currentTab = tab

				self.updateChrome()

				completion?(finished)
			}

			if animation == .hidden {
				for otherTab in tabs {
					otherTab.webView.isHidden = otherTab != tab
				}

				completion(true)
			}
			else {
				if let currentTab = currentTab {
					UIView.transition(from: currentTab.webView, to: tab.webView,
									  duration: 0.25,
									  options: [.transitionCrossDissolve, .showHideTransitionViews],
									  completion: completion)
				}
				else {
					UIView.transition(with: container, duration: 0.25,
									  options: .transitionCrossDissolve,
									  animations: { tab.webView.isHidden = false },
									  completion: completion)
				}
			}
		}
		else {
			updateChrome()

			completion?(true)
		}

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

		searchFl.becomeFirstResponder()
	}

	func unfocusUrlField() {
		debug("#unfocusUrlField")

		searchFl.resignFirstResponder()
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

        if searchFl.isFirstResponder {
            searchFl.resignFirstResponder()
        }
	}


	// MARK: Public Methods

	func present(_ vc: UIViewController, _ sender: UIView) {
		vc.modalPresentationStyle = .popover
		vc.popoverPresentationController?.sourceView = sender.superview
		vc.popoverPresentationController?.sourceRect = sender.frame

		present(vc, animated: true)
	}


	// MARK: Private Methods

	func debug(_ msg: String) {
		print("[\(String(describing: type(of: self)))] \(msg)")
	}

	private func updateChrome() {
		updateSearchField()

		// The last non-hidden should be the one which is showing.
		guard let tab = tabs.last(where: { !$0.webView.isHidden }) else {
			securityBt.setTitle(nil, for: .normal)
			backBt.isEnabled = false
			frwrdBt.isEnabled = false
			actionBt.isEnabled = false
			updateTabCount()

			return
		}

		let securityId: String

		switch SecurityPreset(HostSettings(orDefaultsForHost: tab.url?.host)) {

		case .insecure:
			securityId = Formatter.localize(1)

		case .medium:
			securityId = Formatter.localize(2)

		case .secure:
			securityId = Formatter.localize(3)

		default:
			securityId = SecurityPreset.custom.description.first?.uppercased() ?? "C"
		}

		securityBt.setTitle(securityId)
		updateEncryptionBt(tab.secureMode)
		backBt.isEnabled = tab.canGoBack()
		frwrdBt.isEnabled = tab.canGoForward()
		actionBt.isEnabled = true
		updateTabCount()
	}

	/**
	Update and center tab count in `tabsBt`.

	Honors right-to-left languages.
	*/
	private func updateTabCount() {
		tabsBt.setTitle(Formatter.localize(tabs.count))

		var offset: CGFloat = 0

		if let titleLabel = tabsBt.titleLabel, let imageView = tabsBt.imageView {
			if UIView.userInterfaceLayoutDirection(for: tabsBt.semanticContentAttribute) == .rightToLeft {
				offset = imageView.intrinsicContentSize.width / 2 // Move right edge to center of image.
					+ titleLabel.intrinsicContentSize.width / 2 // Move center of text to center of image.
					+ 3 // Correct for double-frame icon.
			}
			else {
				offset = -imageView.intrinsicContentSize.width / 2 // Move left edge to center of image.
					- titleLabel.intrinsicContentSize.width / 2 // Move center of text to center of image.
					- 3 // Correct for double-frame icon.
			}
		}

		// 2+2 in vertical direction is correction for double-frame icon
		tabsBt.titleEdgeInsets = UIEdgeInsets(top: 2, left: offset, bottom: -2, right: -offset)
	}
}
