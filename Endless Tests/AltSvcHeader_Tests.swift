//
//  AltSvcHeader_Tests.swift
//  OnionBrowser2 Tests
//
//  Created by Benjamin Erhart on 02.03.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import XCTest

class AltSvcHeader_Tests: XCTestCase {

	private let testValues = [
		#"h2=":443"; ma=2592000"#,
		#"h2=":443"; ma=2592000; persist=1"#,
		#"h2="alt.example.com:443", h2=":443""#,
		#"h3-25=":443"; ma=3600, h2=":443"; ma=3600"#,
		#"h2="privacy2zbidut4m4jyj3ksdqidzkw3uoip2vhvhbvwxbqux5xy5obyd.onion:443"; persist=1"#,
		#"clear"#]

	func testTestValues() {
		for value in testValues {
			let header = AltSvcHeader(token: value)

			for service in header.services {
				print("Service \"\(service)\" is \(String(describing: type(of: service))), protocolId=\(service.protocolId), host=\(service.host), port=\(service.port),  maxAge=\(service.maxAge), persist=\(service.persist)")
			}

			XCTAssertEqual(String(describing: header), value, #"Testing "\(value)""#)
		}
	}

	func testClear() {
		let header = AltSvcHeader(token: "clear")

		XCTAssert(header.services.first is ClearAltService, "Testing ClearAltService")
	}

	func testBroken() {
		let header = AltSvcHeader(token: "asdfasdfasdfasdf")

		XCTAssertNil(header.services.first, "Testing broken token")
	}

	func testInitFromHeaders() {
		var header = AltSvcHeader(headers: ["Alt-Svc": testValues.first!])
		XCTAssertNotNil(header)
		XCTAssertEqual(String(describing: header!), testValues.first!)

		header = AltSvcHeader(headers: ["foo": "bar"])
		XCTAssertNil(header)

		header = AltSvcHeader(headers: ["Alt-Svc": ""])
		XCTAssertNil(header)
	}

	func testProgrammaticInit() {
		let header = AltSvcHeader([
			AltService(protocolId: "h2", port: 443),
			AltService(protocolId: "h2", port: 4443, maxAge: 1234, persist: true)])

		XCTAssertEqual(String(describing: header), #"h2=":443", h2=":4443"; ma=1234; persist=1"#)
	}

	func testRemoveDouble() {
		let header = AltSvcHeader(token: #"h2=":443", h2=":443""#)

		XCTAssertEqual(String(describing: header), #"h2=":443""#)
	}

	func testMaxAgeCalc() {
		let header = AltSvcHeader(token: #"h2=":443""#)
		let service = header.services.first

		XCTAssertNotNil(service)

		print("maxAge=\(service!.maxAge), maxAgeAbsolute=\(service!.maxAgeAbsolute), timeIntervalSinceNow=\(service!.maxAgeAbsolute.timeIntervalSinceNow)")

		XCTAssertGreaterThan(service!.maxAgeAbsolute.timeIntervalSinceNow, 0)
	}
}
