//
//  BrowsingViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 29.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import WebKit

class BrowsingViewController: UIViewController, TabDelegate {

	@objc
	enum Transition: Int {
		case `default`
		case notAnimated
		case inBackground
	}

	/// UserDefaults key of the "merge bars like Safari" switch in the settings.
	static let mergedBarsKey = "CibulaMergedBars"

	private static let reloadImg = UIImage(systemName: "arrow.clockwise")
	private static let stopImg = UIImage(systemName: "xmark")

	private let barGlassTag = 7702
	private let backdropTag = 7703

	@IBOutlet weak var searchBar: UIView?
	@IBOutlet weak var searchBarHeightConstraint: NSLayoutConstraint? {
		didSet {
			searchBarHeight = searchBarHeightConstraint?.constant
		}
	}
	@IBOutlet weak var securityBt: UIButton? {
		didSet {
			securityBt?.accessibilityHint = NSLocalizedString("Security Level for This Site", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var searchFl: UITextField? {
		didSet {
			searchFl?.leftView = encryptionBt
			searchFl?.rightView = reloadBt
			searchFl?.accessibilityHint = NSLocalizedString("Address and search bar", comment: "VoiceOver")
		}
	}

	lazy var encryptionBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		button.accessibilityLabel = NSLocalizedString("Certificate Information", comment: "VoiceOver")

		return button
	}()

	private lazy var reloadBt: UIButton = {
		let button = UIButton(type: .custom)
		button.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
		button.setImage(BrowsingViewController.reloadImg, for: .normal)
		button.tintColor = .label

		button.widthAnchor.constraint(equalToConstant: 24).isActive = true
		button.heightAnchor.constraint(equalToConstant: 24).isActive = true

		button.addTarget(self, action: #selector(action), for: .touchUpInside)

		return button
	}()

	@IBOutlet weak var torBt: UIButton? {
		didSet {
			torBt?.accessibilityLabel = NSLocalizedString("Tor Circuit", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var progress: UIProgressView?
	@IBOutlet weak var container: UIView?
	@IBOutlet weak var containerBottomConstraint2Toolbar: NSLayoutConstraint? // Not available on iPad

	@IBOutlet weak var tabsCollection: UICollectionView? {
		didSet {
			tabsCollection?.dragInteractionEnabled = true
		}
	}

	@IBOutlet weak var toolbar: UIView? // Not available on iPad
	@IBOutlet weak var toolbarHeightConstraint: NSLayoutConstraint? { // Not available on iPad
		didSet {
			toolbarHeight = toolbarHeightConstraint?.constant
		}
	}
	@IBOutlet weak var mainTools: UIStackView? // Not available on iPad
	@IBOutlet weak var tabsTools: UIView?
	@IBOutlet weak var backBt: UIButton? {
		didSet {
			backBt?.accessibilityLabel = NSLocalizedString("Back", comment: "VoiceOver")
		}
	}
	@IBOutlet weak var frwrdBt: UIButton? {
		didSet {
			frwrdBt?.accessibilityLabel = NSLocalizedString("Forward", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var findBt: UIButton? {
		didSet {
			if #available(iOS 16.0, *) {
				// No change.
			}
			else {
				// We do not support find below iOS 16.
				findBt?.isHidden = true

				// Reduce used width and height to 0.
				for constraint in findBt?.constraints ?? [] {
					if constraint.firstAnchor is NSLayoutAnchor<NSLayoutDimension> {
						constraint.constant = 0
					}
				}

				// Reduce one margin constraint to 0.
				for constraint in findBt?.superview?.constraints ?? [] {
					if let item = constraint.firstItem as? UIButton,
						item == findBt,
						constraint.secondItem is UIButton
					{
						constraint.constant = 0
					}
				}
			}
		}
	}

	@IBOutlet weak var actionBt: UIButton?
	@IBOutlet weak var bookmarksBt: UIButton?
	@IBOutlet weak var newTabBt: UIButton?

	@IBOutlet weak var tabsBt: UIButton? {
		didSet {
			tabsBt?.setTitleColor(tabsBt?.tintColor, for: .normal)

			tabsBt?.addTarget(self, action: #selector(showOverview), for: .touchUpInside)

			tabsBt?.accessibilityHint = NSLocalizedString("Tabs", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var settingsBt: UIButton? {
		didSet {
			settingsBt?.accessibilityLabel = NSLocalizedString("Settings", comment: "VoiceOver")
		}
	}

	@IBOutlet weak var newTabFromOverviewBt: UIButton? {
		didSet {
			newTabFromOverviewBt?.addTarget(self, action: #selector(newTabFromOverview), for: .touchUpInside)
		}
	}

	@IBOutlet weak var hideOverviewBt: UIButton? {
		didSet {
			hideOverviewBt?.setTitle(NSLocalizedString("Done", comment: ""))
			hideOverviewBt?.addTarget(self, action: #selector(hideOverview), for: .touchUpInside)
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

	lazy var containerBottomConstraint2Superview: NSLayoutConstraint?
		= container?.bottomAnchor.constraint(equalTo: view.bottomAnchor)

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

		tabsCollection?.register(TabCell.nib, forCellWithReuseIdentifier: TabCell.reuseIdentifier)

		// There could have been tabs added before XIB was initialized.
		for tab in tabs {
			tab.add(to: container)
		}

		styleChrome()

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

		if currentTab?.needsRefresh ?? false {
			currentTab?.refresh()
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

		coder.encode(tabs.map({ $0.url.clean }), forKey: "webViewTabs")
		coder.encode(NSNumber(value: currentTabIndex), forKey: "curTabIndex")
	}

	func encodeRestorableState(with activity: NSUserActivity) {
		if !(currentTab?.url.isSpecial ?? true) {
			activity.webpageURL = currentTab?.url.clean
			activity.title = currentTab?.title
		}
		activity.userInfo = ["webViewTabs": tabs.map({ $0.url.clean }),
							 "curTabIndex": NSNumber(value: currentTabIndex)]
	}

	override func decodeRestorableState(with coder: NSCoder) {
		super.decodeRestorableState(with: coder)

		var urls = coder.decodeObject(forKey: "webViewTabs") as? [URL?]

		// Legacy support.
		if urls == nil {
			urls = (coder.decodeObject(forKey: "webViewTabs") as? [[String: Any]])?
				.map { $0["url"] as? URL }
		}

		decodeRestorableState(
			urls,
			coder.decodeObject(forKey: "curTabIndex") as? NSNumber)
	}

	func decodeRestorableState(with activity: NSUserActivity) {
		decodeRestorableState(
			activity.userInfo?["webViewTabs"] as? [URL?],
			activity.userInfo?["curTabIndex"] as? NSNumber)
	}

	func decodeRestorableState(_ urls: [URL?]?, _ currentTabIndex: NSNumber?) {
		for url in urls ?? [] {
			debug("Try restoring tab with \(url?.absoluteString ?? "(nil)").")

			addNewTab(url, transition: .notAnimated)
		}

		if let currentTabIndex = currentTabIndex {
			self.currentTabIndex = currentTabIndex.intValue
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
			guard let certificate = currentTab?.tlsCertificate else {
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

		case findBt:
			currentTab?.toggleFind()

		case actionBt:
			guard let currentTab = currentTab else {
				return
			}

			present(UIActivityViewController(
				activityItems: [currentTab],
				applicationActivities: [DownloadActivity(), AddBookmarkActivity(), SafariActivity()]),
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

		AppDelegate.shared?.dismissModals(of: BookmarksViewController.self)

		present(BookmarksViewController.instantiate(), bookmarksBt)
	}

	@discardableResult
	@objc
	func showSettings() -> UINavigationController {
		AppDelegate.shared?.dismissModals(of: SettingsViewController.self)

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
			securityBt?.setTitle(nil)
			backBt?.isEnabled = false
			frwrdBt?.isEnabled = false
			findBt?.isEnabled = false
			actionBt?.isEnabled = false
			updateTabCount()

			return
		}

		let preset = SecurityPreset(HostSettings.for(tab.url.host))

		if preset == .custom {
			securityBt?.setBackgroundImage(SecurityLevelCell.customShieldImage, for: .normal)
			securityBt?.setTitle(nil)
		}
		else {
			securityBt?.setBackgroundImage(SecurityLevelCell.shieldImage?.tinted(with: preset.color), for: .normal)
			securityBt?.setTitle(preset.shortcode)
		}

		updateEncryptionBt(tab.secureMode)
		backBt?.isEnabled = tab.canGoBack
		frwrdBt?.isEnabled = tab.canGoForward
		findBt?.isEnabled = !tab.url.isSpecial
		actionBt?.isEnabled = tab.url.isSearchable
		updateTabCount()

		if !(tabsCollection?.isHidden ?? true) {
			tabsCollection?.reloadData()
		}
	}

	@objc
	@discardableResult
	func addNewTab(_ url: URL? = nil, configuration: WKWebViewConfiguration? = nil) -> Tab? {
		return addNewTab(url, transition: .default, configuration: configuration)
	}

	@discardableResult
	func addNewTab(_ url: URL? = nil,
				   transition: Transition = .default,
				   configuration: WKWebViewConfiguration? = nil,
				   completion: ((Bool) -> Void)? = nil) -> Tab?
	{
		debug("#addNewTab url=\(String(describing: url)), transition=\(transition), completion=\(String(describing: completion))")

		let tab = Tab(restorationId: url?.absoluteString, configuration: configuration)

		tab.load(url)

		tab.tabDelegate = self

		tabs.append(tab)

		tab.scrollViewDelegate = self
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
			container?.transition(animations, completionForeground)
		}

		if #available(iOS 18, *) {
			TabEntity.add(tab: tab)
		}

		return tab
	}

	func removeTab(_ tab: Tab, focus: Tab? = nil) {
		debug("#removeTab tab=\(tab) focus=\(String(describing: focus))")

		unfocusSearchField()

		container?.transition({
			tab.isHidden = true
			(focus ?? self.tabs.last)?.isHidden = false
		}) { _ in
			tab.close()
			self.tabs.removeAll { $0 == tab }

			if #available(iOS 18, *) {
				TabEntity.removeTab(withId: tab.hash)
			}

			self.currentTab = focus ?? self.tabs.last
			self.currentTab?.isHidden = false

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
		if searchFl?.isFirstResponder ?? false {
			searchFl?.resignFirstResponder()
		}
	}


	// MARK: Public Methods

	@objc
	func becomesVisible() {
		if tabs.count < 1 {
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

		container?.transition({
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

		WebsiteStorage.shared.cleanup()

		self.updateChrome()
	}

	@objc
	func focusSearchField() {
		if !(searchFl?.isFirstResponder ?? false) {
			searchFl?.becomeFirstResponder()
		}
	}

	func debug(_ msg: String) {
		Log.debug(for: Self.self, msg)
	}


	// MARK: Private Methods

	/**
	Gives the top and bottom bars a floating liquid glass look, like Safari.
	Optionally merges both bars into one at the bottom.
	*/
	private func styleChrome() {
		let lilac = UIColor(red: 0.90, green: 0.82, blue: 1, alpha: 1)

		let isPhone = UIDevice.current.userInterfaceIdiom != .pad
		let merged = isPhone && toolbar != nil && UserDefaults.standard.bool(forKey: Self.mergedBarsKey)

		addBackdrop()

		if merged {
			mergeBars()
		}

		if let bar = searchBar, !merged {
			floatBar(bar, atTop: true)
		}

		if let bar = toolbar {
			floatBar(bar, atTop: false)
		}

		searchBar?.tintColor = lilac
		toolbar?.tintColor = lilac
		mainTools?.tintColor = lilac
		tabsBt?.tintColor = lilac
		tabsBt?.setTitleColor(lilac, for: .normal)

		if let field = searchFl {
			field.overrideUserInterfaceStyle = .dark
			field.borderStyle = .none
			field.textColor = .white
			field.tintColor = lilac

			if merged {
				// Inside the shared capsule the address field needs its own soft box.
				field.backgroundColor = UIColor.white.withAlphaComponent(0.10)
				field.layer.cornerRadius = 14
				field.layer.cornerCurve = .continuous
				field.layer.masksToBounds = true
			}
			else {
				field.backgroundColor = .clear
			}
		}

		reloadBt.tintColor = lilac

		view.layoutIfNeeded()
	}

	/// Dark purple background behind the floating bars.
	private func addBackdrop() {
		if view.viewWithTag(backdropTag) != nil {
			return
		}

		let backdrop = GradientBackdropView()
		backdrop.tag = backdropTag
		backdrop.isUserInteractionEnabled = false
		backdrop.translatesAutoresizingMaskIntoConstraints = false
		view.insertSubview(backdrop, at: 0)

		NSLayoutConstraint.activate([
			backdrop.topAnchor.constraint(equalTo: view.topAnchor),
			backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor)
		])
	}

	/**
	Moves the address bar from the top into the bottom bar, above the buttons.
	The bottom bar grows by the height of the address bar.
	*/
	private func mergeBars() {
		guard let top = searchBar, let bottom = toolbar else {
			return
		}

		let topHeight: CGFloat = searchBarHeight ?? 44

		top.removeFromSuperview()
		bottom.addSubview(top)
		top.translatesAutoresizingMaskIntoConstraints = false

		NSLayoutConstraint.activate([
			top.topAnchor.constraint(equalTo: bottom.topAnchor, constant: 2),
			top.leadingAnchor.constraint(equalTo: bottom.leadingAnchor),
			top.trailingAnchor.constraint(equalTo: bottom.trailingAnchor)
		])

		let newHeight = (toolbarHeight ?? toolbarHeightConstraint?.constant ?? 49) + topHeight + 2
		toolbarHeight = newHeight
		toolbarHeightConstraint?.constant = newHeight

		// Buttons stay in the lower part.
		mainTools?.isLayoutMarginsRelativeArrangement = true
		mainTools?.layoutMargins = UIEdgeInsets(top: topHeight + 2, left: 0, bottom: 0, right: 0)

		// The page now starts at the top of the screen. Soft priority, so an existing
		// constraint from the layout file wins, if there is one left.
		let pinned: [UIView?] = [container, progress]

		for item in pinned {
			guard let item = item else {
				continue
			}

			let constraint = item.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
			constraint.priority = UILayoutPriority(750)
			constraint.isActive = true
		}
	}

	/**
	Pulls a bar away from the screen edges (if the layout file pins it there)
	and puts a rounded glass capsule behind its content.
	*/
	private func floatBar(_ bar: UIView, atTop: Bool) {
		if bar.viewWithTag(barGlassTag) != nil {
			return
		}

		let sideInset: CGFloat = 12
		let edgeGap: CGFloat = 6

		for constraint in view.constraints where constraint.isActive {
			let barIsFirst = constraint.firstItem === bar
			let barIsSecond = constraint.secondItem === bar

			if barIsFirst == barIsSecond {
				continue
			}

			let other: AnyObject? = barIsFirst ? constraint.secondItem : constraint.firstItem
			let attribute = barIsFirst ? constraint.firstAttribute : constraint.secondAttribute
			let otherAttribute = barIsFirst ? constraint.secondAttribute : constraint.firstAttribute

			guard attribute == otherAttribute, isScreenEdge(other) else {
				continue
			}

			var inward: CGFloat = 0

			switch attribute {
			case .leading, .left:
				inward = sideInset

			case .trailing, .right:
				inward = -sideInset

			case .top:
				inward = atTop ? edgeGap : 0

			case .bottom:
				inward = atTop ? 0 : -edgeGap

			default:
				break
			}

			if inward != 0 {
				constraint.constant += barIsFirst ? inward : -inward
			}
		}

		bar.backgroundColor = .clear
		bar.overrideUserInterfaceStyle = .dark

		let effect: UIVisualEffect

		if #available(iOS 26.0, *) {
			effect = UIGlassEffect()
		}
		else {
			effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
		}

		let glass = CapsuleGlassView(effect: effect)
		glass.tag = barGlassTag
		glass.frame = bar.bounds
		glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		glass.isUserInteractionEnabled = false
		glass.clipsToBounds = true
		glass.layer.cornerCurve = .continuous
		glass.layer.borderWidth = 0.5
		glass.layer.borderColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.35).cgColor

		// Light purple tint on top of the glass.
		glass.contentView.backgroundColor = UIColor(red: 0.30, green: 0.08, blue: 0.55, alpha: 0.28)

		bar.insertSubview(glass, at: 0)
	}

	private func isScreenEdge(_ item: AnyObject?) -> Bool {
		if let item = item as? UIView {
			return item === view
		}

		if let guide = item as? UILayoutGuide {
			return guide.owningView === view
		}

		return false
	}

	/**
	Update and center tab count in `tabsBt`.

	Honors right-to-left languages.
	*/
	private func updateTabCount() {
		tabsBt?.setTitle(Formatter.localize(tabs.count))

		var offset: CGFloat = 0

		if let titleLabel = tabsBt?.titleLabel, let imageView = tabsBt?.imageView {
			if UIView.userInterfaceLayoutDirection(for: tabsBt!.semanticContentAttribute) == .rightToLeft {
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
		// Ignore deprecation. UIButton.Configuration doesn't provide the vertical insets we need.
		tabsBt?.titleEdgeInsets = UIEdgeInsets(top: 2, left: offset, bottom: -2, right: -offset)

		// Half-way, in fresh style:
		// var conf = UIButton.Configuration.plain()
		// conf.imagePadding = offset
		// tabsBt.configuration = conf
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


/// Glass view with fully rounded ends.
private final class CapsuleGlassView: UIVisualEffectView {

	override func layoutSubviews() {
		super.layoutSubviews()

		layer.cornerRadius = min(bounds.height / 2, 28)
	}
}


/// Dark purple gradient, drawn behind everything.
private final class GradientBackdropView: UIView {

	override class var layerClass: AnyClass {
		CAGradientLayer.self
	}

	override init(frame: CGRect) {
		super.init(frame: frame)

		configure()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		configure()
	}

	private func configure() {
		guard let gradient = layer as? CAGradientLayer else {
			return
		}

		gradient.colors = [UIColor(red: 0.05, green: 0.00, blue: 0.10, alpha: 1).cgColor,
						   UIColor(red: 0.16, green: 0.04, blue: 0.32, alpha: 1).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
	}
}
