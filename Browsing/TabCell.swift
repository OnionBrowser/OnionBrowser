//
//  TabCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

protocol TabCellDelegate {
    func close(tabCell: TabCell)
}

class TabCell: UICollectionViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

	static let reuseIdentifier = String(describing: self)

    @IBOutlet weak var title: UILabel!

    @IBOutlet weak var container: UIView!

    var delegate: TabCellDelegate?

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}

    @IBAction func close() {
        delegate?.close(tabCell: self)
    }


	// MARK: Private Methods

	private func setup() {
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOffset = CGSize(width: -1, height: 1)
		layer.shadowOpacity = 0.5
		layer.shadowRadius = 8
		layer.masksToBounds = false
	}
}
