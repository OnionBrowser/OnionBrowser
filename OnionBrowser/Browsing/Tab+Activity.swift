//
//  Tab+Activity.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 26.11.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import MobileCoreServices
import UniformTypeIdentifiers

extension Tab: UIActivityItemSource {

	private var uti: UTType? {
		guard let id = try? downloadedFile?.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
			return nil
		}

		return UTType(id)
	}

	private var isImageOrAv: Bool {
		guard let uti = uti else {
			return false
		}

		return uti.conforms(to: .image) || uti.conforms(to: .audiovisualContent)
	}

	private var isDocument: Bool {
		guard let uti = uti else {
			return false
		}

		return uti.conforms(to: .data)
			&& !uti.conforms(to: .html)
			&& !uti.conforms(to: .xml)
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

		return (uti ?? .url).identifier
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
				webView?.layer.render(in: context)
			}
		}

		let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
		UIGraphicsEndImageContext()

		return thumbnail
	}
}
