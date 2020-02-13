//
//  BookmarkCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 19.12.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit

class BookmarkCell: UITableViewCell {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

    class var reuseId: String {
        return String(describing: self)
    }

	class var height: CGFloat {
		return 44
	}

	@IBOutlet weak var iconImg: UIImageView!
    @IBOutlet weak var iconWidth: NSLayoutConstraint!
    @IBOutlet weak var nameLb: UILabel!
    @IBOutlet weak var nameLeading: NSLayoutConstraint!


	func set(_ bookmark: Bookmark) -> BookmarkCell {
		iconImg.image = bookmark.icon

		if iconImg.image == nil {
            iconWidth.constant = 0
            nameLeading.constant = 0
		}
        else {
            iconWidth.constant = 32
            nameLeading.constant = 8
        }

		nameLb.text = bookmark.name?.isEmpty ?? true
			? bookmark.url?.absoluteString
			: bookmark.name

		return self
	}
}
