//
//  DownloadHelper.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 28.07.22.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//


import Foundation

class DownloadHelper {

	private static let directory = FileManager.default.temporaryDirectory
		.appendingPathComponent("downloads", isDirectory: true)


	class func getDirectory() -> URL? {
		// Create directory, if it doesn't exist.
		if !directory.exists {
			do {
				try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
			}
			catch {
				print("[\(String(describing: self))]#getDirectory error=\(error)")

				return nil
			}
		}

		return directory
	}

	class func purge() {
		try? FileManager.default.removeItem(at: directory)
	}
}
