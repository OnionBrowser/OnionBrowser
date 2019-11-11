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

	@objc
	enum Animation: Int {
		case `default`
		case hidden
	}

	static let blankUrl = "about:blank"
	static let aboutOnionBrowserUrl = "about:onion-browser"

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

			if currentTab?.needsRefresh ?? false {
				currentTab?.refresh()
			}
		}
	}

    var searchBarHeight: CGFloat!
    var toolbarHeight: CGFloat!

    lazy var containerBottomConstraint2Superview: NSLayoutConstraint
        = container.bottomAnchor.constraint(equalTo: view.bottomAnchor)

	lazy var liveSearchVc = SearchResultsController()
	var liveSearchOngoing = false


    override func viewDidLoad() {
        super.viewDidLoad()

        tabsCollection.register(TabCell.nib, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			tab.webView.add(to: container)
		}

		updateChrome()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		let nc = NotificationCenter.default

		nc.addObserver(self,
					   selector: #selector(keyboardWillShow(notification:)),
					   name: UIResponder.keyboardWillShowNotification,
					   object: nil)

		nc.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)),
					   name: UIResponder.keyboardWillHideNotification,
					   object: nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		// We made it this far, remove lock on previous startup.
		UserDefaults.standard.removeObject(forKey: STATE_RESTORE_TRY_KEY)

		if let url = AppDelegate.shared()?.urlToOpenAtLaunch {
			AppDelegate.shared()?.urlToOpenAtLaunch = nil

			addNewTab(forURL: url)
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		let nc = NotificationCenter.default

		nc.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
		nc.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
	}

	override func encodeRestorableState(with coder: NSCoder) {
		super.encodeRestorableState(with: coder)

		var tabInfo = [[String: Any]]()

		for tab in tabs {
			if let url = tab.url {
				tabInfo.append(["url": url, "title": tab.title.text ?? ""])

				// TODO: From old code. Why here this side effect?
				// Looks strange.
				tab.webView.restorationIdentifier = url.absoluteString
			}
		}

		coder.encode(tabInfo, forKey: "webViewTabs")
		coder.encode(NSNumber(value: currentTabIndex), forKey: "curTabIndex")
	}

	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)

		let tabInfo = coder.decodeObject(forKey: "webViewTabs") as? [[String: Any]]

		for info in tabInfo ?? [] {
			debug("Try restoring tab with \(info).")

			if let url = info["url"] as? URL {
				let tab = addNewTab(for: url, forRestoration: true, with: .hidden, withCompletionBlock: nil)
				tab?.title.text = info["title"] as? String
			}
		}

		if let index = coder.decodeObject(forKey: "curTabIndex") as? NSNumber {
			currentTabIndex = index.intValue
		}

		for tab in tabs {
			tab.webView.isHidden = tab != currentTab
			tab.webView.isUserInteractionEnabled = true
			tab.webView.add(to: container)
		}

		currentTab?.refresh()

		updateProgress()
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

	@objc func keyboardWillShow(notification: Notification) {
		if let kbSize = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
			let insets = UIEdgeInsets(top: 0, left: 0, bottom: kbSize.height, right: 0)
			liveSearchVc.tableView.contentInset = insets
			liveSearchVc.tableView.scrollIndicatorInsets = insets
		}
	}

	@objc func keyboardWillBeHidden(notification: Notification) {
		liveSearchVc.tableView.contentInset = .zero
		liveSearchVc.tableView.scrollIndicatorInsets = .zero
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
				   with animation: Animation, withCompletionBlock completion: ((Bool) -> Void)?) -> WebViewTab? {

		debug("#addNewTab url=\(String(describing: url)), restoration=\(restoration), animation=\(animation), completion=\(String(describing: completion))")

		let tab = WebViewTab(frame: .zero, withRestorationIdentifier: restoration ? url?.absoluteString : nil)

		if let tab = tab {
			if let url = url, !restoration {
				tab.load(url)
			}

			tabs.append(tab)

			tab.webView.scrollView.delegate = self
			tab.webView.isHidden = true
			tab.webView.add(to: container)

			let animations = {
				for otherTab in self.tabs {
					otherTab.webView.isHidden = otherTab != tab
				}
			}

			let completion = { (finished: Bool) in
				self.currentTab = tab

				self.updateChrome()

				completion?(finished)
			}

			if animation == .hidden {
				animations()
				completion(true)
			}
			else {
				container.transition(animations, completion)
			}
		}
		else {
			updateChrome()

			completion?(true)
		}

		return tab
	}

	func addNewTabFromToolbar(_ sender: Any?) {
		debug("#addNewTabFromToolbar sender=\(String(describing: sender))")

		addNewTab(for: nil, forRestoration: false, with: .default) { _ in
			self.searchFl.becomeFirstResponder()
		}
	}

	func switchToTab(_ tabNumber: NSNumber) {
		debug("#switchToTab tabNumber=\(tabNumber)")

		let index = tabNumber.intValue

		if index < 0 || index >= tabs.count {
			return
		}

		let focussing = tabs[index]

		container.transition({
			for tab in self.tabs {
				tab.webView.isHidden = tab != focussing
			}
		}) { _ in
			self.currentTab = focussing
			self.updateChrome()
		}
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
			unfocusUrlField()

			container.transition({
				removing.webView.isHidden = true
				(focussing ?? self.tabs.last)?.webView.isHidden = false
			}) { _ in
				self.currentTab = focussing ?? self.tabs.last

				let hash = removing.hash

				removing.webView.removeFromSuperview()
				self.tabs.remove(at: rIdx)

				AppDelegate.shared()?.cookieJar.clearNonWhitelistedData(forTab: UInt(hash))

				self.updateChrome()
			}
		}
		else if focussing != nil {
			unfocusUrlField()

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

		guard liveSearchOngoing else {
			return
		}

		if UIDevice.current.userInterfaceIdiom == .pad {
			liveSearchVc.dismiss(animated: true)
		}
		else {
			liveSearchVc.view.removeFromSuperview()
			liveSearchVc.removeFromParent()
		}

		liveSearchOngoing = false
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

		if searchFl.isFirstResponder {
			searchFl.resignFirstResponder()
		}
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
		debug("#updateProgress progress=\(currentTab?.progress.floatValue ?? 1)")

		if let progress = progress {
			progress.progress = currentTab?.progress.floatValue ?? 1

			if progress.progress >= 1 {
				if !progress.isHidden {
					view.transition({ progress.isHidden = true })
				}
			}
			else {
				if progress.isHidden {
					view.transition({ progress.isHidden = false })
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
