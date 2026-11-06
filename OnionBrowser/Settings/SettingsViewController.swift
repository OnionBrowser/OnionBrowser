//
//  SettingsViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 09.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class SettingsViewController: FixedFormViewController {

	private let defaultSecurityRow = LabelRow() {
		$0.title = NSLocalizedString("Default Security", comment: "Option title")
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}

	private let searchEngineRow = LabelRow() {
		$0.title = NSLocalizedString("Search Engine", comment: "Option title")
		$0.value = Settings.searchEngine.name
		$0.cell.textLabel?.numberOfLines = 0
		$0.cell.accessoryType = .disclosureIndicator
		$0.cell.selectionStyle = .default
	}


	@objc
	class func instantiate() -> UINavigationController {
		return UINavigationController(rootViewController: self.init())
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done, target: self, action: #selector(dismsiss_))
		navigationItem.title = NSLocalizedString("Settings", comment: "Scene title")

		form
		+++ defaultSecurityRow
		.onCellSelection { [weak self] _, _ in
			self?.showDefaultSecurity()
		}

		+++ Section(header: NSLocalizedString("Search", comment: "Section header"),
					footer: NSLocalizedString("When disabled, all text entered in search bar will be sent to the search engine unless it starts with \"http\".",
											  comment: "Explanation in section footer"))

		<<< searchEngineRow
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(SearchEnginesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Auto-Complete Search Results", comment: "Option title")
			$0.value = Settings.searchLive
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLive = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Stop Auto-Complete at First Dot", comment: "Option title")
			$0.value = Settings.searchLiveStopDot
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.searchLiveStopDot = value
			}
		}

		+++ Section(header: NSLocalizedString("Privacy & Security", comment: "Section header"),
					footer: NSLocalizedString("Choose how long app remembers open tabs.", comment: "Explanation in section footer"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("Custom Site Security", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CustomSitesViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Tell websites that you object to processing and selling of your personal data", comment: "Option title")
			$0.value = Settings.sendGpc
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.sendGpc = value
			}
		}

		<<< LabelRow() {
			$0.title = NSLocalizedString("Cookies and Local Storage", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(
				Storage1ViewController(), animated: true)
		}

		<<< SwitchRow() {
			switch SecureEnclave.biometryType() {
			case .touchID:
				$0.title = NSLocalizedString("Lock App with Touch ID or Device Passcode", comment: "")

			case .faceID:
				$0.title = NSLocalizedString("Lock App with Face ID or Device Passcode", comment: "")

			default:
				$0.title = NSLocalizedString("Lock App with Device Passcode", comment: "")
			}

			$0.value = SecureEnclave.loadKey() != nil
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { [weak self] row in
			let newValue: Bool

			if row.value ?? false {
				newValue = SecureEnclave.createKey() != nil
			}
			else {
				newValue = !SecureEnclave.removeKey()
			}

			// Seems, we can't create a key. Maybe running on a simulator?
			if newValue != row.value {
				// Quirky way of disabling the onChange callback to avoid an endless loop.
				self?.form.delegate = nil

				row.value = newValue
				row.updateCell()

				row.disabled = true
				row.evaluateDisabled()

				self?.form.delegate = self // Enable callback again.
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Hide App Content when in Background", comment: "")
			$0.value = Settings.hideContent
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			Settings.hideContent = row.value ?? false
		})

		<<< PushRow<TabSecurityLevel>() {
			$0.title = NSLocalizedString("Tab Security", comment: "Option title")
			$0.selectorTitle = $0.title
			$0.options = [TabSecurityLevel.alwaysRemember,
						  TabSecurityLevel.forgetOnShutdown,
						  TabSecurityLevel.clearOnBackground]

			$0.value = Settings.tabSecurity

			$0.cell.textLabel?.numberOfLines = 0
		}
		.onPresent { vc, selectorVc in
			// This is just to trigger the usage of #sectionFooterTitleForKey
			selectorVc.sectionKeyForValue = { value in
				return NSLocalizedString("Tab Security", comment: "Option title")
			}

			selectorVc.sectionFooterTitleForKey = { key in
				return NSLocalizedString("Choose how long app remembers open tabs.", comment: "")
			}
		}
		.onChange { row in
			if let value = row.value {
				Settings.tabSecurity = value
			}
		}

		+++ Section(header: NSLocalizedString("Miscellaneous", comment: "Section header"),
					footer: NSLocalizedString("Changing this option requires restarting the app.",
											  comment: "Option explanation"))

		<<< LabelRow() {
			$0.title = NSLocalizedString("URL Blocker", comment: "Option label")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(BlocklistViewController(), animated: true)
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Mute Audio with Mute Switch", comment: "Option title")
			$0.value = Settings.muteWithSwitch
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.muteWithSwitch = value
			}
		}

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Disable Bookmarks on Start Page", comment: "Option title")
			$0.value = Settings.disableBookmarksOnStartPage
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange({ row in
			if let value = row.value, value != Settings.disableBookmarksOnStartPage {
				Settings.disableBookmarksOnStartPage = value

				NcBookmarks.updateStartPage(force: true)

				for tab in AppDelegate.shared?.allOpenTabs ?? [] {
					if tab.url == URL.start {
						tab.refresh()
					}
				}
			}
		})

		<<< SwitchRow() {
			$0.title = NSLocalizedString("Allow 3rd-Party Keyboards", comment: "Option title")
			$0.value = Settings.thirdPartyKeyboards
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			if let value = row.value {
				Settings.thirdPartyKeyboards = value
			}
		}

		<<< SwitchRow() {
			$0.title = (Locale.preferredLanguages.first ?? "").hasPrefix("ru")
				? "Объединить панели, как в Safari"
				: "Merge bars like Safari"
			$0.value = UserDefaults.standard.bool(forKey: BrowsingViewController.mergedBarsKey)
			$0.cell.switchControl.onTintColor = .accent
			$0.cell.textLabel?.numberOfLines = 0
		}
		.onChange { row in
			UserDefaults.standard.set(row.value ?? false, forKey: BrowsingViewController.mergedBarsKey)
		}

		// Last section: only "About" and the version. No header.
		form
		+++ Section(header: "",
					footer: String(
						format: NSLocalizedString("Version %@", comment: "Version info at end of scene"),
						Bundle.main.version))

		<<< ButtonRow() {
			$0.title = NSLocalizedString("About", comment: "Button title")
			$0.cell.textLabel?.numberOfLines = 0
		}
		.cellUpdate { cell, _ in
			cell.textLabel?.textAlignment = .natural
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(CibulaAboutViewController(), animated: true)
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		defaultSecurityRow.value = SecurityPreset(HostSettings.forDefault()).description
		defaultSecurityRow.updateCell()

		searchEngineRow.value = Settings.searchEngine.name
		searchEngineRow.updateCell()
	}


	func showDefaultSecurity() {
		AppDelegate.shared?.dismissModals(of: SecurityViewController.self)

		navigationController?.pushViewController(
			SecurityViewController(), animated: true)
	}

	@objc private func dismsiss_() {
		navigationController?.dismiss(animated: true)
	}
}


// MARK: - About screen

class CibulaAboutViewController: UIViewController {

	private let gradient = CAGradientLayer()

	private let lilac = UIColor(red: 0.82, green: 0.69, blue: 1, alpha: 1)

	override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	override func loadView() {
		view = UIView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark
		title = tr("О приложении", "About")

		gradient.colors = [color(0x0D0019).cgColor, color(0x2A0A52).cgColor, color(0x5B13A8).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		let scroll = UIScrollView()
		scroll.alwaysBounceVertical = true
		scroll.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(scroll)

		// Logo.
		let rings = CibulaRingsView()
		rings.translatesAutoresizingMaskIntoConstraints = false

		let ringsHolder = UIView()
		ringsHolder.addSubview(rings)

		NSLayoutConstraint.activate([
			rings.centerXAnchor.constraint(equalTo: ringsHolder.centerXAnchor),
			rings.topAnchor.constraint(equalTo: ringsHolder.topAnchor),
			rings.bottomAnchor.constraint(equalTo: ringsHolder.bottomAnchor),
			rings.widthAnchor.constraint(equalToConstant: 130),
			rings.heightAnchor.constraint(equalToConstant: 130)
		])

		let titleLabel = UILabel()
		titleLabel.text = "Cibula"
		titleLabel.font = .systemFont(ofSize: 38, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		let versionLabel = UILabel()
		versionLabel.text = tr("Версия", "Version") + " " + Bundle.main.version
		versionLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .medium)
		versionLabel.textColor = lilac
		versionLabel.textAlignment = .center

		let taglineLabel = UILabel()
		taglineLabel.text = tr("Приватный браузер на базе Tor — слой за слоем, без следов.",
							   "A private browser built on Tor — layer by layer, no traces.")
		taglineLabel.font = .systemFont(ofSize: 17, weight: .semibold)
		taglineLabel.textColor = .white
		taglineLabel.textAlignment = .center
		taglineLabel.numberOfLines = 0

		let free = card("gift.fill",
						tr("Абсолютно бесплатно", "Completely free"),
						tr("Никаких подписок, рекламы и скрытых платежей.",
						   "No subscriptions, no ads, no hidden payments."))

		let design = card("paintbrush.fill",
						  tr("Улучшенный дизайн", "Better design"),
						  tr("Тёмно-фиолетовая тема, стеклянные панели и вкладки в стиле Safari.",
							 "A deep purple theme, glass bars and Safari-style tabs."))

		let clean = card("sparkles",
						 tr("Без лишнего хлама", "No clutter"),
						 tr("Убрано всё, что отвлекает. Весь трафик идёт через встроенный Tor, без дополнительных настроек.",
							"Everything distracting is gone. All traffic goes through the built-in Tor, no extra setup."))

		// The name of the original project is built from parts on purpose,
		// so the build script which renames the app doesn't touch it.
		let original = "Onion" + " " + "Browser"

		let footer = UILabel()
		footer.text = tr("Основано на открытом проекте \(original).",
						 "Based on the open source project \(original).")
		footer.font = .systemFont(ofSize: 13, weight: .regular)
		footer.textColor = UIColor.white.withAlphaComponent(0.5)
		footer.textAlignment = .center
		footer.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [ringsHolder, titleLabel, versionLabel, taglineLabel, free, design, clean, footer])
		stack.axis = .vertical
		stack.spacing = 14
		stack.setCustomSpacing(18, after: ringsHolder)
		stack.setCustomSpacing(4, after: titleLabel)
		stack.setCustomSpacing(22, after: versionLabel)
		stack.setCustomSpacing(22, after: taglineLabel)
		stack.setCustomSpacing(22, after: clean)
		stack.translatesAutoresizingMaskIntoConstraints = false
		scroll.addSubview(stack)

		NSLayoutConstraint.activate([
			scroll.topAnchor.constraint(equalTo: view.topAnchor),
			scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),

			stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
			stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
			stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 20),
			stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -20),
			stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
		])
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}


	// MARK: Private Methods

	private func card(_ symbol: String, _ title: String, _ text: String) -> UIView {
		let box = UIView()
		box.backgroundColor = UIColor.white.withAlphaComponent(0.08)
		box.layer.cornerRadius = 18
		box.layer.cornerCurve = .continuous
		box.layer.borderWidth = 1
		box.layer.borderColor = lilac.withAlphaComponent(0.25).cgColor

		let icon = UIImageView(image: UIImage(systemName: symbol))
		icon.tintColor = lilac
		icon.contentMode = .scaleAspectFit
		icon.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = UILabel()
		titleLabel.text = title
		titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
		titleLabel.textColor = .white
		titleLabel.numberOfLines = 0

		let textLabel = UILabel()
		textLabel.text = text
		textLabel.font = .systemFont(ofSize: 15, weight: .regular)
		textLabel.textColor = UIColor.white.withAlphaComponent(0.75)
		textLabel.numberOfLines = 0

		let texts = UIStackView(arrangedSubviews: [titleLabel, textLabel])
		texts.axis = .vertical
		texts.spacing = 4

		let row = UIStackView(arrangedSubviews: [icon, texts])
		row.axis = .horizontal
		row.alignment = .top
		row.spacing = 14
		row.translatesAutoresizingMaskIntoConstraints = false
		box.addSubview(row)

		NSLayoutConstraint.activate([
			icon.widthAnchor.constraint(equalToConstant: 28),
			icon.heightAnchor.constraint(equalToConstant: 28),

			row.topAnchor.constraint(equalTo: box.topAnchor, constant: 16),
			row.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -16),
			row.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 16),
			row.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -16)
		])

		return box
	}

	private func tr(_ ru: String, _ en: String) -> String {
		(Locale.preferredLanguages.first ?? "").hasPrefix("ru") ? ru : en
	}

	private func color(_ hex: UInt32) -> UIColor {
		UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
				green: CGFloat((hex >> 8) & 0xFF) / 255,
				blue: CGFloat(hex & 0xFF) / 255,
				alpha: 1)
	}
}


/// Concentric rings, like the layers of an onion.
private class CibulaRingsView: UIView {

	override init(frame: CGRect) {
		super.init(frame: frame)

		backgroundColor = .clear
		isOpaque = false
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		backgroundColor = .clear
		isOpaque = false
	}

	override func draw(_ rect: CGRect) {
		guard let ctx = UIGraphicsGetCurrentContext() else {
			return
		}

		let center = CGPoint(x: bounds.midX, y: bounds.midY)
		let maxRadius = min(bounds.width, bounds.height) / 2 - 4

		for i in 0..<4 {
			let radius = maxRadius * (1 - CGFloat(i) * 0.22)
			let alpha = 0.3 + 0.2 * CGFloat(i)

			ctx.setStrokeColor(UIColor(red: 0.82, green: 0.62, blue: 1, alpha: alpha).cgColor)
			ctx.setLineWidth(3)
			ctx.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
			ctx.strokePath()
		}

		let core = maxRadius * 0.2
		ctx.setFillColor(UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1).cgColor)
		ctx.fillEllipse(in: CGRect(x: center.x - core, y: center.y - core, width: core * 2, height: core * 2))
	}
}
