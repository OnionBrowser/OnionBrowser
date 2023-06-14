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

class CircuitViewController: UIViewController, UIPopoverPresentationControllerDelegate,
UITableViewDataSource, UITableViewDelegate {

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


	// MARK: Actions

	@IBAction func newCircuits() {
		OrbotManager.shared.closeCircuits(usedCircuits) { [weak self] _ in
			self?.view.sceneDelegate?.browsingUi.currentTab?.refresh()

			self?.dismiss(animated: true)
		}
	}

	@IBAction func showBridgeSelection(_ sender: UIView) {
		OrbotKit.shared.open(.bridges)
	}


	// MARK: Private Methods

	private func reloadCircuits() {
		DispatchQueue.global(qos: .userInitiated).async {
			OrbotManager.shared.getCircuits(host: self.currentUrl?.host) { circuits in

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
		}
	}
}
