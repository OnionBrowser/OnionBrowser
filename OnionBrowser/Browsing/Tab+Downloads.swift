//
//  Tab+Downloads.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import QuickLook

extension Tab: DownloadTaskDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource {

	/**
	Should be called whenever navigation occurs or
	when the WebViewTab is being closed.
	*/
	func cancelDownload() {
		if downloadedFile != nil {
			// Delete the temporary file.
			try? FileManager.default.removeItem(atPath: downloadedFile!.path)

			downloadedFile = nil
		}

		if previewController != nil {
			previewController?.view.removeFromSuperview()
			previewController?.removeFromParent()
			previewController = nil
		}

		overlay.removeFromSuperview()
	}


	// MARK: DownloadTaskDelegate

	func didStartDownloadingFile() {
		// Nothing to do here.
	}

	func didFinishDownloading(to location: URL?) {
		DispatchQueue.main.async {
			if location != nil {
				self.downloadedFile = location;
				self.showDownload()
			}
		}
	}

	func setProgress(_ pr: NSNumber?) {
		progress = pr?.floatValue ?? 0
	}


	// MARK: QLPreviewControllerDelegate

	func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
		return downloadedFile! as NSURL
	}


	// MARK: QLPreviewControllerDataSource

	func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
		return downloadedFile != nil ? 1 : 0
	}

	// MARK: Private Methods

	private func showDownload() {
		previewController = QLPreviewController()
		previewController?.delegate = self
		previewController?.dataSource = self

		AppDelegate.shared?.browsingUi?.addChild(previewController!)

		previewController?.view.add(to: self)

		previewController?.didMove(toParent: AppDelegate.shared?.browsingUi)

		// Positively show toolbar, as users can't scroll it back up.
		scrollView.delegate?.scrollViewDidScrollToTop?(scrollView)
	}
}
