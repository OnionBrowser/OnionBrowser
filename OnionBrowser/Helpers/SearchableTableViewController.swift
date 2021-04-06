//
//  SearchableTableViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 22.10.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class SearchableTableViewController: UITableViewController, UISearchResultsUpdating {

    let searchController = UISearchController(searchResultsController: nil)

	/**
     true, if a search filter is currently set by the user.
    */
	var isFiltering: Bool {
        return searchController.isActive
            && !(searchController.searchBar.text?.isEmpty ?? true)
    }

	var searchText: String? {
		return searchController.searchBar.text?.lowercased()
	}

	override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        definesPresentationContext = true
		navigationItem.searchController = searchController
    }

	// MARK: UISearchResultsUpdating

	func updateSearchResults(for searchController: UISearchController) {
		assertionFailure("Override in child class!")
	}
}
