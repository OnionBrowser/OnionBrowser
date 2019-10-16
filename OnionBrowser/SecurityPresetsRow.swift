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
			return NSLocalizedString("Medium", comment: "Security level")

		case .secure:
			return NSLocalizedString("Secure", comment: "Security level")

		default:
			return NSLocalizedString("Custom", comment: "Security level")
		}
	}

	var values: (csp: String, webRtc: Bool, mixedMode: Bool)? {
		switch self {
		case .insecure:
			return (HOST_SETTINGS_CSP_OPEN, true, true)

		case .medium:
			return (HOST_SETTINGS_CSP_BLOCK_CONNECT, false, false)

		case .secure:
			return (HOST_SETTINGS_CSP_STRICT, false, false)

		default:
			return nil
		}
	}

	case custom = -1
	case insecure = 0
	case medium = 1
	case secure = 2

	init(_ csp: String?, _ webRtc: Bool?, _ mixedMode: Bool?) {
		let webRtc = webRtc ?? false
		let mixedMode = mixedMode ?? false

		if csp == HOST_SETTINGS_CSP_OPEN && webRtc && mixedMode {
			self = .insecure
		}
		else if csp == HOST_SETTINGS_CSP_BLOCK_CONNECT && !webRtc && !mixedMode {
			self = .medium
		}
		else if csp == HOST_SETTINGS_CSP_STRICT && !webRtc && !mixedMode {
			self = .secure
		}
		else {
			self = .custom
		}
	}

	init(_ settings: HostSettings?) {
		self = .init(settings?.settingOrDefault(HOST_SETTINGS_KEY_CSP),
					 settings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_WEBRTC),
					 settings?.boolSettingOrDefault(HOST_SETTINGS_KEY_ALLOW_MIXED_MODE))
	}
}

class SecurityPresetsCell: Cell<SecurityPreset>, CellType {

    @IBOutlet weak var radio: UISegmentedControl!

    @IBAction func valueChanged(_ sender: UISegmentedControl) {
        row.value = SecurityPreset(rawValue: sender.selectedSegmentIndex)
        row.updateCell()
    }

    public override func update() {
        super.update()

		radio.selectedSegmentIndex = row.value?.rawValue ?? SecurityPreset.custom.rawValue > SecurityPreset.custom.rawValue
			? row.value!.rawValue
			: UISegmentedControl.noSegment
	}
}

final class SecurityPresetsRow: Row<SecurityPresetsCell>, RowType {

    required init(tag: String?) {
        super.init(tag: tag)

        cellProvider = CellProvider<SecurityPresetsCell>(nibName: String(describing: SecurityPresetsCell.self))
    }
}
