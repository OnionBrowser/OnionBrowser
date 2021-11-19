//
//  IpSupport.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 17.11.21.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import Reachability

class IpSupport {

	enum Status {
		case dual
		case ipV4Only
		case ipV6Only
		case unknown
	}

	typealias Changed = (Status) -> Void

	static var shared = IpSupport()


	private var reachability: Reachability?

	private var callback: Changed?


	private init() {
		NotificationCenter.default.addObserver(
			self, selector: #selector(reachabilityChanged),
			name: .reachabilityChanged, object: nil)
	}

	func start(_ changed: @escaping Changed) {
		callback = changed

		reachability = try? Reachability()
		try? reachability?.startNotifier()
	}

	func stop() {
		reachability?.stopNotifier()
		reachability = nil

		callback = nil
	}

	@objc private func reachabilityChanged() {
		if reachability?.connection == .unavailable {
			callback?(.unknown)

			return
		}

		let (v4, v6) = getIpAddressesOfPublicInterfaces()

		let hasNonLocalV4 = !v4
			.filter({ !$0.hasPrefix("127.") && !$0.hasPrefix("0.") && !$0.hasPrefix("169.254.") && !$0.hasPrefix("255.") })
			.isEmpty
		let hasNonLocalV6 = !v6
			.filter({ $0 != "::1" && !$0.hasPrefix("fe80:") })
			.isEmpty

		let status: Status

		switch (hasNonLocalV4, hasNonLocalV6) {
		case (true, true):
			status = .dual

		case (true, false):
			status = .ipV4Only

		case (false, true):
			status = .ipV6Only

		default:
			status = .unknown
		}

		callback?(status)
	}

	private func getIpAddressesOfPublicInterfaces() -> ([String], [String]) {
		var v4 = [String]()
		var v6 = [String]()

		var ifaddrs: UnsafeMutablePointer<ifaddrs>? = nil

		guard getifaddrs(&ifaddrs) == 0,
			  let firstAddr = ifaddrs
		else {
			return (v4, v6)
		}

		for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
			let ifaddr = ifptr.pointee

			guard ifaddr.ifa_flags & UInt32(IFF_UP) != 0 else {
				continue
			}

			let ifName = String(cString: ifaddr.ifa_name)

			guard ifName.hasPrefix("en") || ifName.hasPrefix("pdp_ip") else {
				continue
			}

			let family = ifaddr.ifa_addr.pointee.sa_family

			if family == AF_INET {
				if let address = getIpAddress(ifaddr), !address.isEmpty {
					v4.append(address)
				}
			}
			else if family == AF_INET6 {
				if let address = getIpAddress(ifaddr), !address.isEmpty {
					v6.append(address)
				}
			}
		}

		freeifaddrs(ifaddrs)

		return (v4, v6)
	}

	private func getIpAddress(_ ifaddr: ifaddrs) -> String? {
		var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))

		let result = getnameinfo(
			ifaddr.ifa_addr, socklen_t(ifaddr.ifa_addr.pointee.sa_len),
			&buffer, socklen_t(buffer.count),
			nil, 0, NI_NUMERICHOST)

		return result == 0 ? String(cString: buffer) : nil
	}
}
