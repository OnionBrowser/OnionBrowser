//
//  CaptchaRow.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.03.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import ImageRow

public final class CaptchaCell: PushSelectorCell<UIImage> {

	@IBOutlet weak var captcha: UIImageView!

	public override func update() {
		super.update()

		accessoryType = .none
		editingAccessoryView = .none

		captcha.image = row.value ?? (row as? ImageRowProtocol)?.placeholderImage
	}
}

final class CaptchaRow: _ImageRow<CaptchaCell>, RowType {

	required init(tag: String?) {
		super.init(tag: tag)

		cellProvider = CellProvider<CaptchaCell>(nibName: String(describing: CaptchaCell.self))
	}
}
