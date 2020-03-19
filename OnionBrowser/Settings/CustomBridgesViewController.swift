//
//  CustomBridgesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 14.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class CustomBridgesViewController: FixedFormViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

	weak var delegate: BridgeConfDelegate?

	private static let bridgesUrl = "https://bridges.torproject.org/"

	private lazy var picker: UIImagePickerController = {
		let picker = UIImagePickerController()

		picker.sourceType = .photoLibrary
		picker.delegate = self

		return picker
	}()

	private let textAreaRow = TextAreaRow() {
		$0.placeholder = OnionManager.obfs4Bridges.first
		$0.cell.placeholderLabel?.font = .systemFont(ofSize: 15)
		$0.cell.textLabel?.font = .systemFont(ofSize: 15)
	}

	private lazy var detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])

	override func viewDidLoad() {
		super.viewDidLoad()

		textAreaRow.value = delegate?.customBridges?.joined(separator: "\n")

		navigationItem.title = NSLocalizedString("Use Custom Bridges", comment: "")
		navigationItem.rightBarButtonItem = UIBarButtonItem(
			title: NSLocalizedString("Connect", comment: ""), style: .done,
			target: self, action: #selector(connect))
		navigationItem.rightBarButtonItem?.isEnabled = !(textAreaRow.value?.isEmpty ?? true)

		form
		+++ Section(footer:
			String(format: NSLocalizedString("In a separate browser, visit %@ and tap \"Get Bridges\" > \"Just Give Me Bridges!\"",
											 comment: ""), CustomBridgesViewController.bridgesUrl))

		+++ ButtonRow() {
			$0.title = NSLocalizedString("Copy URL to Clipboard", comment: "")
		}
		.onCellSelection({ _, _ in
			UIPasteboard.general.string = CustomBridgesViewController.bridgesUrl
		})

		+++ Section(NSLocalizedString("Paste Bridges", comment: ""))
			<<< textAreaRow
			.onChange({ row in
				self.navigationItem.rightBarButtonItem?.isEnabled = !(row.value?.isEmpty ?? true)
			})

		+++ Section(NSLocalizedString("Use QR Code", comment: ""))
			<<< ButtonRow() {
				$0.title = NSLocalizedString("Scan QR Code", comment: "")
			}
			.onCellSelection({ _, _ in
				self.navigationController?.pushViewController(ScanQrViewController(), animated: true)
			})
			<<< ButtonRow() {
				$0.title = NSLocalizedString("Upload QR Code", comment: "")
			}
			.onCellSelection({ _, _ in
				self.present(self.picker)
			})
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		delegate?.customBridges = textAreaRow.value?
				.components(separatedBy: "\n")
				.map({ bridge in bridge.trimmingCharacters(in: .whitespacesAndNewlines) })
				.filter({ bridge in !bridge.isEmpty && !bridge.hasPrefix("//") && !bridge.hasPrefix("#") })

		delegate?.bridgesType = delegate?.customBridges?.isEmpty ?? true ? .none : .custom
	}

	// MARK: UIImagePickerControllerDelegate

	func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
		picker.dismiss(animated: true)

		var raw = ""

		if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
			let ciImage = image.ciImage ?? (image.cgImage != nil ? CIImage(cgImage: image.cgImage!) : nil) {

			let features = detector?.features(in: ciImage)

			for feature in features as? [CIQRCodeFeature] ?? [] {
				raw += feature.messageString ?? ""
			}
		}

		tryDecode(raw)
	}

	func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
		picker.dismiss(animated: true)
	}


	// MARK: Public Methods

	func tryDecode(_ raw: String?) {
		// They really had to use JSON for content encoding but with illegal single quotes instead
		// of double quotes as per JSON standard. Srsly?
		if let data = raw?.replacingOccurrences(of: "'", with: "\"").data(using: .utf8),
			let newBridges = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {

			textAreaRow.value = newBridges.joined(separator: "\n")
			textAreaRow.updateCell()
		}
		else {
			AlertHelper.present(self, message:
				String(format: NSLocalizedString("QR Code could not be decoded! Are you sure you scanned a QR code from %@?",
												 comment: ""), CustomBridgesViewController.bridgesUrl))
		}
	}


	// MARK: Private Methods

	@objc
	private func connect() {
		delegate?.connect()
	}
}
