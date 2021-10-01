//
//  CertificateViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 21.01.20.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class CertificateViewController: UITableViewController {

	var certificate: SSLCertificate?

	private var sections = [String]()

	private var data = [[[String: String?]]]()

	private let dateFormatter: DateFormatter = {
		let df = DateFormatter()
		df.timeZone = NSTimeZone.default
		df.dateStyle = .medium
		df.timeStyle = .medium

		return df
	}()


	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.leftBarButtonItem = UIBarButtonItem(
			barButtonSystemItem: .done, target: self, action: #selector(done))

		tableView.allowsSelection = false

		if certificate?.negotiatedProtocol != .sslProtocolUnknown {
			sections.append(NSLocalizedString("Connection Information", comment: ""))

			data.append([
				kv(NSLocalizedString("Protocol", comment: ""), certificate?.negotiatedProtocolString()),
				kv(NSLocalizedString("Cipher", comment: ""), certificate?.negotiatedCipherString()),
			])
		}

		sections.append(NSLocalizedString("Certificate Information", comment: ""))

		var group: [[String: String?]] = [
			kv(NSLocalizedString("Version", comment: ""), certificate?.version.description),
			kv(NSLocalizedString("Serial Number", comment: ""), certificate?.serialNumber),
			kv(NSLocalizedString("Signature Algorithm", comment: ""), certificate?.signatureAlgorithm,
			   certificate?.hasWeakSignatureAlgorithm() ?? false ? NSLocalizedString("Error", comment: "") : nil),
		]

		if certificate?.isEV ?? false {
			group.append(kv(NSLocalizedString("Extended Validation: Organization", comment: ""),
							certificate?.evOrgName, "Ok"))
		}

		data.append(group)

		if let subject = certificate?.subject {
			sections.append(NSLocalizedString("Issued To", comment: ""))

			data.append(orderly(from: subject, wellKnows:
				[X509_KEY_CN, X509_KEY_O, X509_KEY_OU, X509_KEY_STREET, X509_KEY_L, X509_KEY_ST, X509_KEY_ZIP, X509_KEY_C]))
		}

		sections.append(NSLocalizedString("Period of Validity", comment: ""))

		data.append([
			kv(NSLocalizedString("Begins On", comment: ""),
			   dateFormatter.string(from: certificate?.validityNotBefore ?? Date(timeIntervalSince1970: 0))),
			kv(NSLocalizedString("Expires After", comment: ""),
			   dateFormatter.string(from: certificate?.validityNotAfter ?? Date(timeIntervalSince1970: 0))),
		])

		if let issuer = certificate?.issuer {
			sections.append(NSLocalizedString("Issued By", comment: ""))

			data.append(orderly(from: issuer, wellKnows:
				[X509_KEY_CN, X509_KEY_O, X509_KEY_OU, X509_KEY_STREET, X509_KEY_L, X509_KEY_ST, X509_KEY_ZIP, X509_KEY_C]))
		}
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return data.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		// #warning Incomplete implementation, return the number of rows
		return data[section].count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return sections[section]
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "info") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "info")

		let d = data[indexPath.section][indexPath.row]

		cell.textLabel?.text = d["k"] as? String
		cell.detailTextLabel?.text = d["v"] as? String

		if let colorO = d["c"], let color = colorO {
			cell.detailTextLabel?.textColor = UIColor(named: color)
		}
		else {
			cell.detailTextLabel?.textColor = nil
		}

		return cell
	}


	// MARK: Actions

	@objc
	func done() {
		dismiss(animated: true)
	}


	// MARK: Private Methods

	private func kv(_ key: String?, _ value: String?, _ color: String? = nil) -> [String: String?] {
		if color != nil {
			return ["k": key, "v": value, "c": color]
		}

		return ["k": key, "v": value]
	}

	private func orderly(from dict: [AnyHashable: Any], wellKnows: [String]) -> [[String: String?]] {
		var group = [[String: String?]]()
		var dict = dict

		// Read well-knowns in a defined order.
		for k in wellKnows {
			if let v = dict[k] as? String {
				group.append(kv(k, v))
				dict.removeValue(forKey: k)
			}
		}

		// Add the rest.
		for (k, v) in dict {
			group.append(kv(k as? String, v as? String))
		}

		return group
	}
}
