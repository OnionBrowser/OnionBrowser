//
//  BrowsingViewController+Tabs.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 31.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension BrowsingViewController: UICollectionViewDataSource, UICollectionViewDelegate,
UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate,
UICollectionViewDropDelegate, TabCellDelegate {

	override var preferredStatusBarStyle: UIStatusBarStyle {
		return tabsCollection?.isHidden ?? true ? .default : .lightContent
	}

	@objc func showOverview() {
		unfocusSearchField()

		self.tabsCollection.reloadData()

		view.backgroundColor = .darkGray

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar.isHidden = true
			self.progress.isHidden = true
			self.container.isHidden = true
			self.tabsCollection.isHidden = false
			self.mainTools?.isHidden = true
			self.tabsTools.isHidden = false
		})
	}

	@objc func newTabFromOverview() {
		addNewTab(transition: .notAnimated) { _ in
			self.hideOverview() { _ in
				self.searchFl.becomeFirstResponder()
			}
		}
	}

	@objc func hideOverview() {
		hideOverview(completion: nil)
	}

	private func cellSize() -> CGSize {
		let size = UIScreen.main.bounds.size

		// Could be 0 or less, so secure against becoming negative with minimum width of smallest iOS device.
		let width = (min(max(320, size.width), max(320, size.height)) - 8 * 2 /* left and right inset */) / 2 - 8 /* spacing */

		return CGSize(width: width, height: width / 4 * 3)
	}
	
	// MARK: UICollectionViewDataSource

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return tabsCollection.isHidden ? 0 : tabs.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabCell.reuseIdentifier, for: indexPath)

		if let cell = cell as? TabCell {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row > -1 && indexPath.row < tabs.count {
				let tab = tabs[indexPath.row]

				cell.title.text = tab.title
								
				cell.preview.image = tab.snapshot?.topCropped(newSize: cellSize())
				tab.isHidden = false
			}

			cell.delegate = self
		}

		return cell
	}

	
	// MARK: UICollectionViewDelegate

	func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		currentTab = tabs[indexPath.row]
		hideOverview(completion: nil)
	}

	// MARK: UICollectionViewDelegateFlowLayout

	func collectionView(_ collectionView: UICollectionView, layout
		collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		return cellSize()
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

			if tabsCollection.hasActiveDrag {
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
		if let indexPath = tabsCollection.indexPath(for: sender), indexPath.row > -1 {

			// Crash reports show, that indexPath.row can sometimes be different then
			// the real size of `tabs`. No idea why that race condition happens, but
			// we should at least not crash, if so.
			if indexPath.row < tabs.count {
				removeTab(tabs[indexPath.row])
			}

			tabsCollection.performBatchUpdates({
				tabsCollection.deleteItems(at: [indexPath])
			})
		}
	}


	// MARK: Private Methods

	private func hideOverview(completion: ((_ finished: Bool) -> Void)?) {
		currentTab?.resetSnapshot()
		// UIViews can only ever have one superview. Move back from tabsCollection to container now.
		for tab in tabs {
			tab.isHidden = tab != currentTab
			tab.add(to: container)
		}

		updateChrome()

		if #available(iOS 13.0, *) {
			self.view.backgroundColor = .systemBackground
		}
		else {
			self.view.backgroundColor = .white
		}

		UIView.animate(withDuration: 0.5, animations: {
			self.view.setNeedsLayout()
		}) { _ in
			self.setNeedsStatusBarAppearanceUpdate()
		}

		view.transition({
			self.searchBar.isHidden = false
			self.tabsCollection.isHidden = true
			self.container.isHidden = false
			self.tabsTools.isHidden = true
			self.mainTools?.isHidden = false
		}, completion)
	}
}
