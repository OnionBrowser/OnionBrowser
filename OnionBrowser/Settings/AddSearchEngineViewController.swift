//
//  AddSearchEngineViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 30.11.22.
//  Copyright © 2022 - 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import Eureka

class AddSearchEngineViewController: FixedFormViewController {

	var engine: SearchEngine?

	private lazy var nameRow = TextRow("name") {
		$0.title = NSLocalizedString("Name", comment: "")
		$0.placeholder = NSLocalizedString("My Search Engine", comment: "")

		$0.cell.textField.autocorrectionType = .no
	}

	private lazy var regexPredicate = NSPredicate(format:"SELF MATCHES %@", "^(https?):\\/\\/([\\w.:@]+)[\\/?][\\w.:\\/?=&#%@]+$")

	private lazy var urlValid = { [weak self] (value: String?) -> Bool in
		if let value = value {
			return !value.isEmpty && value.contains("%@") && self?.regexPredicate.evaluate(with: value) ?? false
		}

		return false
	}

	private lazy var searchUrlRow = AccountRow("searchUrl") {
		$0.title = NSLocalizedString("Search URL", comment: "")
		$0.placeholder = "https://example.org?q=%@"

		$0.cell.textField.keyboardType = .URL
		$0.cell.textField.textContentType = .URL
	}

	private lazy var autocompleteUrlRow = AccountRow("autocompleteUrl") {
		$0.title = NSLocalizedString("Autocomplete URL", comment: "")
		$0.placeholder = "https://example.org/suggest/q=%@"

		$0.cell.textField.keyboardType = .URL
		$0.cell.textField.textContentType = .URL
	}
	

	override func viewDidLoad() {
		super.viewDidLoad()

		if let setting = engine {
			switch setting.type {
			case .builtIn:
				// A built-in engine was selected. Copy config for a new custom entry.
				searchUrlRow.value = setting.details?.searchUrl
				autocompleteUrlRow.value = setting.details?.autocompleteUrl

				self.engine = nil

			case .custom:
				// A custom engine was selected for editing.
				nameRow.value = setting.name
				searchUrlRow.value = setting.details?.searchUrl
				autocompleteUrlRow.value = setting.details?.autocompleteUrl
			}
		}

		navigationItem.title = engine != nil
		? NSLocalizedString("Edit Search Engine", comment: "Scene title")
		: NSLocalizedString("Add Search Engine", comment: "Scene title")

		form
		+++ nameRow
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

		+++ Section(footer: NSLocalizedString("Add \"%@\" as the search term placeholder!", comment: ""))

		<<< searchUrlRow
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

		<<< autocompleteUrlRow
			.cellUpdate { cell, _ in
				cell.textField.clearButtonMode = .whileEditing
			}

		+++ ButtonRow() {
			$0.title = engine != nil ? NSLocalizedString("Update", comment: "") : NSLocalizedString("Add", comment: "")
			$0.disabled = Condition.function(["name", "searchUrl", "autocompleteUrl"], { [weak self] _ in
				self?.nameRow.value?.isEmpty ?? true
					|| !(self?.urlValid(self?.searchUrlRow.value) ?? false)
					|| !(self?.autocompleteUrlRow.value?.isEmpty ?? true
						 || self?.urlValid(self?.autocompleteUrlRow.value) ?? false)
			})
		}
		.onCellSelection { [weak self] _, row in
			guard let self = self,
				  !row.isDisabled,
				  let name = self.nameRow.value
			else {
				return
			}

			if let oldName = self.engine?.name, oldName != name {
				SearchEngine(name: oldName, type: .custom).set(details: nil)
			}

			let engine = SearchEngine(name: name, type: .custom)
			engine.set(details: .init(
				searchUrl: self.searchUrlRow.value,
				autocompleteUrl: self.autocompleteUrlRow.value))

			Settings.searchEngine = engine

			self.navigationController?.popViewController(animated: true)
		}
	}
}
