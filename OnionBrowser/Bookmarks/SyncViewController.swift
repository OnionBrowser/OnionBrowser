//
//  SyncViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 26.02.20.
//  Copyright © 2020 jcs. All rights reserved.
//

import UIKit
import Eureka

class SyncViewController: FixedFormViewController {

	var delegate: BookmarksViewControllerDelegate?

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Sync Bookmarks", comment: "")

		var desc1 = NSLocalizedString(
			"If you have access to a Nextcloud server with a Bookmarks plugin, enter your credentials to enable Onion Browser to synchronize your bookmarks with it.",
			comment: "")
		desc1 += "\n\n"
		desc1 += NSLocalizedString("Please note: If you create, edit or delete a bookmark, Onion Browser tries to sync that change to the Nextcloud server immediately. However, if that fails, no attempt is made to re-sync later.", comment: "")

		var desc2 = NSLocalizedString("If you synchronize, all bookmarks will be read from the server and added/updated in Onion Browser.", comment: "")
		desc2 += "\n\n"
		desc2 += NSLocalizedString("Additionally, all bookmarks not existing on the server but in Onion Browser will be created there.", comment: "")

		form
			+++ Section(footer: desc1)

			+++ TextRow("host") {
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

			+++ Section(footer: desc2)

			<<< ButtonRow("sync") {
				$0.title = NSLocalizedString("Synchronize", comment: "")
				$0.disabled = Condition.function(["host", "username", "password"]) { form in
					return (form.rowBy(tag: "host") as? TextRow)?.value?.isEmpty ?? true
						|| (form.rowBy(tag: "username") as? AccountRow)?.value?.isEmpty ?? true
						|| (form.rowBy(tag: "password") as? PasswordRow)?.value?.isEmpty ?? true
				}
			}
			.onCellSelection { _, row in
				if !row.isDisabled {
					Settings.nextcloudServer = (self.form.rowBy(tag: "host") as? TextRow)?.value
					Settings.nextcloudUsername = (self.form.rowBy(tag: "username") as? AccountRow)?.value
					Settings.nextcloudPassword = (self.form.rowBy(tag: "password") as? PasswordRow)?.value

					MBProgressHUD.showAdded(to: self.navigationController?.view ?? self.view, animated: true)

					Nextcloud.sync { error in
						DispatchQueue.main.async {
							MBProgressHUD.hide(for: self.navigationController?.view ?? self.view, animated: true)

							if let error = error {
								AlertHelper.present(self, message: error.localizedDescription)
							}
						}

						self.delegate?.needsReload()
					}
				}
			}
	}
}
