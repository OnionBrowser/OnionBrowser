//
//  TabCell.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
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

	private static let cornerRadius: CGFloat = 20

	@IBOutlet weak var header: UIView!
	@IBOutlet weak var title: UILabel!

	@IBOutlet weak var preview: UIImageView!

	weak var delegate: TabCellDelegate?

	private let glass = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

	private let closeButton = CloseButton(type: .system)

	private let nameLabel = UILabel()

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

	override func awakeFromNib() {
		super.awakeFromNib()

		styleCell()
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Self.cornerRadius).cgPath
	}

	/**
	While the system drag (tab reordering) is running, our own swipe-to-close must stay out of the way.
	*/
	override func dragStateDidChange(_ dragState: UICollectionViewCell.DragState) {
		super.dragStateDidChange(dragState)

		panGr.isEnabled = dragState == .none
	}


	// MARK: Public Methods

	func setName(_ text: String?) {
		nameLabel.text = text
		title?.text = text
	}


	// MARK: Actions

	@IBAction func close() {
		delegate?.close(self)
	}


	// MARK: UIGestureRecognizerDelegate

	/**
	First step: Allow scrolling gestures on the UICollectionView simultanously.
	Only the scroll pan is meant here, not the long press which lifts a tab for reordering.
	*/
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {

		return (gestureRecognizer == panGr && otherGestureRecognizer.view is UICollectionView && otherGestureRecognizer is UIPanGestureRecognizer)
			|| (gestureRecognizer.view is UICollectionView && gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer == panGr)
	}

	/**
	Second step: Don't do our pan while the UICollectionView scroll is running simultanously.
	*/
	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {

		return gestureRecognizer == panGr && otherGestureRecognizer.view is UICollectionView && otherGestureRecognizer is UIPanGestureRecognizer
	}


	// MARK: Private Methods

	private func setup() {
		// Purple glow instead of a plain black shadow.
		layer.shadowColor = UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 1).cgColor
		layer.shadowOffset = CGSize(width: 0, height: 6)
		layer.shadowOpacity = 0.45
		layer.shadowRadius = 14
		layer.masksToBounds = false

		addGestureRecognizer(panGr)
	}

	private func styleCell() {
		contentView.backgroundColor = UIColor(red: 0.10, green: 0.03, blue: 0.20, alpha: 1)
		contentView.layer.cornerRadius = Self.cornerRadius
		contentView.layer.cornerCurve = .continuous
		contentView.layer.masksToBounds = true
		contentView.layer.borderWidth = 1
		contentView.layer.borderColor = UIColor(red: 0.77, green: 0.55, blue: 1, alpha: 0.35).cgColor

		preview?.contentMode = .scaleAspectFill
		preview?.clipsToBounds = true

		if let header = header {
			// Glass header.
			header.backgroundColor = .clear

			glass.frame = header.bounds
			glass.autoresizingMask = [.flexibleWidth, .flexibleHeight]
			glass.isUserInteractionEnabled = false
			header.insertSubview(glass, at: 0)

			// Hide the close button and title from the layout file, we use our own.
			for button in header.subviews.compactMap({ $0 as? UIButton }) {
				button.isHidden = true
			}

			title?.isHidden = true

			// Small round close button with an outline, like in macOS.
			var config = UIButton.Configuration.plain()
			config.image = UIImage(systemName: "xmark",
								   withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .heavy))
			config.baseForegroundColor = UIColor(red: 0.92, green: 0.86, blue: 1, alpha: 1)
			config.contentInsets = .zero

			var background = UIBackgroundConfiguration.clear()
			background.backgroundColor = UIColor.white.withAlphaComponent(0.12)
			background.cornerRadius = 9
			background.strokeColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 0.75)
			background.strokeWidth = 1
			config.background = background

			closeButton.configuration = config
			closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
			closeButton.translatesAutoresizingMaskIntoConstraints = false
			header.addSubview(closeButton)

			nameLabel.font = .systemFont(ofSize: 13, weight: .semibold)
			nameLabel.textColor = .white
			nameLabel.lineBreakMode = .byTruncatingTail
			nameLabel.numberOfLines = 1
			nameLabel.translatesAutoresizingMaskIntoConstraints = false
			header.addSubview(nameLabel)

			NSLayoutConstraint.activate([
				closeButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -10),
				closeButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
				closeButton.widthAnchor.constraint(equalToConstant: 18),
				closeButton.heightAnchor.constraint(equalToConstant: 18),

				nameLabel.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 12),
				nameLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
				nameLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor)
			])
		}
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
			if originalCenter != nil {
				center = originalCenter
			}
		}
	}
}


/// A close button with a bigger touch area than its small round look.
private final class CloseButton: UIButton {

	override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
		return bounds.insetBy(dx: -14, dy: -14).contains(point)
	}
}
