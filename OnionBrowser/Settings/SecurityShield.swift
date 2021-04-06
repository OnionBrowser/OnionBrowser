//
//  SecurityShield.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 17.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SecurityShield: UIView {

	let preset: SecurityPreset

	var isSelected = false {
		didSet {
			if isSelected {
				button.backgroundColor = .ok
				button.text = "\u{2713}" // Checkmark
			}
			else {
				button.backgroundColor = .clear
				button.text = nil
			}
		}
	}

	private lazy var shield: UIImageView = {
		let view = UIImageView(image: UIImage(named: "shield"))

		view.tintColor = .accent

		view.translatesAutoresizingMaskIntoConstraints = false

		view.widthAnchor.constraint(equalToConstant: 31 * 1.5).isActive = true
		view.heightAnchor.constraint(equalToConstant: 39 * 1.5).isActive = true

		return view
	}()

	private lazy var number: UILabel = {
		let view = UILabel()

		view.font = .systemFont(ofSize: 26, weight: .black)
		view.textColor = .white
		view.textAlignment = .center

		view.translatesAutoresizingMaskIntoConstraints = false

		return view
	}()

	private lazy var title: UILabel = {
		let view = UILabel()

		view.font = .systemFont(ofSize: 14)
		view.textColor = .systemGray
		view.textAlignment = .center
		view.adjustsFontSizeToFitWidth = true
		view.minimumScaleFactor = 0.5
		view.allowsDefaultTighteningForTruncation = true

		view.translatesAutoresizingMaskIntoConstraints = false

		return view
	}()

	private lazy var button: UILabel = {
		let view = UILabel()

		view.translatesAutoresizingMaskIntoConstraints = false

		view.layer.borderColor = UIColor.accent?.cgColor
		view.layer.cornerRadius = 12
		view.layer.borderWidth = 1
		view.clipsToBounds = true

		view.textColor = .white
		view.textAlignment = .center

		view.widthAnchor.constraint(equalToConstant: 24).isActive = true
		view.heightAnchor.constraint(equalToConstant: 24).isActive = true

		return view
	}()


	init(_ preset: SecurityPreset) {
		self.preset = preset

		super.init(frame: .zero)

		shield.tintColor = preset.color
		number.text = preset.shortcode

		title.text = preset.description

		addSubview(shield)
		shield.topAnchor.constraint(equalTo: topAnchor).isActive = true
		shield.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		shield.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

		shield.addSubview(number)
		number.centerXAnchor.constraint(equalTo: shield.centerXAnchor).isActive = true
		number.centerYAnchor.constraint(equalTo: shield.centerYAnchor).isActive = true

		addSubview(title)
		title.topAnchor.constraint(equalTo: shield.bottomAnchor, constant: 4).isActive = true
		title.leadingAnchor.constraint(equalTo: leadingAnchor).isActive = true
		title.trailingAnchor.constraint(equalTo: trailingAnchor).isActive = true

		addSubview(button)
		button.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4).isActive = true
		button.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
		button.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
	}

	required init?(coder: NSCoder) {
		preset = coder.decodeObject(forKey: "preset") as? SecurityPreset ?? .secure

		super.init(coder: coder)
	}

	override func encode(with coder: NSCoder) {
		coder.encode(preset, forKey: "preset")

		super.encode(with: coder)
	}
}
