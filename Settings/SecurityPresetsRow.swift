//
//  SecurityPresetsRow.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 16.10.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

enum SecurityPreset: Int, CustomStringConvertible {
	var description: String {
		switch self {
		case .insecure:
			return NSLocalizedString("Insecure", comment: "Security level")

		case .medium:
			return NSLocalizedString("Moderate", comment: "Security level")

		case .secure:
			return NSLocalizedString("Secure", comment: "Security level")

		default:
			return NSLocalizedString("Custom", comment: "Security level")
		}
	}

	var shortcode: String {
		switch self {
		case .insecure, .medium, .secure:
			return Formatter.localize(rawValue + 1)

		default:
			return description.first?.uppercased() ?? "C"
		}
	}

	var recommendation: String? {
		switch self {
		case .insecure:
			return NSLocalizedString("(not recommended)", comment: "")

		case .medium:
			return NSLocalizedString("(recommended)", comment: "")

		default:
			return nil
		}
	}

	var explanation: String {
		switch self {
		case .insecure:
			return NSLocalizedString("Everything should work.", comment: "")

		case .medium:
			return NSLocalizedString("Some things won't work.", comment: "")

		case .secure:
			return NSLocalizedString("Many things won't work.", comment: "")

		default:
			return NSLocalizedString("Settings have been customized.", comment: "")
		}
	}

	var values: (csp: HostSettings.ContentPolicy, webRtc: Bool, mixedMode: Bool)? {
		switch self {
		case .insecure:
			return (.open, true, true)

		case .medium:
			return (.blockXhr, false, false)

		case .secure:
			return (.strict, false, false)

		default:
			return nil
		}
	}

	case custom = -1
	case insecure = 0
	case medium = 1
	case secure = 2

	init(_ csp: HostSettings.ContentPolicy?, _ webRtc: Bool?, _ mixedMode: Bool?) {
		let webRtc = webRtc ?? false
		let mixedMode = mixedMode ?? false

		if csp == .open && webRtc && mixedMode {
			self = .insecure
		}
		else if csp == .blockXhr && !webRtc && !mixedMode {
			self = .medium
		}
		else if csp == .strict && !webRtc && !mixedMode {
			self = .secure
		}
		else {
			self = .custom
		}
	}

	init(_ settings: HostSettings?) {
		self = .init(settings?.contentPolicy,
					 settings?.webRtc,
					 settings?.mixedMode)
	}
}

class SecurityPresetsCell: Cell<SecurityPreset>, CellType {

	private lazy var shields: [SecurityShield] = {
		var shields = [SecurityShield]()

		for i in 0 ... 2 {
			if let preset = SecurityPreset(rawValue: i) {
				let shield = SecurityShield(preset)
				shield.translatesAutoresizingMaskIntoConstraints = false

				shields.append(shield)
			}
		}

		return shields
	}()

	@objc private func shieldSelected(_ sender: UITapGestureRecognizer) {
		let view = sender.view as? SecurityShield

		for shield in shields {
			if shield.isSelected && shield != view {
				shield.isSelected = false
			}
		}

		row.value = view?.preset
		row.updateCell()
	}

	override func setup() {
		super.setup()

		for shield in shields {
			addSubview(shield)

			shield.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(shieldSelected(_:))))
			
			shield.topAnchor.constraint(equalTo: topAnchor, constant: 32).isActive = true
			shield.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -32).isActive = true
		}

		shields.first?.trailingAnchor.constraint(equalTo: shields[1].leadingAnchor, constant: -48).isActive = true
		shields[1].centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
		shields.last?.leadingAnchor.constraint(equalTo: shields[1].trailingAnchor, constant: 48).isActive = true

		selectionStyle = .none
	}

    public override func update() {
        super.update()

		for shield in shields {
			shield.isSelected = shield.preset == row.value
		}
	}
}

final class SecurityPresetsRow: Row<SecurityPresetsCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)

		cellStyle = .default

        cellProvider = CellProvider<SecurityPresetsCell>()
    }
}
