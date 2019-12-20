//
//  CircuitViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 04.12.19.
//  Copyright (c) 2012-2019, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import POE

class CircuitViewController: UIViewController, UIPopoverPresentationControllerDelegate,
POEDelegate, UITableViewDataSource, UITableViewDelegate {

	struct Node {
		var title: String
		var ip: String?
		var note: String?

		init(title: String, ip: String? = nil, note: String? = nil) {
			self.title = title
			self.ip = ip
			self.note = note
		}

		init(_ torNode: TorNode) {
			self.title = torNode.localizedCountryName ?? torNode.countryCode ?? torNode.nickName ?? ""
			self.ip = torNode.ipv4Address?.isEmpty ?? true ? torNode.ipv6Address : torNode.ipv4Address
		}
	}

	public var currentUrl: URL?

	@IBOutlet weak var headerLb: UILabel! {
		didSet {
			headerLb.text = NSLocalizedString("Tor Circuit", comment: "")
		}
	}

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var newCircuitsBt: UIButton! {
		didSet {
			newCircuitsBt.setTitle(NSLocalizedString("New Circuit for this Site", comment: ""))
		}
	}

	@IBOutlet weak var bridgeConfigBt: UIButton! {
		didSet {
			bridgeConfigBt.setTitle(NSLocalizedString("Bridge Configuration", comment: ""))
		}
	}


	override var preferredContentSize: CGSize {
		get {
			return CGSize(width: 300, height: 320)
		}
		set {
			// Ignore.
		}
	}

	private var nodes = [Node]()
	private var usedCircuits = [TorCircuit]()

	private static let onionAddressRegex = try? NSRegularExpression(pattern: "^(.*).onion$", options: .caseInsensitive)

	private static let beginningOfTime = Date(timeIntervalSince1970: 0)

	override func viewDidLoad() {
		super.viewDidLoad()

        tableView.register(CircuitNodeCell.nib, forCellReuseIdentifier: CircuitNodeCell.reuseId)

		reloadCircuits()
	}


	// MARK: UITableViewDataSource

	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return nodes.count
	}

	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: CircuitNodeCell.reuseId, for: indexPath)
			as! CircuitNodeCell

		return cell.set(nodes[indexPath.row], isFirst: indexPath.row < 1, isLast: indexPath.row > nodes.count - 2)
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return CircuitNodeCell.height
	}


	// MARK: UIPopoverPresentationControllerDelegate

	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: POEDelegate

	func introFinished(_ useBridge: Bool) {
		print("#introFinished not implemented!");
	}

	/**
	Receive this callback, after the user finished the bridges configuration.

	- parameter bridgesId: the selected ID of the list you gave in the constructor of
	BridgeSelectViewController.
	- parameter customBridges: the list of custom bridges the user configured.
	*/
	func bridgeConfigured(_ bridgesId: Int, customBridges: [String]) {
		UserDefaults.standard.set(bridgesId, forKey: USE_BRIDGES)
		UserDefaults.standard.set(customBridges, forKey: CUSTOM_BRIDGES)

		// At this point we already have a connection. The bridge reconfiguration is very cheap,
		// so we stay in the browser view and let OnionManager reconfigure in the background.
		// Actually, the reconfiguration can be done completely offline, so we don't have a chance to
		// find out, if another bridge setting (or no bridge) actually works afterwards.
		// The user will find out, when she tries to continue browsing.
		OnionManager.shared.setBridgeConfiguration(bridgesId: bridgesId, customBridges: customBridges)
		OnionManager.shared.startTor(delegate: nil)
	}

	func changeSettings() {
		print("#changeSettings not implemented!");
	}

	func userFinishedConnecting() {
		print("#userFinishedConnecting not implemented!");
	}


	// MARK: Actions

	@IBAction func newCircuits() {
		OnionManager.shared.closeCircuits(usedCircuits) { _ in
			AppDelegate.shared().browsingUi?.currentTab?.refresh()

			self.dismiss(animated: true)
		}
	}

	@IBAction func showBridgeSelection(_ sender: UIView) {
		let builtInBridges: [Int: String]
		builtInBridges = [USE_BRIDGES_OBFS4: "obfs4",
						  USE_BRIDGES_MEEKAZURE: "meek-azure"]

		let ud = UserDefaults.standard

		let vc = BridgeSelectViewController.instantiate(
			currentId: ud.integer(forKey: USE_BRIDGES),
			noBridgeId: NSNumber(value: USE_BRIDGES_NONE),
			providedBridges: builtInBridges,
			customBridgeId: NSNumber(value: USE_BRIDGES_CUSTOM),
			customBridges: ud.stringArray(forKey: CUSTOM_BRIDGES),
			delegate: self)

		present(vc, sender)
	}


	// MARK: Private Methods

	private func reloadCircuits() {
		DispatchQueue.global(qos: .userInitiated).async {
            OnionManager.shared.getCircuits { circuits in

				// Store in-use circuits (identified by having a SOCKS username,
				// so the user can close them and get fresh ones on #newCircuits.
				self.usedCircuits = circuits.filter { !($0.socksUsername?.isEmpty ?? true) }

				var candidates = [TorCircuit]()
				var query: String?

				if let host = self.currentUrl?.host {
					let matches = CircuitViewController.onionAddressRegex?.matches(
						in: host, options: [],
						range: NSRange(host.startIndex ..< host.endIndex, in: host))

					if matches?.first?.numberOfRanges ?? 0 > 1,
						let nsRange = matches?.first?.range(at: 1),
						let range = Range(nsRange, in: host) {
						query = String(host[range])
					}
				}

				// Circuits used for .onion addresses can be identified by their
				// rendQuery, which is equal to the "domain".
				if let query = query {
					for circuit in circuits {
						if circuit.purpose == TorCircuit.purposeHsClientRend
							&& circuit.rendQuery == query {

							candidates.append(circuit)
						}
					}
				}
				else {
					for circuit in circuits {
						if circuit.purpose == TorCircuit.purposeGeneral
							&& !(circuit.socksUsername?.isEmpty ?? true)
							&& !(circuit.buildFlags?.contains(TorCircuit.buildFlagIsInternal) ?? false)
							&& !(circuit.buildFlags?.contains(TorCircuit.buildFlagOneHopTunnel) ?? false) {

							candidates.append(circuit)
						}
					}
				}

				// Oldest first! This is sometimes wrong, but our best guess.
				// Often times there are newer ones created after a request
				// but the main page was requested via the oldest one.
				candidates.sort { $0.timeCreated ?? CircuitViewController.beginningOfTime
					< $1.timeCreated ?? CircuitViewController.beginningOfTime }

				self.nodes.removeAll()

				self.nodes.append(Node(title: NSLocalizedString("This browser", comment: "")))

				for node in candidates.first?.nodes ?? [] {
					self.nodes.append(Node(node))
				}
				if self.nodes.count > 1 {
					self.nodes[1].note = NSLocalizedString("Guard", comment: "")
				}

				self.nodes.append(Node(title: BrowsingViewController.prettyTitle(self.currentUrl)))

				DispatchQueue.main.async {
					self.tableView.reloadData()
				}
			}
		}
	}
}
