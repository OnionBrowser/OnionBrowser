//
//  Tab+Downloads.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.11.19.
//  Copyright © 2012 - 2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import QuickLook
import WebKit

extension Tab: WKDownloadDelegate, QLPreviewControllerDelegate, QLPreviewControllerDataSource {

	/**
	Should be called whenever navigation occurs or
	when the WebViewTab is being closed.
	*/
	func cancelDownload() {
		if downloadedFile != nil {
			// Delete the temporary file.
			try? FileManager.default.removeItem(at: downloadedFile!)

			downloadedFile = nil
		}

		if previewController != nil {
			previewController?.view.removeFromSuperview()
			previewController?.removeFromParent()
			previewController = nil
		}

		overlay.removeFromSuperview()
	}


	// MARK: WKDownloadDelegate

	func download(_ download: WKDownload, decideDestinationUsing response: URLResponse,
				  suggestedFilename: String, completionHandler: @escaping (URL?) -> Void)
	{
		guard let dir = DownloadHelper.getDirectory() else {
			downloadedFile = nil
			completionHandler(nil)

			return
		}

		downloadedFile = dir.appendingPathComponent(suggestedFilename, isDirectory: false)

		// Remove old file, if it does exist.
		if downloadedFile?.exists ?? false {
			try? FileManager.default.removeItem(at: downloadedFile!)
		}

		completionHandler(downloadedFile)
	}

	func download(_ download: WKDownload, didReceive challenge: URLAuthenticationChallenge,
				  completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void)
	{
		webView(webView, didReceive: challenge) { disposition, credential in
			completionHandler(disposition, credential)
		}
	}

	func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
		print(error)
	}

	func downloadDidFinish(_ download: WKDownload) {
		DispatchQueue.main.async {
			if self.downloadedFile?.exists ?? false {
				self.showDownload()
			}
		}
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

		sceneDelegate?.browsingUi.addChild(previewController!)

		previewController?.view.add(to: self)

		previewController?.didMove(toParent: sceneDelegate?.browsingUi)

		// Positively show toolbar, as users can't scroll it back up.
		scrollView.delegate?.scrollViewDidScrollToTop?(scrollView)
	}
}
