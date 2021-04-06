//
//  AltSvcHeader.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 28.02.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

/**
Parser/builder for the Alt-Svc header.

The Alt-Svc HTTP response header is used to advertise alternative services through which the same resource
can be reached.

An alternative service is defined by a protocol/host/port combination.

https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Alt-Svc
*/
@objcMembers
public class AltSvcHeader: NSObject {

	public private(set) var services = [AltService]()

	/**
	Init from a Alt-Svc header string.

	- parameter token: The Alt-Svc header string.
	*/
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

	/**
	Init from a bunch of HTTP headers, if a Alt-Svc header is contained.

	- parameter headers: HTTP headers
	*/
	public convenience init?(headers: [String: String]) {
		var token: String? = nil

		for key in headers.keys {
			if key.lowercased() == "alt-svc" {
				token = headers[key]
				break
			}
		}

		if token?.isEmpty ?? true {
			return nil
		}

		self.init(token: token!)
	}

	/**
	Init from a list of `AltService`s.

	- parameter services: The `AltService` objects.
	*/
	public init(_ services: [AltService]) {
		self.services = services
	}

	public override var description: String {
		return services.map { String(describing: $0) }.joined(separator: ", ")
	}
}

/**
An alternative service through which the same resource can be reached.

An alternative service is defined by a protocol/host/port combination.
*/
@objcMembers
public class AltService: NSObject {

	private static let maxAgeRegEx = try? NSRegularExpression(pattern: "ma=(\\d+)", options: [])

	/**
	24 hours in seconds. (Default `maxAge` value)
	*/
	public static let twentyFourHours = 24 * 60 * 60

	/**
	The ALPN protocol identifier. Examples include h2 for HTTP/2 and h3-25 for draft 25 of the HTTP/3 protocol.
	*/
	public let protocolId: String

	/**
	The host part of the  string specifying the alternative authority which consists of an optional host override,
	a colon, and a mandatory port number.
	*/
	public let host: String

	/**
	The port number port of the string specifying the alternative authority which consists of an optional host
	override, a colon, and a mandatory port number.
	*/
	public let port: Int

	/**
	The number of seconds for which the alternative service is considered fresh.
	Defaults to 24 hours.

	Alternative service entries can be cached for up to `maxAge` seconds, minus the age of the response
	(from the Age header).

	If the cached entry expires, the client can no longer use this alternative service for new connections.
	*/
	public let maxAge: Int

	/**
	Usually cached alternative service entries are cleared on network configuration changes.
	Use of the persist=1 parameter ensures that the entry is not deleted through such changes.
	*/
	public let persist: Bool

	/**
	The absolute end of validity of this `AltService` calculated from the date of creation of this object.
	*/
	public let maxAgeAbsolute: Date

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

		let authorityPieces = authority.split(separator: ":", omittingEmptySubsequences: false)

		guard authorityPieces.count == 2,
			let port = Int(String(authorityPieces.last ?? ""))
			else {
				return nil
		}

		let host = String(authorityPieces.first ?? "")

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

		return AltService(protocolId: protocolId, host: host, port: port, maxAge: maxAge, persist: persist)
	}

	public init(protocolId: String, host: String = "", port: Int, maxAge: Int = AltService.twentyFourHours, persist: Bool = false) {
		self.protocolId = protocolId
		self.host = host
		self.port = port
		self.maxAge = maxAge
		self.persist = persist
		self.maxAgeAbsolute = Date(timeInterval: TimeInterval(maxAge), since: Date())
	}

	// MARK: NSObject

	@objc
	public override var hash: Int {
		return protocolId.hashValue ^ host.hashValue ^ port.hashValue
	}

	@objc
	public override func isEqual(_ object: Any?) -> Bool {
		guard let rhs = object as? AltService else {
			return false
		}

		return protocolId == rhs.protocolId
			&& host == rhs.host
			&& port == rhs.port
	}

	@objc
	public override var description: String {
		var token = ["\(protocolId)=\"\(host):\(port)\""]

		if maxAge != AltService.twentyFourHours {
			token.append("ma=\(maxAge)")
		}

		if persist {
			token.append("persist=1")
		}

		return token.joined(separator: "; ")
	}
}

/**
The special value ''clear" indicates that the origin requests all alternatives for that origin to be invalidated.
*/
public class ClearAltService: AltService {

	init() {
		super.init(protocolId: "", host: "", port: 0, maxAge: 0)
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
