#!/usr/bin/env xcrun --sdk macosx swift

//
//  update-bridges.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.12.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

// MARK: Config

let url = URL(string: "https://gitweb.torproject.org/builders/tor-browser-build.git/plain/projects/tor-browser/Bundle-Data/PTConfigs/bridge_prefs.js")!

let regex = try? NSRegularExpression(pattern: "\"(obfs4.+)\"", options: .caseInsensitive)


// MARK: Helper Methods

func exit(_ msg: String) {
	print(msg)
	exit(1)
}

func resolve(_ path: String) -> String {
	let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
	let script = URL(fileURLWithPath: CommandLine.arguments.first ?? "", relativeTo: cwd).deletingLastPathComponent()

	return URL(fileURLWithPath: path, relativeTo: script).path
}


// MARK: Main

let outfile = resolve("../Resources/obfs4-bridges.plist")

let modified = (try? FileManager.default.attributesOfItem(atPath: outfile)[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)

guard Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 2 > 1 else {
	print("File too young, won't update!")
	exit(0)
}


let task = URLSession.shared.dataTask(with: URLRequest(url: url)) { data, response, error in
//	print("data=\(String(describing: data)), response=\(String(describing: response)), error=\(String(describing: error))")

	if let error = error {
		return exit(error.localizedDescription)
	}

	guard let data = data else {
		return exit("No data!")
	}

	guard let content = String(data: data, encoding: .utf8) else {
		return exit("Data could not be converted to a UTF-8 string!")
	}

	let bridges = NSMutableArray()

	for line in content.split(separator: "\n") {
		let line = String(line)

		let match = regex?.firstMatch(in: line, options: [], range: NSRange(line.startIndex ..< line.endIndex, in: line))

		if match?.numberOfRanges ?? 0 > 1,
			let nsrange = match?.range(at: 1),
			let range = Range(nsrange, in: line) {

			bridges.add(String(line[range]))
		}
	}

	if !bridges.write(toFile: outfile, atomically: true) {
		exit("Couldn't write bridge file!")
	}

	exit(0)
}
task.resume()


// Wait on explicit exit.
_ = DispatchSemaphore(value: 0).wait(timeout: .distantFuture)
