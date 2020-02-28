//
//  AltSvcHeader.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 28.02.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

/**
Parser for the Alt-Svc header.

https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Alt-Svc
*/
public class AltSvcHeader: NSObject {

	private var services = [AltService]()

	public init(token: String) {
		let serviceTokens = token.split(separator: ",")

		for token in serviceTokens {
			if let service = AltService.parse(String(token)) {
				if !services.contains(service) {
					services.append(service)
				}
			}
		}
	}

	public convenience init(headers: [String: String]) {
		var token = ""

		for key in headers.keys {
			if key.lowercased() == "alt-svc" {
				token = headers[key]!
				break
			}
		}

		self.init(token: token)
	}
}

public class AltService: NSObject {

	private static let maxAgeRegEx = try? NSRegularExpression(pattern: "ma=(\\d+)", options: [])

	private static let twentyFourHours = 24 * 60 * 60

	public let protocolId: String

	public let authority: String

	public let maxAge: Int

	public let persist: Bool

	public class func parse(_ token: String) -> AltService? {
		let token = token.trimmingCharacters(in: .whitespacesAndNewlines)

		if token.lowercased() == "clear" {
			return ClearAltService()
		}

		let pieces = token.split(separator: ";")

		guard let service = pieces.first else {
			return nil
		}

		let servicePieces = service.split(separator: "=")

		guard servicePieces.count == 2,
			let protocolId = servicePieces.first?.trimmingCharacters(in: .whitespacesAndNewlines),
			let authority = servicePieces.last?.trimmingCharacters(in: .whitespacesAndNewlines)
				.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			else {
				return nil
		}

		var maxAge = twentyFourHours // Default as per spec.

		if pieces.count > 1 {
			let ma = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

			if let match = maxAgeRegEx?.matches(in: ma, options: [], range: NSRange(ma.startIndex ..< ma.endIndex, in: ma)).first,
				match.range(at: 1).location != NSNotFound,
				let range = Range(match.range(at: 1), in: ma),
				let value = Int(String(ma[range])) {

				maxAge = value
			}
		}

		let persist = pieces.last?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "persist=1"

		return AltService(protocolId: protocolId, authority: authority, maxAge: maxAge, persist: persist)
	}

	public init(protocolId: String, authority: String, maxAge: Int, persist: Bool) {
		self.protocolId = protocolId
		self.authority = authority
		self.maxAge = maxAge
		self.persist = persist
	}

	// MARK: NSObject

	@objc
	public override var hash: Int {
		return protocolId.hashValue ^ authority.hashValue
	}

	@objc
	public override func isEqual(_ object: Any?) -> Bool {
		guard let rhs = object as? AltService else {
			return false
		}

		return protocolId == rhs.protocolId
			&& authority == rhs.authority
	}

	@objc
	public override var description: String {
		var token = ["\(protocolId)=\"/(authority)\""]

		if maxAge != AltService.twentyFourHours {
			token.append("ma=\(maxAge)")
		}

		if persist {
			token.append("persist=1")
		}

		return token.joined(separator: "; ")
	}
}

public class ClearAltService: AltService {

	init() {
		super.init(protocolId: "", authority: "", maxAge: 0, persist: false)
	}

	@objc
	public override var hash: Int {
		return "clear".hashValue
	}

	@objc
	public override func isEqual(_ object: Any?) -> Bool {
		return object is ClearAltService
	}

	@objc
	public override var description: String {
		return "clear"
	}
}
