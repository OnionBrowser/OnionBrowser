//
//  SearchEnginesViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 01.12.22.
//  Copyright © 2022 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit
import Eureka
import IPtProxyUI

class SearchEnginesViewController: FixedFormViewController {

	private let section = SelectableSection<ListCheckRow<SearchEngine>>(
		nil, selectionType: .singleSelection(enableDeselection: false))


	override func viewDidLoad() {
		super.viewDidLoad()

		navigationItem.title = NSLocalizedString("Search Engine", comment: "")
		navigationItem.rightBarButtonItem = editButtonItem


		form
		+++ section

		+++ ButtonRow() {
			$0.title = NSLocalizedString("Add", comment: "")
		}
		.onCellSelection { [weak self] _, _ in
			self?.add()
		}
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		section.removeAll()

		let selected = Settings.searchEngine

		for engine in Settings.searchEngines {
			section <<< ListCheckRow<SearchEngine>() {
				$0.title = engine.name
				$0.selectableValue = engine
				$0.value = $0.selectableValue == selected ? $0.selectableValue : nil

				guard engine.type == .custom else {
					return
				}

				$0.trailingSwipe.actions.append(SwipeAction(style: .destructive, title: NSLocalizedString("Delete", comment: ""), handler: { [weak self] _, row, callback in
					guard let engine = (row as? ListCheckRow<SearchEngine>)?.selectableValue else {
						return
					}

					engine.set(details: nil)

					if Settings.searchEngine == engine {
						let engine = Settings.searchEngines.first

						let row = (self?.section.allRows as? [ListCheckRow<SearchEngine>])?.first(where: { $0.selectableValue == engine })
						row?.value = row?.selectableValue
						row?.updateCell()
					}

					callback?(true)
				}))
			}
		}

		tableView.reloadSections([0], with: .none)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		if let engine = section.selectedRow()?.value {
			Settings.searchEngine = engine
		}
	}

	override func setEditing(_ editing: Bool, animated: Bool) {
		super.setEditing(editing, animated: animated)

		tableView.setEditing(editing, animated: animated)
	}


	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if tableView.isEditing && indexPath.section == 0 {
			add((section.allRows[indexPath.row] as? ListCheckRow<SearchEngine>)?.selectableValue)
		}
		else {
			super.tableView(tableView, didSelectRowAt: indexPath)
		}
	}


	// MARK: Private Methods

	private func add(_ engine: SearchEngine? = nil) {
		let vc = AddSearchEngineViewController()
		vc.engine = engine

		navigationController?.pushViewController(vc, animated: true)
	}
}
