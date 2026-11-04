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

		var config = UIButton.Config
