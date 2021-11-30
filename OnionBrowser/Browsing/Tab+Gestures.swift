//
//  Tab+Gestures.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 27.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import IPtProxyUI

extension Tab: UIGestureRecognizerDelegate {

	func setupGestureRecognizers() {
		let isRtl = UIView.userInterfaceLayoutDirection(for: webView.semanticContentAttribute) == .rightToLeft

		// Swipe to go back one page.
		let swipeBack = UISwipeGestureRecognizer(target: self, action: #selector(goBack))
		swipeBack.direction = isRtl ? .left : .right
		swipeBack.delegate = self
		webView.addGestureRecognizer(swipeBack)

		// Swipe to go forward one page.
		let swipeForward = UISwipeGestureRecognizer(target: self, action: #selector(goForward))
		swipeForward.direction = isRtl ? .right : .left
		swipeForward.delegate = self
		webView.addGestureRecognizer(swipeForward)

		// Long press to show context menu.
		let longPress = UILongPressGestureRecognizer(target: self, action: #selector(showContextMenu(_:)))
		longPress.delegate = self
		webView.addGestureRecognizer(longPress)

		// Hard long press to immediately open link or image in a new tab.
		let forceTouch = VForceTouchGestureRecognizer(target: self, action: #selector(openInNewTab(_:)))
		forceTouch.percentMinimalRequest = 0.4
		forceTouch.delegate = self
		webView.addGestureRecognizer(forceTouch)

		// Pull down to refresh.
		refresher.addTarget(self, action: #selector(refresherTriggered), for: .valueChanged)
		scrollView.addSubview(refresher)
	}


	// MARK: UIGestureRecognizerDelegate

	func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith
		otherGestureRecognizer: UIGestureRecognizer) -> Bool {

		if !(gestureRecognizer is UILongPressGestureRecognizer) {
			return false
		}

		if gestureRecognizer.state != .began {
			return true
		}

		let (href, img, _) = analyzeTappedElements(gestureRecognizer)

		if href != nil || img != nil {
			// This is enough to cancel the touch when the long press gesture fires,
			// so that the link being held down doesn't activate as a click once
			// the finger is let up.
			if otherGestureRecognizer is UILongPressGestureRecognizer {
				otherGestureRecognizer.isEnabled = false
				otherGestureRecognizer.isEnabled = true
			}

			return true
		}

		return false
	}


	// MARK: Private Methods

	@objc
	private func showContextMenu(_ gr: UIGestureRecognizer) {
		// Otherwise this will be uselessly called multiple times.
		guard gr.state == .began else {
			return
		}

		let (href, img, message) = analyzeTappedElements(gr)

		if href == nil && img == nil {
			gr.isEnabled = false // Cancels the gesture recognizer.
			gr.isEnabled = true

			return
		}

		let menu = UIAlertController(title: message.isEmpty ? nil : message,
									 message: (href ?? img)?.absoluteString,
									 preferredStyle: .actionSheet)

		if href != nil || img != nil {
			let url = href ?? img

			menu.addAction(UIAlertAction(
				title: NSLocalizedString("Open", comment: ""),
				style: .default,
				handler: { _ in
					self.load(url)
			}))

			menu.addAction(UIAlertAction(
				title: NSLocalizedString("Open in a New Tab", comment: ""),
				style: .default,
				handler: { _ in
					let child = self.tabDelegate?.addNewTab(url)
					child?.parentId = self.hash
			}))

			menu.addAction(UIAlertAction(
				title: NSLocalizedString("Open in Background Tab", comment: ""),
				style: .default,
				handler: { _ in
					let child = self.tabDelegate?.addNewTab(
						url, forRestoration: false, transition: .inBackground, completion: nil)
					child?.parentId = self.hash
			}))

			menu.addAction(UIAlertAction(
				title: NSLocalizedString("Open in Safari", comment: ""),
				style: .default,
				handler: { _ in
					if let url = url {
						UIApplication.shared.open(url, options: [:], completionHandler: nil)
					}
			}))
		}

		if img != nil {
			menu.addAction(UIAlertAction(
				title: NSLocalizedString("Save Image", comment: ""),
				style: .default,
				handler: { _ in
					JAHPAuthenticatingHTTPProtocol.temporarilyAllow(img, forWebViewTab: self)

					let task = URLSession.shared.dataTask(with: img!) { data, response, error in
						if let data = data,
							let image = UIImage(data: data) {

							UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
						}
						else {
							DispatchQueue.main.async {
								let alert = AlertHelper.build(
									message: String(format:
										NSLocalizedString("An error occurred downloading image %@", comment: ""),
													img!.absoluteString))

								self.tabDelegate?.present(alert, nil)
							}
						}
					}

					task.resume()
			}))
		}

		menu.addAction(UIAlertAction(
			title: NSLocalizedString("Copy URL", comment: ""), style: .default,
			handler: { _ in
				UIPasteboard.general.string = (href ?? img)?.absoluteString
		}))

		menu.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""),
									 style: .cancel, handler: nil))

		let point = gr.location(in: gr.view)

		menu.popoverPresentationController?.sourceView = gr.view
		menu.popoverPresentationController?.sourceRect = CGRect(
			x: point.x + 35, // Offset for width of the finger.
			y: point.y, width: 1, height: 1)

		tabDelegate?.present(menu, nil)
	}

	@objc
	private func openInNewTab(_ gr: VForceTouchGestureRecognizer) {
		// Otherwise this will be uselessly called multiple times.
		guard gr.state == .began else {
			return
		}

		// Taptic feedback.
		let feedback = UINotificationFeedbackGenerator()
		feedback.prepare()
		feedback.notificationOccurred(.success)

		let (href, img, _) = analyzeTappedElements(gr)

		if let url = href ?? img {
			let child = tabDelegate?.addNewTab(url)
			child?.parentId = hash
		}
	}

	@objc
	private func refresherTriggered() {
		refresh()

		// Delay just so it confirms to the user that something happened.
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			self.refresher.endRefreshing()
		}
	}

	private func analyzeTappedElements(_ gr: UIGestureRecognizer) -> (href: URL?, img: URL?, title: String) {
		var tap = gr.location(in: webView)
		tap.y -= scrollView.contentInset.top

		var elements = NSArray()

		// Translate tap coordinates from view to scale of page.
		if let innerWidth = stringByEvaluatingJavaScript(from: "window.innerWidth"),
			let width = Int(innerWidth),
			let innerHeight = stringByEvaluatingJavaScript(from: "window.innerHeight"),
			let height = Int(innerHeight) {

			let windowSize = CGSize(width: width, height: height)

			let viewSize = webView.frame.size
			let ratioX = windowSize.width / viewSize.width
			let ratioY = windowSize.height / viewSize.height
			let tapOnPage = CGPoint(x: tap.x * ratioX, y: tap.y * ratioY)

			// Now find, if there are usable elements at those coordinates and extract their attributes.
			if let json = stringByEvaluatingJavaScript(from: "JSON.stringify(__endless.elementsAtPoint(\(tapOnPage.x), \(tapOnPage.y)));"),
				let data = json.data(using: .utf8),
				let array = try? JSONSerialization.jsonObject(with: data, options: []) as? NSArray {

				elements = array
			}
		}

		var href = ""
		var img = ""
		var title = ""

		for element in elements {
			guard let element = element as? NSDictionary,
				let k = element.allKeys.first as? String,
				let attrs = element.object(forKey: k) as? NSDictionary
			else {
				continue
			}

			if k == "a" {
				href = attrs.object(forKey: "href") as? String ?? ""

				// Only use if image title is blank.
				if title.isEmpty {
					title = attrs.object(forKey: "title") as? String ?? ""
				}
			}
			else if k == "img" {
				img = attrs.object(forKey: "src") as? String ?? ""

				title = attrs.object(forKey: "title") as? String ?? ""

				if title.isEmpty {
					title = attrs.object(forKey: "alt") as? String ?? ""
				}
			}
		}

		return (href: href.isEmpty ? nil : URL(string: href),
				img: img.isEmpty ? nil : URL(string: img),
				title: title)
	}
}
