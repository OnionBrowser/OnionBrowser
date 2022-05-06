//
//  BrowsingViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 29.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class BrowsingViewController: UIViewController, TabDelegate {

	@objc
	enum Transition: Int {
		case `default`
		case notAnimated
		case inBackground
	}

	private static let reloadImg = UIImage(named: "reload")
	private static let stopImg = UIImage(named: "close")

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
		button.setImage(BrowsingViewController.reloadImg, for: .normal)

		if #available(iOS 13, *) {
			button.tintColor = .label
		}
		else {
			button.tintColor = .black
		}

		button.widthAnchor.constraint(equalToConstant: 24).isActive = true
		button.heightAnchor.constraint(equalToConstant: 24).isActive = true

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		return button
	}()

	@IBOutlet weak var torBt: UIButton!
	@IBOutlet weak var progress: UIProgressView!
	@IBOutlet weak var container: UIView!
	@IBOutlet weak var containerBottomConstraint2Toolbar: NSLayoutConstraint? // Not available on iPad

	@IBOutlet weak var tabsCollection: UICollectionView! {
		didSet {
			tabsCollection.dragInteractionEnabled = true
		}
	}

	@IBOutlet weak var toolbar: UIView? // Not available on iPad
	@IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint? { // Not available on iPad
		didSet {
			toolbarHeight = toolbarHeightConstraint?.constant
		}
	}
	@IBOutlet weak var mainTools: UIStackView? // Not available on iPad
	@IBOutlet weak var tabsTools: UIView!
	@IBOutlet weak var backBt: UIButton!
	@IBOutlet weak var frwrdBt: UIButton!
	@IBOutlet weak var actionBt: UIButton!
	@IBOutlet weak var bookmarksBt: UIButton!
	@IBOutlet weak var newTabBt: UIButton?
	@IBOutlet weak var tabsBt: UIButton! {
		didSet {
			tabsBt.setTitleColor(tabsBt.tintColor, for: .normal)

			tabsBt.addTarget(self, action: #selector(showOverview), for: .touchUpInside)
		}
	}
	@IBOutlet weak var settingsBt: UIButton!
	@IBOutlet weak var newTabFromOverviewBt: UIButton! {
		didSet {
			newTabFromOverviewBt.addTarget(self, action: #selector(newTabFromOverview), for: .touchUpInside)
		}
	}
	@IBOutlet weak var hideOverviewBt: UIButton! {
		didSet {
			hideOverviewBt.setTitle(NSLocalizedString("Done", comment: ""))
			hideOverviewBt.addTarget(self, action: #selector(hideOverview), for: .touchUpInside)
		}
	}

	@objc
	var tabs = [Tab]()

	private var currentTabIndex = -1

	@objc
	weak var currentTab: Tab? {
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
	var toolbarHeight: CGFloat? // Not available on iPad

	lazy var containerBottomConstraint2Superview: NSLayoutConstraint
		= container.bottomAnchor.constraint(equalTo: view.bottomAnchor)

	lazy var liveSearchVc = LiveSearchViewController()

	init() {
		var nib = String(describing: type(of: self))

		if UIDevice.current.userInterfaceIdiom == .pad {
			nib += "-iPad"
		}

		super.init(nibName: nib, bundle: Bundle(for: type(of: self)))
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		tabsCollection.register(TabCell.nib, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			tab.add(to: container)
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
		Settings.stateRestoreLock = false
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
			tabInfo.append(["url": tab.url])

			// TODO: From old code. Why here this side effect?
			// Looks strange.
			tab.restorationIdentifier = tab.url.absoluteString
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
				addNewTab(url, forRestoration: true, transition: .notAnimated)
			}
		}

		if let index = coder.decodeObject(forKey: "curTabIndex") as? NSNumber {
			currentTabIndex = index.intValue
		}

		for tab in tabs {
			tab.isHidden = tab != currentTab
			tab.isUserInteractionEnabled = true
			tab.add(to: container)
		}

		currentTab?.refresh()

		updateChrome()
	}


	// MARK: Actions

	@IBAction func action(_ sender: UIButton) {
		unfocusSearchField()

		switch sender {
		case securityBt:
			let vc = SecurityPopUpViewController()
			let url = currentTab?.url.clean

			// Don't allow special pages to customize!
			vc.host = (url?.isSpecial ?? true) ? nil : url?.host ?? url?.path

			present(vc, sender)

		case encryptionBt:
			guard let certificate = currentTab?.sslCertificate else {
					return
			}

			let vc = CertificateViewController()
			vc.certificate = certificate
			vc.title = currentTab?.url.host
			present(UINavigationController(rootViewController: vc), sender)

		case reloadBt:
			if currentTab?.isLoading ?? false {
				currentTab?.stop()
			}
			else {
				currentTab?.refresh()
			}
			updateReloadBt()

		case torBt:
			let vc = CircuitViewController()
			vc.currentUrl = currentTab?.url.clean
			present(vc, sender)

		case backBt:
			currentTab?.goBack()

		case frwrdBt:
			currentTab?.goForward()

		case actionBt:
			guard let currentTab = currentTab else {
				return
			}

			present(UIActivityViewController(
				activityItems: [currentTab],
				applicationActivities: [AddBookmarkActivity(), TUSafariActivity()]),
					sender)

		case newTabBt:
			addEmptyTabAndFocus()

		case settingsBt:
			showSettings()

		default:
			break
		}
	}

	@IBAction func showBookmarks() {
		unfocusSearchField()

		present(BookmarksViewController.instantiate(), bookmarksBt)
	}

	@discardableResult
	@objc
	func showSettings() -> UINavigationController {
		let navC = SettingsViewController.instantiate()

		present(navC)

		return navC
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


	// MARK: TabDelegate

	func updateChrome() {
		debug("#updateChrome progress=\(currentTab?.progress ?? 1)")

		if let progress = progress {
			progress.progress = currentTab?.progress ?? 1

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

		updateReloadBt()

		updateSearchField()

		// The last non-hidden should be the one which is showing.
		guard let tab = tabs.last(where: { !$0.isHidden }) else {
			securityBt.setTitle(nil)
			backBt.isEnabled = false
			frwrdBt.isEnabled = false
			actionBt.isEnabled = false
			updateTabCount()

			return
		}

		let preset = SecurityPreset(HostSettings.for(tab.url.host))

		if preset == .custom {
			securityBt.setBackgroundImage(SecurityLevelCell.customShieldImage, for: .normal)
			securityBt.setTitle(nil)
		}
		else {
			securityBt.setBackgroundImage(SecurityLevelCell.shieldImage?.tinted(with: preset.color), for: .normal)
			securityBt.setTitle(preset.shortcode)
		}

		updateEncryptionBt(tab.secureMode)
		backBt.isEnabled = tab.canGoBack
		frwrdBt.isEnabled = tab.canGoForward
		actionBt.isEnabled = !tab.url.isSpecial
		updateTabCount()

		if !tabsCollection.isHidden {
			tabsCollection.reloadData()
		}
	}

	@objc
	@discardableResult
	func addNewTab(_ url: URL? = nil) -> Tab? {
		return addNewTab(url, forRestoration: false)
	}

	@discardableResult
	func addNewTab(_ url: URL? = nil, forRestoration: Bool = false,
				   transition: Transition = .default, completion: ((Bool) -> Void)? = nil) -> Tab? {

		debug("#addNewTab url=\(String(describing: url)), forRestoration=\(forRestoration), transition=\(transition), completion=\(String(describing: completion))")

		let tab = Tab(restorationId: forRestoration ? url?.absoluteString : nil)

		if !forRestoration {
			tab.load(url)
		}

		tab.tabDelegate = self

		tabs.append(tab)

		tab.scrollView.delegate = self
		tab.isHidden = true
		tab.add(to: container)

		let animations = {
			for otherTab in self.tabs {
				otherTab.isHidden = otherTab != tab
			}
		}

		let completionForeground = { (finished: Bool) in
			self.currentTab = tab

			self.updateChrome()

			completion?(finished)
		}

		switch transition {
		case .notAnimated:
			animations()
			completionForeground(true)

		case .inBackground:
			completion?(true)

		default:
			container.transition(animations, completionForeground)
		}

		return tab
	}

	func removeTab(_ tab: Tab, focus: Tab? = nil) {
		debug("#removeTab tab=\(tab) focus=\(String(describing: focus))")

		unfocusSearchField()

		container.transition({
			tab.isHidden = true
			(focus ?? self.tabs.last)?.isHidden = false
		}) { _ in
			self.currentTab = focus ?? self.tabs.last

			let hash = tab.hash

			tab.close()
			self.tabs.removeAll { $0 == tab }

			AppDelegate.shared?.cookieJar.clearNonWhitelistedData(forTab: UInt(hash))

			self.updateChrome()
		}
	}

	func getTab(ipcId: String?) -> Tab? {
		return tabs.first { $0.ipcId == ipcId }
	}

	func getTab(hash: Int?) -> Tab? {
		return tabs.first { $0.hash == hash }
	}

	func getIndex(of tab: Tab) -> Int? {
		return tabs.firstIndex(of: tab)
	}

	func unfocusSearchField() {
		if searchFl.isFirstResponder {
			searchFl.resignFirstResponder()
		}
	}


	// MARK: Public Methods

	@objc
	func becomesVisible() {
		if let newUrl = Settings.openNewUrlOnStart {
			Settings.openNewUrlOnStart = nil

			if newUrl == URL.blank {
				// Workaround for showing an empty tab.
				// See AppDelegate#handle:
				addEmptyTabAndFocus()
			}
			else {
				addNewTab(newUrl, transition: .notAnimated)
			}
		}
		else if tabs.count < 1 {
			addNewTab()
		}
	}

	@objc
	func addEmptyTabAndFocus() {
		addNewTab() { _ in
			self.focusSearchField()
		}
	}

	@objc
	func switchToTab(_ index: Int) {
		if index < 0 || index >= tabs.count {
			return
		}

		let focussing = tabs[index]

		container.transition({
			for tab in self.tabs {
				tab.isHidden = tab != focussing
			}
		}) { _ in
			self.currentTab = focussing
			self.updateChrome()
		}
	}

	@objc
	func removeCurrentTab() {
		guard let currentTab = currentTab else {
			return
		}

		removeTab(currentTab)
	}

	@objc
	func removeAllTabs() {
		for tab in tabs {
			tab.close()
		}

		tabs.removeAll()

		currentTab = nil

		AppDelegate.shared?.cookieJar.clearAllNonWhitelistedData()

		self.updateChrome()
	}

	@objc
	func focusSearchField() {
		if !searchFl.isFirstResponder {
			searchFl.becomeFirstResponder()
		}
	}

	func debug(_ msg: String) {
		print("[\(String(describing: type(of: self)))] \(msg)")
	}


	// MARK: Private Methods

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

	/**
	Shows either a reload or stop icon, depending on if the current tab is currently loading or not.
	*/
	private func updateReloadBt() {
		if currentTab?.isLoading ?? false {
			reloadBt.setImage(BrowsingViewController.stopImg, for: .normal)
			reloadBt.imageEdgeInsets = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
		}
		else {
			reloadBt.setImage(BrowsingViewController.reloadImg, for: .normal)
			reloadBt.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
		}
	}
}
