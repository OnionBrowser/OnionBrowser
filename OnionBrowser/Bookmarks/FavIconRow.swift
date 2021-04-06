//
//  FavIconRow.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 17.01.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import ImageRow

public final class FavIconCell: PushSelectorCell<UIImage> {

	@IBOutlet weak var icon: UIImageView!
	@IBOutlet weak var editableIndicator: UIImageView!

	public override func update() {
		super.update()

		accessoryType = .none
		editingAccessoryView = .none

		icon.image = row.value ?? (row as? ImageRowProtocol)?.placeholderImage
		editableIndicator.isHidden = row.isDisabled
	}
}

final class FavIconRow: _ImageRow<FavIconCell>, RowType {

	required init(tag: String?) {
		super.init(tag: tag)

		cellProvider = CellProvider<FavIconCell>(nibName: String(describing: FavIconCell.self))
	}
}
