//
//  TorCircuit+Helper.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 12.10.23.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Tor
import OrbotKit

extension TorCircuit: Encodable {

	enum CodingKeys: CodingKey {
		case raw
		case circuitId
		case status
		case nodes
		case buildFlags
		case purpose
		case hsState
		case rendQuery
		case timeCreated
		case reason
		case remoteReason
		case socksUsername
		case socksPassword
	}

	private static let beginningOfTime = Date(timeIntervalSince1970: 0)


	class func filter(_ circuits: [TorCircuit]) -> [TorCircuit] {
		circuits.filter({ circuit in
			!(circuit.nodes?.isEmpty ?? true)
			&& (
				(circuit.purpose == TorCircuit.purposeGeneral || circuit.purpose == "CONFLUX_LINKED")
				&& !(circuit.buildFlags?.contains(TorCircuit.buildFlagIsInternal) ?? false)
				&& !(circuit.buildFlags?.contains(TorCircuit.buildFlagOneHopTunnel) ?? false)
			) || (
				circuit.purpose == TorCircuit.purposeHsClientRend
				&& !(circuit.rendQuery?.isEmpty ?? true)
			) || (
				circuit.purpose == TorCircuit.purposeHsServiceRend
			)
		})
		// Oldest first! This is sometimes wrong, but our best guess.
		// Often times there are newer ones created after a request
		// but the main page was requested via the oldest one.
			.sorted(by: {
				$0.timeCreated ?? Self.beginningOfTime
				< $1.timeCreated ?? Self.beginningOfTime
			})
	}


	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(raw, forKey: .raw)
		try container.encode(circuitId, forKey: .circuitId)
		try container.encode(status, forKey: .status)
		try container.encode(nodes, forKey: .nodes)
		try container.encode(buildFlags, forKey: .buildFlags)
		try container.encode(purpose, forKey: .purpose)
		try container.encode(hsState, forKey: .hsState)
		try container.encode(rendQuery, forKey: .rendQuery)
		try container.encode(timeCreated, forKey: .timeCreated)
		try container.encode(reason, forKey: .reason)
		try container.encode(remoteReason, forKey: .remoteReason)
		try container.encode(socksUsername, forKey: .socksUsername)
		try container.encode(socksPassword, forKey: .socksPassword)
	}

	public func toOrbotKitType() -> OrbotKit.TorCircuit? {
		guard let data = try? JSONEncoder().encode(self) else {
			return nil
		}

		return try? JSONDecoder().decode(OrbotKit.TorCircuit.self, from: data)
	}
}

extension TorNode: Encodable {

	enum CodingKeys: CodingKey {
		case fingerprint
		case nickName
		case ipv4Address
		case ipv6Address
		case countryCode
		case localizedCountryName
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(fingerprint, forKey: .fingerprint)
		try container.encode(nickName, forKey: .nickName)
		try container.encode(ipv4Address, forKey: .ipv4Address)
		try container.encode(ipv6Address, forKey: .ipv6Address)
		try container.encode(countryCode, forKey: .countryCode)
		try container.encode(localizedCountryName, forKey: .localizedCountryName)
	}
}
