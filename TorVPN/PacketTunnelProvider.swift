//
//  PacketTunnelProvider.swift
//  TorVPN
//
//  Created by Benjamin Erhart on 28.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {

	private static let ENABLE_LOGGING = true
	private static var messageQueue: [String: Any] = ["log":[]]

	private var hostHandler: ((Data?) -> Void)?

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.

		log("[\(String(describing: type(of: self)))]#startTunnel")

		let ipv4 = NEIPv4Settings(addresses: ["192.168.20.2"], subnetMasks: ["255.255.255.0"])
		ipv4.includedRoutes = [NEIPv4Route.default()]

		let ipv6 = NEIPv6Settings.init(addresses: ["fec0::0001"], networkPrefixLengths: [0])
		ipv6.includedRoutes = [NEIPv6Route.default()]

		let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
		settings.ipv4Settings = ipv4
		settings.ipv6Settings = ipv6
		settings.dnsSettings = NEDNSSettings(servers: ["127.0.0.1"])

		log("[\(String(describing: type(of: self)))]#startTunnel before setTunnelNetworkSettings")

		setTunnelNetworkSettings(settings) { error in
			self.log("[\(String(describing: type(of: self)))]#startTunnel in callback error=\(String(describing: error))")

			completionHandler(error)
		}

		log("[\(String(describing: type(of: self)))]#startTunnel end")
	}

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
		if PacketTunnelProvider.ENABLE_LOGGING {
			hostHandler = completionHandler
		}
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }

    override func wake() {
        // Add code here to wake up.
    }

	@objc private func sendMessages() {
		if PacketTunnelProvider.ENABLE_LOGGING, let handler = hostHandler {
			let response = try? NSKeyedArchiver.archivedData(withRootObject: PacketTunnelProvider.messageQueue, requiringSecureCoding: false)
			PacketTunnelProvider.messageQueue = ["log": []]
			handler(response)
			hostHandler = nil
		}
	}

	private func log(_ message: String) {
		PacketTunnelProvider.log(message)

		sendMessages()
	}

	private static func log(_ message: String) {
		if ENABLE_LOGGING, var log = messageQueue["log"] as? [String] {
			log.append("\(self): \(message)")
			messageQueue["log"] = log

			NSLog(message)
		}
	}
}
