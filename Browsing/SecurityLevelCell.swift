//
//  SecurityLevelCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 13.12.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SecurityLevelCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

    class var height: CGFloat {
        return 64
    }


	override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    @IBOutlet weak var numberLb: UILabel!
    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var explanationLb: UILabel!
	@IBOutlet weak var radioLb: UILabel! {
		didSet {
			radioLb.layer.borderColor = UIColor.poeAccent?.cgColor
		}
	}

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        if selected {
            radioLb.backgroundColor = .poeOk
            radioLb.text = "\u{2713}" // Checkmark
        }
        else {
            radioLb.backgroundColor = .clear
            radioLb.text = nil
        }
    }

	@discardableResult
	func set(_ preset: SecurityPreset) -> SecurityLevelCell {

		numberLb.text = Formatter.localize(preset.rawValue + 1)

		let text = NSMutableAttributedString(string: preset.description)

		if let recommendation = preset.recommendation {
			let size = nameLb.font.pointSize - 2
			var font = UIFont.systemFont(ofSize: size, weight: .bold)

			if let descriptor = font.fontDescriptor.withSymbolicTraits([.traitItalic, .traitBold]) {
				font = UIFont(descriptor: descriptor, size: size)
			}

			text.append(NSAttributedString(string: " "))
			text.append(NSAttributedString(string: recommendation, attributes: [
				.font: font,
			]))
		}

		nameLb.attributedText = text

		explanationLb.text = preset.explanation

		return self
	}
}
