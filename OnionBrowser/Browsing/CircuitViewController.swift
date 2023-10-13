//
//  CircuitViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 04.12.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import OrbotKit
import Tor
import IPtProxyUI

class CircuitViewController: UIViewController, UIPopoverPresentationControllerDelegate,
							 UITableViewDataSource, UITableViewDelegate, BridgesConfDelegate 
{

	struct Node {
		var title: String
		var ip: String?
		var note: String?

		init(title: String, ip: String? = nil, note: String? = nil) {
			self.title = title
			self.ip = ip
			self.note = note
		}

		init(_ torNode: OrbotKit.TorNode) {
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
    @IBOutlet weak var noCircuitsView: UIView!

    @IBOutlet weak var noCircuitsLb1: UILabel! {
        didSet {
            noCircuitsLb1.text = NSLocalizedString(
                "Your traffic goes to 3 different parts of the world.", comment: "")
        }
    }
    @IBOutlet weak var noCircuitsLb2: UILabel! {
        didSet {
            noCircuitsLb2.text = NSLocalizedString(
                "Connect to a website to see your circuit.", comment: "")
        }
    }

    @IBOutlet weak var newCircuitsBt: UIButton! {
		didSet {
			newCircuitsBt.setTitle(NSLocalizedString(
                "New Circuit for this Site", comment: ""))
		}
	}

	@IBOutlet weak var bridgeConfigBt: UIButton! {
		didSet {
			bridgeConfigBt.setTitle(NSLocalizedString(
                "Bridge Configuration", comment: ""))
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
	private var usedCircuits = [OrbotKit.TorCircuit]()

	private static let onionAddressRegex = try? NSRegularExpression(pattern: "^(.*)\\.(onion|exit)$", options: .caseInsensitive)

	private static let beginningOfTime = Date(timeIntervalSince1970: 0)

	override func viewDidLoad() {
		super.viewDidLoad()

        tableView.register(CircuitNodeCell.nib, forCellReuseIdentifier: CircuitNodeCell.reuseId)

		if currentUrl?.isSpecial ?? true {
			tableView.isHidden = true
            noCircuitsView.isHidden = false
			newCircuitsBt.isHidden = true
		}
		else {
            noCircuitsView.isHidden = true
			reloadCircuits()
		}
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


	// MARK: BridgesConfDelegate

	var transport: IPtProxyUI.Transport {
		get {
			Settings.transport
		}
		set {
			Settings.transport = newValue
		}
	}

	var customBridges: [String]? {
		get {
			Settings.customBridges
		}
		set {
			Settings.customBridges = newValue
		}
	}

	func save() {
		TorManager.shared.updateConfig(Settings.transport)
	}


	// MARK: Actions

	@IBAction func newCircuits() {
		let completion = { [weak self] (_: Bool) in
			self?.view.sceneDelegate?.browsingUi.currentTab?.refresh()

			self?.dismiss(animated: true)
		}

		if Settings.useBuiltInTor == true {
			TorManager.shared.close(usedCircuits.compactMap({ $0.circuitId }), completion)
		}
		else {
			OrbotManager.shared.closeCircuits(usedCircuits, completion)
		}
	}

	@IBAction func showBridgeSelection(_ sender: UIView) {
		if Settings.useBuiltInTor == true {
			let vc = BridgesConfViewController()
			vc.delegate = self

			present(UINavigationController(rootViewController: vc))
		}
		else {
			OrbotKit.shared.open(.bridges)
		}
	}

	private func reloadCircuits() {
		// TODO: A lot of this needs to move to Tor.framework for better reuse!
		let completion = { (circuits: [OrbotKit.TorCircuit]) in
			// Store in-use circuits (identified by having a SOCKS username,
			// so the user can close them and get fresh ones on #newCircuits.
			self.usedCircuits = circuits


			self.nodes.removeAll()

			self.nodes.append(Node(title: NSLocalizedString("This browser", comment: "")))

			for node in circuits.first?.nodes ?? [] {
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

		DispatchQueue.global(qos: .userInitiated).async {
			let host = self.currentUrl?.host

			if Settings.useBuiltInTor == true {
				TorManager.shared.getCircuits { circuits in
					var candidates = TorCircuit.filter(circuits)

					if let host = host {
						var query: String?

						let matches = Self.onionAddressRegex?.matches(
							in: host, options: [],
							range: NSRange(host.startIndex ..< host.endIndex, in: host))

						if matches?.first?.numberOfRanges ?? 0 > 1,
							let nsRange = matches?.first?.range(at: 1),
							let range = Range(nsRange, in: host) {
							query = String(host[range])
						}

						// Circuits used for .onion addresses can be identified by their
						// rendQuery, which is equal to the "domain".
						if let query = query {
							candidates = candidates.filter { circuit in
								circuit.purpose == TorCircuit.purposeHsClientRend
								&& circuit.rendQuery == query
							}
						}
						else {
							candidates = candidates.filter { circuit in
								circuit.purpose == TorCircuit.purposeGeneral || circuit.purpose == "CONFLUX_LINKED"
							}
						}
					}

					completion(candidates.compactMap({ $0.toOrbotKitType() }))
				}
			}
			else {
				OrbotManager.shared.getCircuits(host: host, completion)
			}
		}
	}
}
