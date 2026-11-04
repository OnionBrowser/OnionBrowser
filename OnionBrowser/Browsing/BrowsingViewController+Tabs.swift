//
//  BrowsingViewController+Tabs.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright © 2012 - 2024, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension BrowsingViewController: UICollectionViewDataSource, UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate,
UICollectionViewDropDelegate, TabCellDelegate {

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return tabsCollection?.isHidden ?? true ? .default : .lightContent
	}


	private var cellSize: CGSize {
		let size = UIScreen.main.bounds.size

		// Could be 0 or less, so secure against becoming negative with minimum width of smallest iOS device.
		let width = (min(max(320, size.width), max(320, size.height)) - 8 * 2 /* left and right inset */) / 2 - 8 /* spacing */

		// Tall cards, like in Safari.
		return CGSize(width: width, height: width * 1.3)
	}

	private var overviewBackground: UIColor {
		UIColor(red: 0.08, green: 0.02, blue: 0.16, alpha: 1)
	}


	@objc func showOverview() {
		unfocusSearchField()

		// Reset before showing the overview. Would become cumbersome,
		// if we'd call everywhere, where a tab might change.
		for tab in tabs {
			tab.clearSnapshot()
		}

		self.tabsCollection?.reloadData()

		view.backgroundColor = overviewBackground
		tabsCollection?.backgroundColor = .clear

		styleTabsTools()

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar?.isHidden = true
			self.progress?.isHidden = true
			self.container?.isHidden = true
			self.tabsCollection?.isHidden = false
			self.mainTools?.isHidden = true
			self.tabsTools?.isHidden = false
		})
	}

	@objc func newTabFromOverview() {
		addNewTab(transition: .notAnimated) { _ in
			self.hideOverview() { _ in
				self.searchFl?.becomeFirstResponder()
			}
		}
	}

	@objc func hideOverview() {
		hideOverview(completion: nil)
	}


	// MARK: UICollectionViewDataSource

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return tabsCollection?.isHidden ?? true ? 0 : tabs.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier, for: indexPath)

		if let cell = cell as? TabCell {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row > -1 && indexPath.row < tabs.count {
				let tab = tabs[indexPath.row]

				// Semi-transparent, so the glass effect of the header stays visible.
				cell.header.backgroundColor = tab == currentTab
					? UIColor(red: 0.55, green: 0.17, blue: 0.96, alpha: 0.6)
					: UIColor(red: 0.10, green: 0.03, blue: 0.20, alpha: 0.6)
				cell.title.text = tab.title

				var size = cellSize
				size.height -= 24 // header height
				cell.preview.image = tab.getSnapshot(size: size)

				tab.isHidden = false
			}

			cell.delegate = self
		}

		return cell
	}

	
	// MARK: UICollectionViewDelegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		// Crash reports show, that indexPath.row can sometimes be different then
		// the real size of `tabs`. No idea why that race condition happens, but
		// we should at least not crash, if so.
		if indexPath.row > -1 && indexPath.row < tabs.count {
			currentTab = tabs[indexPath.row]
			hideOverview(completion: nil)
		}
	}

	// MARK: UICollectionViewDelegateFlowLayout

	func collectionView(_ collectionView: UICollectionView, layout
		collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return cellSize
	}


	// MARK: UICollectionViewDragDelegate

	func collectionView(_ collectionView: UICollectionView, itemsForBeginning
		session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {

		let tab = tabs[indexPath.row]

		let dragItem = UIDragItem(itemProvider: NSItemProvider(object: tab.url.absoluteString as NSString))
		dragItem.localObject = tab

		return [dragItem]
	}


	// MARK: UICollectionViewDropDelegate

	func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate
		session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?)
		-> UICollectionViewDropProposal {

			if tabsCollection?.hasActiveDrag ?? false {
				return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
			}

			return UICollectionViewDropProposal(operation: .forbidden)
	}

	func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
		if coordinator.proposal.operation == .move,
			let item = coordinator.items.first,
			let source = item.sourceIndexPath,
			let destination = coordinator.destinationIndexPath {

			collectionView.performBatchUpdates({
				let tab = tabs.remove(at: source.row)
				tabs.insert(tab, at: destination.row)
				currentTab = tab

				collectionView.deleteItems(at: [source])
				collectionView.insertItems(at: [destination])
			})

			coordinator.drop(item.dragItem, toItemAt: destination)
		}
	}


	// MARK: TabCellDelegate

	func close(_ sender: TabCell) {
		if let indexPath = tabsCollection?.indexPath(for: sender), indexPath.row > -1 {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row < tabs.count {
				tabsCollection?.performBatchUpdates({
					removeTab(tabs[indexPath.row])

					tabsCollection?.deleteItems(at: [indexPath])
				})
			}
		}
	}


	// MARK: Private Methods

	private func styleTabsTools() {
		let tools: UIView? = tabsTools

		guard let bar = tools as? UIToolbar else {
			return
		}

		bar.tintColor = UIColor(red: 0.85, green: 0.70, blue: 1, alpha: 1)

		// On iOS 26 and newer the system draws its own glass bar. Leave that alone.
		if #unavailable(iOS 26.0) {
			let appearance = UIToolbarAppearance()
			appearance.configureWithTransparentBackground()
			appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
			appearance.backgroundColor = UIColor(red: 0.16, green: 0.04, blue: 0.32, alpha: 0.35)

			bar.standardAppearance = appearance
			bar.scrollEdgeAppearance = appearance
			bar.compactAppearance = appearance
		}
	}

	private func hideOverview(completion: ((_ finished: Bool) -> Void)?) {
		for tab in tabs {
			tab.isHidden = tab != currentTab
		}

		updateChrome()

		self.view.backgroundColor = .systemBackground

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar?.isHidden = false
			self.tabsCollection?.isHidden = true
			self.container?.isHidden = false
			self.tabsTools?.isHidden = true
			self.mainTools?.isHidden = false
		}, completion)
	}
}
