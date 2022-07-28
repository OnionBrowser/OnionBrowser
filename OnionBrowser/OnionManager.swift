//
//  OnionManager.swift
//  OnionBrowser2
//
//  Copyright © 2012 - 2022, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation
import OrbotKit

protocol OnionManagerDelegate: AnyObject {

	func torConnProgress(_ progress: Int)

	func torConnFinished()

	func torConnDifficulties()
}

class OnionManager : NSObject {

	static let shared = OnionManager()

	// Show Tor log in iOS' app log.
	private static let TOR_LOGGING = false



	// MARK: OnionManager instance

	public private(set) var lastInfo: OrbotKit.Info?

	public var tokenAlert: UIAlertController?

	private var initRetry: DispatchWorkItem?

	private var needsReconfiguration = false


	// MARK: Public Methods

	func closeCircuits(_ circuits: [OrbotKit.TorCircuit], _ callback: @escaping ((_ success: Bool) -> Void)) {
		let group = DispatchGroup()
		var suc = false

		for circuit in circuits {
			group.enter()

			OrbotKit.shared.closeCircuit(circuit: circuit) { success, error in
				if let error = error {
					print("[\(String(describing: type(of: self)))]#closeCircuits error=\(error)")
				}

				// If only one call succeeds, we count that as a success.
				if success {
					suc = true
				}

				group.leave()
			}
		}

		group.wait()

		callback(suc)
	}

	/**
	Get all fully built circuits and detailed info about their nodes.

	- parameter callback: Called, when all info is available.
	- parameter circuits: A list of circuits and the nodes they consist of.
	*/
	func getCircuits(host: String?, _ callback: @escaping ((_ circuits: [OrbotKit.TorCircuit]) -> Void)) {
		OrbotKit.shared.circuits(host: host) { circuits, error in
			if let error = error {
				print("[\(String(describing: type(of: self)))]#getCircuits error=\(error)")
			}

			callback(circuits ?? [])
		}
	}

	func ensureOrbotRunning(_ vc: UIViewController) {
		if !OrbotKit.shared.installed {
			OnionManager.shared.alertOrbotNotInstalled(vc)
		}
		else {
			OrbotKit.shared.apiToken = Settings.orbotApiToken

			OrbotKit.shared.info { info, error in
				if case OrbotKit.Errors.httpError(statusCode: 403)? = error {
					OnionManager.shared.alertOrbotNoAccess(vc)

					return
				}

				if let error = error {
					DispatchQueue.main.async {
						AlertHelper.present(vc, message: error.localizedDescription)
					}

					return
				}

				self.lastInfo = info

				if info?.status == .stopped {
					DispatchQueue.main.async {
						AlertHelper.present(
							vc,
							message: String(format: NSLocalizedString(
								"%@ is dedicated to run together with Orbot, only.\n\nPlease start Orbot!",
						  comment: ""), Bundle.main.displayName),
							title: NSLocalizedString("Orbot not Started", comment: ""),
							actions: [
								AlertHelper.cancelAction(
									NSLocalizedString("Exit", comment: ""),
									handler: { _ in
										exit(0)
									}),
								AlertHelper.defaultAction(
									NSLocalizedString("Start Orbot", comment: ""),
									handler: { _ in
										OrbotKit.shared.open(.start)
									})
							])
					}

					return
				}

				(vc as? OnionManagerDelegate)?.torConnFinished()
			}
		}
	}

	func alertOrbotNotInstalled(_ vc: UIViewController) {
		DispatchQueue.main.async {
			AlertHelper.present(
				vc,
				message: String(format: NSLocalizedString(
					"%@ is dedicated to run together with Orbot, only.\n\nPlease install Orbot!",
					comment: ""), Bundle.main.displayName),
				title: NSLocalizedString("Orbot Not Installed", comment: ""),
				actions: [
					AlertHelper.cancelAction(
						NSLocalizedString("Exit", comment: ""),
						handler: { _ in
							exit(0)
						}),
					AlertHelper.defaultAction(
						NSLocalizedString("App Store", comment: ""),
						handler: { _ in
							UIApplication.shared.open(OrbotKit.appStoreLink)
						})
				])
		}
	}

	func alertOrbotNoAccess(_ vc: UIViewController) {
		DispatchQueue.main.async {
			AlertHelper.present(
				vc,
				message: String(format: NSLocalizedString(
					"You need to request API access with Orbot, in order for %@ to work while Orbot is running.",
					comment: ""), Bundle.main.displayName),
				title: NSLocalizedString("Request API Access", comment: ""),
				actions: [
					AlertHelper.cancelAction(
						NSLocalizedString("Exit", comment: ""),
						handler: { _ in
							exit(0)
						}),
					AlertHelper.defaultAction(
						NSLocalizedString("Request API Access", comment: ""),
						handler: { [weak self] _ in
							OrbotKit.shared.open(.requestApiToken(needBypass: false, callback: URL(string: "onionbrowser:token-callback"))) { success in
								if !success {
									AlertHelper.present(vc, message: NSLocalizedString("Orbot could not be opened!", comment: ""))

									return
								}

								self?.tokenAlert = AlertHelper.build(title: NSLocalizedString("Access Token", comment: ""),
																	 actions: [AlertHelper.cancelAction()])

								if let alert = self?.tokenAlert {
									AlertHelper.addTextField(alert, placeholder: NSLocalizedString("Paste API token here", comment: ""))

									alert.addAction(AlertHelper.defaultAction() { _ in
										Settings.orbotApiToken = self?.tokenAlert?.textFields?.first?.text
										OrbotKit.shared.apiToken = Settings.orbotApiToken

										(vc as? OnionManagerDelegate)?.torConnFinished()
									})

									vc.present(alert, animated: false)
								}
							}
						})
				])
		}
	}


	// MARK: Private Methods

	/**
	Cancel the connection retry and fail guard.
	*/
	private func cancelInitRetry() {
		initRetry?.cancel()
		initRetry = nil
	}
}
