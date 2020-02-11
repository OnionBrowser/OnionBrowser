//
//  FileManager+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.02.20.
//  Copyright © 2020 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import Foundation

extension FileManager {

	var groupFolder: URL? {
		return containerURL(forSecurityApplicationGroupIdentifier: Config.groupId)
	}

	var logfile: URL? {
		return groupFolder?.appendingPathComponent("log")
	}

	var log: String? {
		if let logfile = logfile {
			return try? String(contentsOf: logfile)
		}

		return nil
	}
}
