//
//  CircuitNodeCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.12.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class CircuitNodeCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

    class var height: CGFloat {
        return 36
    }

	@IBOutlet weak var topLink: UIView!
	@IBOutlet weak var bottomLink: UIView!
	@IBOutlet weak var textLb: UILabel!
	
	@discardableResult
	func set(_ node: CircuitViewController.Node, isFirst: Bool = false, isLast: Bool = false) -> CircuitNodeCell {

		topLink.isHidden = isFirst
		bottomLink.isHidden = isLast

		let text = NSMutableAttributedString(string: node.title)

		if let ip = node.ip {
			text.append(NSAttributedString(string: " "))
			text.append(NSAttributedString(string: ip, attributes: [
				.foregroundColor: UIColor.systemGray]))
		}

		if let note = node.note {
			text.append(NSAttributedString(string: " "))
			text.append(NSAttributedString(string: note, attributes: [
				.foregroundColor: UIColor.accent ?? UIColor.systemPurple,
				.font: UIFont.systemFont(ofSize: textLb.font.pointSize, weight: .black)
			]))
		}

		textLb.attributedText = text

		return self
	}
}
