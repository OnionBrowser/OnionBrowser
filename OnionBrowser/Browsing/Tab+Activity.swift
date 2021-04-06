//
//  Tab+Activity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 26.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import MobileCoreServices

extension Tab: UIActivityItemSource {

	private var uti: String? {
		return try? downloadedFile?.resourceValues(forKeys: [URLResourceKey.typeIdentifierKey]).typeIdentifier
	}

	private var isImageOrAv: Bool {
		if let uti = uti as CFString? {
			return UTTypeConformsTo(uti, kUTTypeImage)
				|| UTTypeConformsTo(uti, kUTTypeAudiovisualContent)
		}

		return false
	}

	private var isDocument: Bool {
		if let uti = uti as CFString? {
			return UTTypeConformsTo(uti, kUTTypeData)
				&& !UTTypeConformsTo(uti, kUTTypeHTML)
				&& !UTTypeConformsTo(uti, kUTTypeXML)
		}

		return false
	}



	func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
		if let file = downloadedFile,
			isImageOrAv || isDocument {
			return file
		}

		return url
	}

	func activityViewController(_ activityViewController: UIActivityViewController,
								itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {

		print("[\(String(describing: type(of: self)))] activityType=\(String(describing: activityType))")

		if let downloadedFile = downloadedFile,
			let activityType = activityType,
			(activityType == .print
				|| activityType == .markupAsPDF
				|| activityType == .mail
				|| activityType == .openInIBooks
				|| activityType == .airDrop
				|| activityType == .copyToPasteboard
				|| activityType == .saveToCameraRoll
				|| activityType.rawValue == "com.apple.DocumentManagerUICore.SaveToFiles" // iOS 14
				|| activityType.rawValue == "com.apple.CloudDocsUI.AddToiCloudDrive") {

			// Return local file URL -> The file will be loaded and shared from there
			// and it will use the correct file name.
			return downloadedFile
		}

		if activityType == .message && isImageOrAv {
			return downloadedFile
		}

		return url
	}

	func activityViewController(_ activityViewController: UIActivityViewController,
								subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
		return title
	}

	func activityViewController(_ activityViewController: UIActivityViewController,
								dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {

		return uti ?? kUTTypeURL as String
	}

	func activityViewController(_ activityViewController: UIActivityViewController,
								thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
								suggestedSize size: CGSize) -> UIImage? {

		UIGraphicsBeginImageContext(size)

		if let context = UIGraphicsGetCurrentContext() {
			if downloadedFile != nil {
				previewController?.view.layer.render(in: context)
			}
			else {
				webView.layer.render(in: context)
			}
		}

		let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		return thumbnail
	}
}
