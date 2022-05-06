//
//  TabCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

protocol TabCellDelegate: AnyObject {
    func close(_ sender: TabCell)
}

class TabCell: UICollectionViewCell, UIGestureRecognizerDelegate {

    class var nib: UINib {
        return UINib(nibName: String(describing: self), bundle: Bundle(for: self))
    }

	static let reuseIdentifier = String(describing: TabCell.self)

    @IBOutlet weak var header: UIView!
    @IBOutlet weak var title: UILabel!

    @IBOutlet weak var preview: UIImageView!

    weak var delegate: TabCellDelegate?

	private lazy var panGr: UIPanGestureRecognizer = {
		let gr = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
		gr.delegate = self

		return gr
	}()

	override init(frame: CGRect) {
		super.init(frame: frame)

		setup()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

		setup()
	}


	// MARK: Actions

    @IBAction func close() {
        delegate?.close(self)
    }


	// MARK: UIGestureRecognizerDelegate

	/**
	First step: Allow scrolling gestures on the UICollectionView simultanously.
	*/
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

		return (gestureRecognizer == panGr && otherGestureRecognizer.view is UICollectionView)
			|| (gestureRecognizer.view is UICollectionView && otherGestureRecognizer == panGr)
	}

	/**
	Second step: Don't do our pan while the UICollectionView scroll is running simultanously.
	*/
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {

		return (gestureRecognizer == panGr && otherGestureRecognizer.view is UICollectionView)
	}


	// MARK: Private Methods

	private func setup() {
		layer.shadowColor = UIColor.black.cgColor
		layer.shadowOffset = CGSize(width: -1, height: 1)
		layer.shadowOpacity = 0.5
		layer.shadowRadius = 8
		layer.masksToBounds = false

		addGestureRecognizer(panGr)
	}

	private var originalCenter: CGPoint!

	@objc func pan(_ gr: UIPanGestureRecognizer) {
		let trans = gr.translation(in: self)

		switch gr.state {
		case .began:
			originalCenter = center

			// A close swipe always needs to be in the up direction.
			if trans.y < 0 {
				center = CGPoint(x: originalCenter.x + trans.x, y: originalCenter.y + trans.y)
			}
			else {
				// 3rd step: Cancel this recognizer, when swipe is down instead of up.
				// UICollectionView scroll should take over.
				panGr.isEnabled = false
				panGr.isEnabled = true
			}

		case .changed:
			center = CGPoint(x: originalCenter.x + trans.x, y: originalCenter.y + trans.y)

		case .ended:
			// Detect a close swipe, when tab was swiped completely over original position,
			// or over 0, for the first tab row.
			if center.y < max(0, originalCenter.y - bounds.height) {
				delegate?.close(self)
			}
			else {
				center = originalCenter
			}

		default:
			center = originalCenter
		}
	}
}
