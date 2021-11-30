//
//  Storage1ViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 17.10.19.
//  Copyright © 2019 jcs. All rights reserved.
//

import UIKit
import Eureka
import IPtProxyUI

class Storage1ViewController: FixedFormViewController {

	/**
	We need a day beginning at 00:00 of the current day with the user's timezone.

	Otherwise, we will see timezone-corrected time intervals or current time.
	*/
	private lazy var reference: Date? = {
		return Calendar.current.date(from:
			Calendar.current.dateComponents(Set([.timeZone, .year, .month, .day]), from: Date()))
	}()

	private lazy var intervalRow = LabelRow() {
		$0.title = NSLocalizedString("Auto-Sweep Interval", comment: "Option title")
		$0.cell.textLabel?.numberOfLines = 0
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Cookies and Local Storage", comment: "Scene title")

		form
		+++ LabelRow() {
			$0.title = NSLocalizedString("Cookies and Local Storage", comment: "Option title")
			$0.cell.textLabel?.numberOfLines = 0
			$0.cell.accessoryType = .disclosureIndicator
			$0.cell.selectionStyle = .default
		}
		.onCellSelection { [weak self] _, _ in
			self?.navigationController?.pushViewController(
				Storage2ViewController(), animated: true)
		}

		+++ Section(footer: NSLocalizedString(
			"Cookies and local storage data from non-allowlisted hosts will be cleared even from open tabs after not being accessed for this many minutes.",
			comment: "Option description"))

		<<< intervalRow

		<<< CountDownPickerRow() {
			if let reference = reference {
				let date = Date(timeInterval: Settings.cookieAutoSweepInterval, since: reference)
				$0.value = date

				updateIntervalRow(date)
			}
		}
		.onChange { [weak self] row in
			if let value = row.value, let reference = self?.reference {
				Settings.cookieAutoSweepInterval = value.timeIntervalSinceReferenceDate - reference.timeIntervalSinceReferenceDate

				self?.updateIntervalRow(value)
			}
		}
	}

	private func updateIntervalRow(_ date: Date) {
		let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)

		self.intervalRow.value = DateComponentsFormatter.localizedString(
			from: dateComponents, unitsStyle: .abbreviated)?.replacingOccurrences(of: ",", with: "")

		self.intervalRow.updateCell()
	}
}
