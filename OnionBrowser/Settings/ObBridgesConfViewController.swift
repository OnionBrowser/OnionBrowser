//
//  ObBridgesConfViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 14.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka
import IPtProxyUI

class ObBridgesConfViewController: BridgesConfViewController {

	class func present(from: UIViewController) {
		from.present(UINavigationController(rootViewController: ObBridgesConfViewController()))
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		transport = Settings.transport
		customBridges = Settings.customBridges

		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("Connect", comment: ""), style: .done,
			target: self, action: #selector(save))

		if Settings.advancedTorConf?.count ?? 0 > 0 {
			let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 0))
			toolbar.translatesAutoresizingMaskIntoConstraints = false
			toolbar.sizeToFit() // Stupid workaround to avoid NSLayoutConstraint issues.

			let button = UIBarButtonItem(title: NSLocalizedString("Remove Advanced Tor Conf", comment: ""),
										 style: .plain, target: self, action: #selector(removeAdvancedTorConf))
			toolbar.setItems([button], animated: false)

			view.addSubview(toolbar)
			toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
			toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
			toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor).isActive = true
		}
	}


	// MARK: BridgesConfDelegate

	override var saveButtonTitle: String? {
		NSLocalizedString("Connect", comment: "")
	}

	override func startMeek() {
		Transport.obfs4.start()
	}

	override func stopMeek() {
		// Ignore here - we don't stop Obfs4proxy here.
	}

	override func auth(request: inout URLRequest) {
		let mutableRequest = ((request as NSURLRequest).mutableCopy() as? NSMutableURLRequest)!

		URLProtocol.setProperty(true, forKey: kJAHPMoatProperty, in: mutableRequest)

		request = mutableRequest as URLRequest

		JAHPAuthenticatingHTTPProtocol.temporarilyAllow(request.url)
	}


	// MARK: Actions

	@objc
	override func save() {
		Settings.transport = transportSection.selectedRow()?.value ?? .none
		Settings.customBridges = customBridges

		if presentingViewController is BridgesViewController {
			AppDelegate.shared?.show(ConnectingViewController())
		}
		else {
			// At this point we already have a connection. The bridge reconfiguration is very cheap,
			// so we stay in the browser view and let OnionManager reconfigure in the background.
			// Actually, the reconfiguration can be done completely offline, so we don't have a chance to
			// find out, if another bridge setting (or no bridge) actually works afterwards.
			// The user will find out, when she tries to continue browsing.

			OnionManager.shared.setTransportConf(transport: Settings.transport,
												 customBridges: Settings.customBridges)
			OnionManager.shared.startTor(delegate: nil)

			navigationController?.dismiss(animated: true)

			if let vc = presentingViewController as? BridgesConfDelegate {
				vc.save()
			}
		}
	}

	@objc
	private func removeAdvancedTorConf() {
		Settings.advancedTorConf = nil

		AlertHelper.present(self, message: NSLocalizedString("Quit. Then restart the app.", comment: ""),
							title: NSLocalizedString("Advanced Tor Configuration Removed", comment: ""))
	}
}
