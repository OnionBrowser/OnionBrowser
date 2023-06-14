//
//  URLSession+IPtProxyUI.swift
//  IPtProxyUI
//
//  Created by Benjamin Erhart on 2021-11-29.
//  Copyright © 2019 - 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

public extension URLSession {

	func apiTask<T: Codable>(with request: URLRequest, _ completion: ((T?, Error?) -> Void)? = nil) -> URLSessionDataTask {
		return dataTask(with: request) { data, response, error in

//			print("[\(String(describing: type(of: self)))]#apiTask data=\(String(describing: String(data: data ?? Data(), encoding: .utf8))), response=\(String(describing: response)), error=\(String(describing: error))")
			
			if let error = error {
				completion?(nil, error)
				return
			}

			guard let response = response as? HTTPURLResponse else {
				completion?(nil, ApiError.noHttpResponse)
				return
			}

			guard response.statusCode == 200 else {
				completion?(nil, ApiError.no200Status(status: response.statusCode))
				return
			}

			guard let data = data, !data.isEmpty else {
				completion?(nil, ApiError.noBody)
				return
			}
			
			do {
				completion?(try JSONDecoder().decode(T.self, from: data), nil)
			}
			catch {
				completion?(nil, error)
				return
			}
		}
	}
}
