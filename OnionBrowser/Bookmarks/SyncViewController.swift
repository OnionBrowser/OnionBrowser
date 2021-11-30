//
//  SyncViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 26.02.20.
//  Copyright © 2020 jcs. All rights reserved.
//

import UIKit
import Eureka
import IPtProxyUI

class SyncViewController: FixedFormViewController {

	var delegate: BookmarksViewControllerDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Sync Bookmarks", comment: "")

		var desc = NSLocalizedString("If you sync, all bookmarks will be read from the server and added/updated in Onion Browser.", comment: "")
		desc += "\n\n"
		desc += NSLocalizedString("Additionally, all bookmarks not existing on the server but in Onion Browser will be created there.", comment: "")

		form
			+++ Section(header: NSLocalizedString("Sync Bookmarks with Nextcloud Server", comment: ""),
						footer: desc)

			<<< TextRow("host") {
				$0.title = NSLocalizedString("Host", comment: "")
				$0.placeholder = "nextcloud.example.com"
				$0.cell.textField.autocorrectionType = .no
				$0.cell.textField.autocapitalizationType = .none
				$0.cell.textField.keyboardType = .URL
				$0.cell.textField.textContentType = .URL
				$0.value = Settings.nextcloudServer
			}
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

			<<< AccountRow("username") {
				$0.title = NSLocalizedString("Username", comment: "")
				$0.value = Settings.nextcloudUsername
			}
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

			<<< PasswordRow("password") {
				$0.title = NSLocalizedString("Password", comment: "")
				$0.value = Settings.nextcloudPassword
			}
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

			+++ ButtonRow("sync") {
				$0.title = NSLocalizedString("Sync Bookmarks", comment: "")
				$0.disabled = Condition.function(["host", "username", "password"]) { form in
					return (form.rowBy(tag: "host") as? TextRow)?.value?.isEmpty ?? true
						|| (form.rowBy(tag: "username") as? AccountRow)?.value?.isEmpty ?? true
						|| (form.rowBy(tag: "password") as? PasswordRow)?.value?.isEmpty ?? true
				}
			}
			.onCellSelection { [weak self] _, row in
				guard let vc = self else {
					return
				}

				if !row.isDisabled {
					Settings.nextcloudServer = (self?.form.rowBy(tag: "host") as? TextRow)?.value
					Settings.nextcloudUsername = (self?.form.rowBy(tag: "username") as? AccountRow)?.value
					Settings.nextcloudPassword = (self?.form.rowBy(tag: "password") as? PasswordRow)?.value

					let hud = MBProgressHUD.showAdded(to: vc.navigationController?.view ?? vc.view, animated: true)

					Nextcloud.sync { error in
						DispatchQueue.main.async {
							hud.mode = .customView
							hud.customView = UIImageView(image: UIImage(named: "check"))
							hud.hide(animated: true, afterDelay: 1)

							if let error = error {
								let message = NSLocalizedString("We couldn't sync your bookmarks at this time. Try again to make sure your information is synced.", comment: "")
									+ "\n\n"
									+ error.localizedDescription

								AlertHelper.present(
									vc,
									message: message,
									title: NSLocalizedString("Connection to Nextcloud Server Failed", comment: ""),
									actions: [
										AlertHelper.cancelAction(),
										AlertHelper.defaultAction(NSLocalizedString("Try Again", comment: ""), handler: { _ in
											DispatchQueue.main.async {
												vc.form.rowBy(tag: "sync")?.didSelect()
											}
										})
								])
							}
						}

						vc.delegate?.needsReload()
					}
				}
			}
	}
}
