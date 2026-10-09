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
import IPtProxyUI_iOS


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

	private static let onionAddressRegex = try? NSRegularExpression(pattern: "^(.*\\.)?(.*?)\\.(onion|exit)$", options: .caseInsensitive)

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

	var transport: IPtProxyUI_Shared.Transport {
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

	var countryCode: String? {
		get {
			Settings.countryCode
		}
		set {
			Settings.countryCode = newValue
		}
	}

	func save() {
		TorManager.shared.updateConfig(Settings.transport)
	}


	// MARK: Actions

	@IBAction func newCircuits() {
		Task {
			if Settings.useBuiltInTor == true {
				await TorManager.shared.close(usedCircuits.compactMap({ $0.circuitId }))
			}
			else {
				await OrbotManager.shared.closeCircuits(usedCircuits)
			}

			await MainActor.run {
				view.sceneDelegate?.browsingUi.currentTab?.refresh()

				dismiss(animated: true)
			}
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
		Task {
			let host = currentUrl?.host

			let okCircuits: [OrbotKit.TorCircuit]

			if Settings.useBuiltInTor == true {
				let circuits = await TorManager.shared.getCircuits()

				var candidates = TorCircuit.filter(circuits)

				if let host = host {
					var query: String?

					let matches = Self.onionAddressRegex?.matches(
						in: host, options: [],
						range: NSRange(host.startIndex ..< host.endIndex, in: host))

					if let match = matches?.first,
					   match.numberOfRanges > 1
					{
					   let nsRange = match.range(at: match.numberOfRanges - 2)

						if let range = Range(nsRange, in: host) {
							query = String(host[range])
						}
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
							circuit.purpose == TorCircuit.purposeGeneral || circuit.purpose == TorCircuit.purposeConfluxLinked
						}
					}
				}

				okCircuits = candidates.compactMap({ $0.toOrbotKitType() })
			}
			else {
				okCircuits = await OrbotManager.shared.getCircuits(host: host)
			}

			// Store in-use circuits (identified by having a SOCKS username,
			// so the user can close them and get fresh ones on #newCircuits.
			usedCircuits = okCircuits

			nodes.removeAll()

			nodes.append(Node(title: NSLocalizedString("This browser", comment: "")))

			for node in okCircuits.first?.nodes ?? [] {
				nodes.append(Node(node))
			}
			if nodes.count > 1 {
				nodes[1].note = NSLocalizedString("Guard", comment: "")
			}

			nodes.append(Node(title: BrowsingViewController.prettyTitle(currentUrl)))

			await MainActor.run {
				tableView.reloadData()
			}
		}
	}
}
