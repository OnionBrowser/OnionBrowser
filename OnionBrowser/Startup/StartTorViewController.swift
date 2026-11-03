//
//  StartTorViewController.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 11.10.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import IPtProxyUI_iOS

class StartTorViewController: UIViewController, BridgesConfDelegate {

	// Kept only so that old nib/storyboard connections can never crash.
	// The UI is built in code below.
	@IBOutlet weak var titleLb: UILabel!
	@IBOutlet weak var activityIndicator: UIActivityIndicatorView!
	@IBOutlet weak var retryBt: UIButton!
	@IBOutlet weak var progressView: UIProgressView!
	@IBOutlet weak var statusLb: UILabel!
	@IBOutlet weak var bridgesBt: UIButton!

	private let gradient = CAGradientLayer()
	private let ringsView = SpinningRingsView()
	private let headline = UILabel()
	private let progressBar = UIProgressView(progressViewStyle: .default)
	private let percentLabel = UILabel()
	private let statusLabel = UILabel()
	private let retryButton = UIButton(type: .system)
	private let bridgesButton = UIButton(type: .system)

	override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

	override func loadView() {
		view = UIView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		overrideUserInterfaceStyle = .dark

		gradient.colors = [Self.color(0x0D0019).cgColor, Self.color(0x2A0A52).cgColor, Self.color(0x5B13A8).cgColor]
		gradient.startPoint = CGPoint(x: 0.2, y: 0)
		gradient.endPoint = CGPoint(x: 0.8, y: 1)
		view.layer.insertSublayer(gradient, at: 0)

		ringsView.translatesAutoresizingMaskIntoConstraints = false

		headline.text = tr("Заходим в сеть Tor…", "Entering the Tor network…")
		headline.font = .systemFont(ofSize: 28, weight: .heavy)
		headline.textColor = .white
		headline.textAlignment = .center
		headline.numberOfLines = 0

		progressBar.progressTintColor = Self.color(0xC58BFF)
		progressBar.trackTintColor = UIColor.white.withAlphaComponent(0.15)
		progressBar.transform = CGAffineTransform(scaleX: 1, y: 2.5)
		progressBar.layer.cornerRadius = 2
		progressBar.clipsToBounds = true

		percentLabel.text = "0%"
		percentLabel.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
		percentLabel.textColor = Self.color(0xD2B0FF)
		percentLabel.textAlignment = .center

		statusLabel.font = .systemFont(ofSize: 15, weight: .regular)
		statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
		statusLabel.textAlignment = .center
		statusLabel.numberOfLines = 0
		statusLabel.isHidden = true

		let content = UIStackView(arrangedSubviews: [headline, progressBar, percentLabel, statusLabel])
		content.axis = .vertical
		content.spacing = 18
		content.setCustomSpacing(26, after: headline)
		content.translatesAutoresizingMaskIntoConstraints = false

		var retryConfig = UIButton.Configuration.filled()
		retryConfig.title = tr("Повторить", "Retry")
		retryConfig.baseBackgroundColor = Self.color(0x8B2CF5)
		retryConfig.baseForegroundColor = .white
		retryConfig.cornerStyle = .large
		retryConfig.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
		retryButton.configuration = retryConfig
		retryButton.addTarget(self, action: #selector(retry), for: .touchUpInside)
		retryButton.isHidden = true

		var bridgesConfig = UIButton.Configuration.tinted()
		bridgesConfig.title = tr("Настроить мосты", "Configure Bridges")
		bridgesConfig.baseBackgroundColor = Self.color(0xC58BFF)
		bridgesConfig.baseForegroundColor = Self.color(0xE6D2FF)
		bridgesConfig.cornerStyle = .large
		bridgesConfig.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 24, bottom: 18, trailing: 24)
		bridgesButton.configuration = bridgesConfig
		bridgesButton.addTarget(self, action: #selector(configureBridges), for: .touchUpInside)

		let buttons = UIStackView(arrangedSubviews: [retryButton, bridgesButton])
		buttons.axis = .vertical
		buttons.spacing = 12
		buttons.translatesAutoresizingMaskIntoConstraints = false

		view.addSubview(ringsView)
		view.addSubview(content)
		view.addSubview(buttons)

		let guide = view.safeAreaLayoutGuide

		NSLayoutConstraint.activate([
			ringsView.topAnchor.constraint(equalTo: guide.topAnchor, constant: 64),
			ringsView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			ringsView.widthAnchor.constraint(equalToConstant: 200),
			ringsView.heightAnchor.constraint(equalToConstant: 200),

			content.topAnchor.constraint(equalTo: ringsView.bottomAnchor, constant: 36),
			content.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
			content.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

			buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			buttons.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16)
		])
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()

		gradient.frame = view.bounds
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)

		retry()
	}


	// MARK: BridgesConfDelegate

	var transport: IPtProxyUI_Shared.Transport {
		get {
			Settings.transport
		}
		set {
			Settings.transport = newValue
		}
	}

	var customBridges: [String]? {
		get {
			Settings.customBridges
		}
		set {
			Settings.customBridges = newValue
		}
	}

	var countryCode: String? {
		get {
			Settings.countryCode
		}
		set {
			Settings.countryCode = newValue
		}
	}

	func save() {
		TorManager.shared.updateConfig(Settings.transport)
	}


	// MARK: Actions

	@IBAction
	func retry() {
		ringsView.start()
		retryButton.isHidden = true
		headline.text = tr("Заходим в сеть Tor…", "Entering the Tor network…")
		progressBar.progress = 0
		percentLabel.text = "0%"
		statusLabel.isHidden = true

		TorManager.shared.start(Settings.transport) { [weak self] progress, summary in
			guard let progress = progress else {
				return
			}

			Task {
				await MainActor.run {
					self?.progressBar.setProgress(Float(progress) / 100, animated: true)
					self?.percentLabel.text = String(format: "%d%%", progress)

					UIAccessibility.post(notification: .announcement, argument: String(format: "%d%%", progress))

					if let summary = summary, !summary.isEmpty {
						self?.statusLabel.text = summary
						self?.statusLabel.textColor = UIColor.white.withAlphaComponent(0.8)
						self?.statusLabel.isHidden = false
					}
					else {
						self?.statusLabel.isHidden = true
					}
				}
			}
		} _: { [weak self] error in
			Task { @MainActor in
				guard error == nil else {
					self?.ringsView.stop()
					self?.retryButton.isHidden = false
					self?.headline.text = self?.tr("Не удалось подключиться", "Couldn't connect")
					self?.statusLabel.text = (error ?? TorManager.Errors.noSocksAddr).localizedDescription
					self?.statusLabel.textColor = Self.color(0xFF7A7A)
					self?.statusLabel.isHidden = false

					UIAccessibility.post(notification: .announcement, argument: self?.statusLabel.text)

					return
				}

				AppDelegate.shared?.allOpenTabs.forEach { tab in
					tab.reinitWebView()
				}

				self?.view.sceneDelegate?.show(await OrbotManager.shared.checkStatus())
			}
		}
	}

	@IBAction
	func configureBridges() {
		let vc = BridgesConfViewController()
		vc.delegate = self

		present(UINavigationController(rootViewController: vc))
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


/// Rotating arcs around a pulsing core.
private class SpinningRingsView: UIView {

	private var ringLayers = [CAShapeLayer]()
	private let coreLayer = CAShapeLayer()
	private var isAnimating = false

	override func layoutSubviews() {
		super.layoutSubviews()

		ringLayers.forEach { $0.removeFromSuperlayer() }
		ringLayers.removeAll()
		coreLayer.removeFromSuperlayer()

		let center = CGPoint(x: bounds.midX, y: bounds.midY)
		let maxRadius = min(bounds.width, bounds.height) / 2 - 4

		for i in 0..<3 {
			let radius = maxRadius * (1 - CGFloat(i) * 0.28)

			let layer = CAShapeLayer()
			layer.frame = bounds
			layer.path = UIBezierPath(arcCenter: center, radius: radius,
									  startAngle: 0, endAngle: .pi * 1.55, clockwise: true).cgPath
			layer.fillColor = UIColor.clear.cgColor
			layer.strokeColor = UIColor(red: 0.82, green: 0.62, blue: 1, alpha: 0.95 - CGFloat(i) * 0.25).cgColor
			layer.lineWidth = 4
			layer.lineCap = .round

			self.layer.addSublayer(layer)
			ringLayers.append(layer)
		}

		let core = maxRadius * 0.16
		coreLayer.frame = bounds
		coreLayer.path = UIBezierPath(ovalIn: CGRect(x: center.x - core, y: center.y - core,
													 width: core * 2, height: core * 2)).cgPath
		coreLayer.fillColor = UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1).cgColor
		layer.addSublayer(coreLayer)

		if isAnimating {
			applyAnimations()
		}
	}

	func start() {
		isAnimating = true
		applyAnimations()
	}

	func stop() {
		isAnimating = false

		ringLayers.forEach { $0.removeAllAnimations() }
		coreLayer.removeAllAnimations()
	}

	private func applyAnimations() {
		for (i, ring) in ringLayers.enumerated() {
			let spin = CABasicAnimation(keyPath: "transform.rotation.z")
			spin.fromValue = 0
			spin.toValue = (i % 2 == 0 ? 1 : -1) * 2 * Double.pi
			spin.duration = 2.2 + Double(i) * 0.8
			spin.repeatCount = .infinity
			ring.add(spin, forKey: "spin")
		}

		let pulse = CABasicAnimation(keyPath: "transform.scale")
		pulse.fromValue = 0.85
		pulse.toValue = 1.25
		pulse.duration = 0.9
		pulse.autoreverses = true
		pulse.repeatCount = .infinity
		coreLayer.add(pulse, forKey: "pulse")
	}
}
