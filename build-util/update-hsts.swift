#!/usr/bin/env xcrun --sdk macosx swift

//
//  update-hsts.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 21.02.22.
//  Copyright © 2022 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

// MARK: Config

let url = URL(string: "https://chromium.googlesource.com/chromium/src/net/+/master/http/transport_security_state_static.json?format=TEXT")!

let outfile = resolve("../Resources/hsts_preload.plist")


// MARK: Helper Methods

func exit(_ msg: String) {
	print(msg)
	exit(1)
}

func resolve(_ path: String) -> URL {
	let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
	let script = URL(fileURLWithPath: CommandLine.arguments.first ?? "", relativeTo: cwd).deletingLastPathComponent()

	return URL(fileURLWithPath: path, relativeTo: script)
}


// MARK: Main

let modified = (try? outfile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date(timeIntervalSince1970: 0)

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

	guard let data = Data(base64Encoded: data) else {
		return exit("Could not decode BASE64!")
	}

	let decoder = JSONDecoder()
	decoder.keyDecodingStrategy = .convertFromSnakeCase
	decoder.allowsJSON5 = true

	let hsts: Hsts

	do {
		hsts = try decoder.decode(Hsts.self, from: data)
	}
	catch {
		return exit("Data could not be decoded to JSON! error=\(error)")
	}

	var plist = [String: OutEntry]()

	for entry in hsts.entries {
//		print(entry)

		if entry.mode == .forceHttps {
			plist[entry.name] = OutEntry(allowSubdomains: entry.includeSubdomains)
		}
	}

	let encoder = PropertyListEncoder()
	encoder.outputFormat = .xml

	let output: Data

	do {
		output = try encoder.encode(plist)
	}
	catch {
		return exit("Plist could not be encoded! error=\(error)")
	}

	do {
		try output.write(to: outfile, options: .atomic)
	}
	catch {
		return exit("Plist file could not be written! error=\(error)")
	}

	exit(0)
}
task.resume()


// Wait on explicit exit.
_ = DispatchSemaphore(value: 0).wait(timeout: .distantFuture)


/**
The documentation is taken from the top of the source file, which contains this. Base64 decode it to find this and adapt, if changed!

 The top-level element is a dictionary with two keys: "pinsets" maps details
 of certificate pinning to a name and "entries" contains the HSTS details for
 each host.
 */
struct Hsts: Codable {

	var pinsets: [Pinset]

	var entries: [Entry]
}

/**
 For a given pinset, a certificate is accepted if at least one of the
 `static_spki_hashes` SPKIs is found in the chain and none of the
 `bad_static_spki_hashes` SPKIs are. SPKIs are specified as names, which must
 match up with the file of certificates.
 */
struct Pinset: Codable {

	/**
	 The name of the pinset.
	 */
	var name: String

	/**
	 The set of allowed SPKIs hashes.
	 */
	var staticSpkiHashes: [String]

	/**
	 The set of forbidden SPKIs hashes.
	 */
	var badStaticSpkiHashes: [String]?

	/**
	 The URI to send violation reports to; reports will be in the format defined in RFC 7469.
	 */
	var reportUri: String?
}

struct Entry: Codable {

	enum Policy: String, Codable, CustomStringConvertible {

		/**
		 Test domains
		 */
		case test = "test"

		/**
		 Google-owned sites.
		 */
		case google = "google"

		/**
		 Entries without `includeSubdomains` or with HPKP/Expect-CT.
		 */
		case custom = "custom"

		/**
		 Bulk entries preloaded before Chrome 50.
		 */
		case bulkLegacy = "bulk-legacy"

		/**
		 Bulk entries with max-age >= 18 weeks (Chrome 50-63).
		 */
		case bulk18Weeks = "bulk-18-weeks"

		/**
		 Bulk entries with max-age >= 1 year (after Chrome 63).
		 */
		case bulk1Year = "bulk-1-year"

		/**
		 Public suffixes (e.g. TLDs or other public suffix list entries) preloaded at the owner's request.
		 */
		case publicSuffix = "public-suffix"

		/**
		 Domains under a public suffix that have been preloaded at the request of the the public suffix owner (e.g. the registry for the TLD).
		 */
		case publicSuffixRequested = "public-suffix-requested"

		var description: String {
			return rawValue
		}
	}

	enum Mode: String, Codable, CustomStringConvertible {

		/**
		 If covered names should require HTTPS.
		 */
		case forceHttps = "force-https"

		var description: String {
			return rawValue
		}
	}

	/**
	 The DNS name of the host in question.
	 */
	var name: String

	/**
	 the policy under which the domain is part of the preload list. This field is used for list maintenance.
	 */
	var policy: Policy?

	/**
	 For backwards compatibility, this means:

	 - If mode == "force-https", then apply force-https to subdomains.
	 - If "pins" is set, then apply the pinset to subdomains.
	 */
	var includeSubdomains: Bool?

	/**
	 Whether subdomains of `name` are also covered for pinning.
	 As noted above, `include_subdomains` also has the same effect on pinning.
	 */
	var includeSubdomainsForPinning: Bool?

	/**
	 "force-https" if covered names should require HTTPS.
	 */
	var mode: Mode?

	/**
	 The `name` member of an object in `pinsets`.
	 */
	var pins: String?

	/**
	 true if the site expects Certificate Transparency information to be present on requests to `name`.
	 */
	var expectCt: Bool?

	/**
	 If `expect_ct` is true, the URI to which reports should be sent when valid Certificate Transparency information is not present.
	 */
	var expectCtReportUri: String?
}

struct OutEntry: Codable {

	var allowSubdomains: Bool?
}
