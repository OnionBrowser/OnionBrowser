//
//  URLSession+Helpers.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.03.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension URLSession {

	func apiTask(with request: URLRequest, _ completion: (([String: Any], Error?) -> Void)? = nil) -> URLSessionDataTask {
		return URLSession.shared.dataTask(with: request) { data, response, error in
//			print("[\(String(describing: type(of: self)))]#apiTask data=\(data), response=\(response), error=\(error)")

			if let error = error {
				completion?([:], error)
				return
			}

			guard let response = response as? HTTPURLResponse else {
				completion?([:], ApiError.noHttpResponse)
				return
			}

			guard response.statusCode == 200 else {
				completion?([:], ApiError.no200Status(status: response.statusCode))
				return
			}

			guard let data = data else {
				completion?([:], ApiError.noBody)
				return
			}

			let maybePayload: [String: Any]?

			do {
				maybePayload = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			}
			catch let error {
				completion?([:], error)
				return
			}

			guard let payload = maybePayload else {
				completion?([:], ApiError.noValidJsonBody)
				return
			}

			completion?(payload, nil)
		}
	}
}
