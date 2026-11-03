//
//  WelcomeViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 02.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class WelcomeViewController: UIViewController {

	// Kept only so that old nib/storyboard connections can never crash.
	// The UI is built in code below.
	@IBOutlet weak var titleLb: UILabel!
	@IBOutlet weak var bodyLb: UILabel!
	@IBOutlet weak var nextBt: UIButton!

	private let gradient = CAGradientLayer()

	override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	override func loadView() {
		// Plain view: this makes UIKit ignore any nib with the same name.
		view = UIView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark

		gradient.colors = [Self.color(0x0D0019).cgColor, Self.color(0x2A0A52).cgColor, Self.color(0x5B13A8).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		let rings = RingsView()
		rings.translatesAutoresizingMaskIntoConstraints = false

		let titleLabel = UILabel()
		titleLabel.text = "Cibula"
		titleLabel.font = .systemFont(ofSize: 46, weight: .heavy)
		titleLabel.textColor = .white
		titleLabel.textAlignment = .center

		let taglineLabel = UILabel()
		taglineLabel.text = tr("Слой за слоем — вас не видно.", "Layer by layer, you disappear.")
		taglineLabel.font = .systemFont(ofSize: 21, weight: .semibold)
		taglineLabel.textColor = Self.color(0xD2B0FF)
		taglineLabel.textAlignment = .center
		taglineLabel.numberOfLines = 0

		let bodyLabel = UILabel()
		bodyLabel.text = tr("Весь трафик идёт через Tor. Никакой слежки и никаких следов — только вы и открытая сеть.",
							"All your traffic travels through Tor. No tracking, no traces — just you and the open web.")
		bodyLabel.font = .systemFont(ofSize: 16, weight: .regular)
		bodyLabel.textColor = UIColor.white.withAlphaComponent(0.75)
		bodyLabel.textAlignment = .center
		bodyLabel.numberOfLines = 0

		let stack = UIStackView(arrangedSubviews: [titleLabel, taglineLabel, bodyLabel])
		stack.axis = .vertical
		stack.spacing = 14
		stack.setCustomSpacing(22, after: titleLabel)
		stack.translatesAutoresizingMaskIntoConstraints = false

		var config = UIButton.Configuration.filled()
		config.title = tr("Поехали", "Let's go")
		config.baseBackgroundColor = Self.color(0x8B2CF5)
		config.baseForegroundColor = .white
		config.cornerStyle = .large
		config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
		config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
			var outgoing = incoming
			outgoing.font = .systemFont(ofSize: 18, weight: .bold)
			return outgoing
		}

		let button = UIButton(configuration: config)
		button.addTarget(self, action: #selector(next), for: .touchUpInside)
		button.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(rings)
		view.addSubview(stack)
		view.addSubview(button)

		let guide = view.safeAreaLayoutGuide

		NSLayoutConstraint.activate([
			rings.topAnchor.constraint(equalTo: guide.topAnchor, constant: 56),
			rings.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			rings.widthAnchor.constraint(equalToConstant: 220),
			rings.heightAnchor.constraint(equalToConstant: 220),

			stack.topAnchor.constraint(equalTo: rings.bottomAnchor, constant: 32),
			stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
			stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),

			button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			button.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
			button.heightAnchor.constraint(greaterThanOrEqualToConstant: 58)
		])
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}

	@IBAction
	func next() {
		Settings.didWelcome = true

		// Do not get in the way of the user after a fresh install.
		// Advertising the new lockdown mode support will only be done,
		// when this installation is an update.
		Settings.updateAdvertiseLockdownMode = true

		Task {
			view.sceneDelegate?.show(await OrbotManager.shared.checkStatus())
		}
	}


	// MARK: Private Methods

	private func tr(_ ru: String, _ en: String) -> String {
		(Locale.preferredLanguages.first ?? "").hasPrefix("ru") ? ru : en
	}

	private static func color(_ hex: UInt32) -> UIColor {
		UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
				green: CGFloat((hex >> 8) & 0xFF) / 255,
				blue: CGFloat(hex & 0xFF) / 255,
				alpha: 1)
	}
}


/// Concentric rings, like the layers of an onion.
private class RingsView: UIView {

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
