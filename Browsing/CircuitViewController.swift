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
		var country: String
		var ip: String?
		var note: String?

		init(country: String, ip: String? = nil, note: String? = nil) {
			self.country = country
			self.ip = ip
			self.note = note
		}
	}

	public var currentUrl: URL?

	@IBOutlet weak var torCircuitLb: UILabel! {
		didSet {
			torCircuitLb.text = NSLocalizedString("Tor Circuit", comment: "")
		}
	}

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var newCircuitBt: UIButton! {
		didSet {
			newCircuitBt.setTitle(NSLocalizedString("New Circuit", comment: ""))
		}
	}

	@IBOutlet weak var bridgeConfigBt: UIButton! {
		didSet {
			bridgeConfigBt.setTitle(NSLocalizedString("Bridge Configuration", comment: ""))
		}
	}


	override var preferredContentSize: CGSize {
		get {
			return CGSize(width: 300, height: 340)
		}
		set {
			// Ignore.
		}
	}

	private var nodes = [Node]()

	override func viewDidLoad() {
		super.viewDidLoad()

        tableView.register(CircuitNodeCell.nib, forCellReuseIdentifier: CircuitNodeCell.reuseId)

		OnionManager.shared.getCurrentCircuit { result in
			self.nodes.removeAll()

			self.nodes.append(CircuitViewController.Node(country: NSLocalizedString("This browser", comment: "")))
			self.nodes.append(contentsOf: result)
			self.nodes[1].note = NSLocalizedString("Guard", comment: "")
			self.nodes.append(CircuitViewController.Node(country: BrowsingViewController.prettyTitle(self.currentUrl)))

			DispatchQueue.main.async {
				self.tableView.reloadData()
			}
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


	// MARK: UIPopoverPresentationControllerDelegate

	public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: UITableViewDelegate

	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		return CircuitNodeCell.height
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

	@IBAction func newCircuit() {
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

		vc.modalPresentationStyle = .popover
		vc.popoverPresentationController?.sourceView = sender.superview
		vc.popoverPresentationController?.sourceRect = sender.frame

		present(vc, animated: true)
	}
}
