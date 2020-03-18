//
//  ApiError.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.03.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

enum ApiError: LocalizedError {
	case noHttpResponse
	case no200Status(status: Int)
	case noBody
	case noValidJsonBody
	case notSuccess(status: Any?)
	case noRequestPossible

	var errorDescription: String? {
		switch self {
		case .noHttpResponse:
			return NSLocalizedString("No valid HTTP response.", comment: "")

		case .no200Status(let status):
			return "\(status) \(HTTPURLResponse.localizedString(forStatusCode: status))"

		case .noBody:
			return NSLocalizedString("Response body missing.", comment: "")

		case .noValidJsonBody:
			return NSLocalizedString("Response is no valid JSON.", comment: "")

		case .notSuccess(let status):
			return String(format: NSLocalizedString("No success, but \"%@\" instead.", comment: ""), String(describing: status))

		case .noRequestPossible:
			return NSLocalizedString("Request could not be formed. Please check host and username/password!", comment: "")
		}
	}
}
