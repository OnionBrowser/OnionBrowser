//
//  LiveSearchViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 02.12.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

class LiveSearchViewController: UITableViewController {

	var searchOngoing = false

	private var lastQuery: String?
	private var results = [String]()

	private weak var tab: Tab?

	private lazy var closeButton: UIButton = {
		let button = UIButton(type: .custom)

		button.setImage(UIImage(named: "close"), for: .normal)
		button.imageEdgeInsets = UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5)

		button.tintColor = .white
		button.backgroundColor = .lightGray

		button.clipsToBounds = true
		button.translatesAutoresizingMaskIntoConstraints = false

		button.addTarget(self, action: #selector(hide), for: .touchUpInside)

		return button
	}()


	// MARK: UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return results.count
    }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		// Needs to be a non-empty string to show the header containing the X button to close it.
		return " "
	}



    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "searchResult")
			?? UITableViewCell(style: .default, reuseIdentifier: "searchResults")

		cell.textLabel?.text = results[indexPath.row]

        return cell
    }


	// MARK: UITableViewDelegate

	override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
		if let view = view as? UITableViewHeaderFooterView {
			let size = view.frame.size.height - 8

			closeButton.layer.cornerRadius = size / 2

			view.addSubview(closeButton)
			closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8).isActive = true
			closeButton.widthAnchor.constraint(equalToConstant: size).isActive = true
			closeButton.heightAnchor.constraint(equalToConstant: size).isActive = true
			closeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
		}
	}


	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tab?.tabDelegate?.unfocusSearchField()

		tab?.search(for: results[indexPath.row])

		hide()
	}


	// MARK: Public Methods

	@objc
	func hide() {
		if !searchOngoing {
			return
		}

		if UIDevice.current.userInterfaceIdiom == .pad {
			dismiss(animated: true)
		}
		else {
			view.removeFromSuperview()
			removeFromParent()
		}

		searchOngoing = false
	}

	func update(_ query: String?, tab: Tab?) {
		let query = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

		if query.isEmpty
			|| lastQuery?.caseInsensitiveCompare(query) == .orderedSame {
			return
		}

		guard let request = LiveSearchViewController.constructRequest(query, autocomplete: true) else {
			return
		}

		self.tab = tab

		// Allow request without a tab.
		JAHPAuthenticatingHTTPProtocol.temporarilyAllow(request.url, forWebViewTab: tab)

		let task = URLSession.shared.dataTask(with: request) { data, response, error in
			if let error = error {
				print("[\(String(describing: type(of: self)))] failed auto-completing: \(error)")
				return
			}

			if self.lastQuery != query {
				print("[\(String(describing: type(of: self)))] stale query results, ignoring")
				return
			}

			guard let response = response as? HTTPURLResponse else {
				print("[\(String(describing: type(of: self)))] not a HTTP response")
				return
			}

			if response.statusCode != 200 {
				print("[\(String(describing: type(of: self)))] failed auto-completing, status \(response.statusCode)")
				return
			}

			if let data = data {
				if let contentType = (response.allHeaderFields["Content-Type"] as? String)?.lowercased(),
					contentType.contains("javascript") || contentType.contains("json") {

					if let result = try? JSONSerialization.jsonObject(with: data, options: []) as? [Any],
						result.count > 1 {

						self.results = result[1] as? [String] ?? []
					}
					else {
						print("[\(String(describing: type(of: self)))] failed parsing JSON: \(data)")
					}
				}
				else {
					self.results = String(data: data, encoding: .utf8)?.split(separator: "\n").map({ String($0) }) ?? []
				}

				DispatchQueue.main.async {
					self.tableView.reloadData()
				}
			}
		}
		task.resume()

		lastQuery = query
	}

	/**
	Constructs a request to the search engine currently selected by the user.

	- parameter query: The search query entered by the user.
	- parameter autocomplete: True, if this should use the autocompleteUrl endpoint, false, if not.
	- returns: a `URLRequest`, if a request can be constructed for that query.
	*/
	class func constructRequest(_ query: String?, autocomplete: Bool = false) -> URLRequest? {
		guard let se = Settings.searchEngine,
			var searchUrl = autocomplete ? se.autocompleteUrl : se.searchUrl,
			let query = query?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
			return nil
		}

		var params: [String]?

		if let pp = se.postParams {
			/* need to send this as a POST, so build our key val pairs */
			params = []

			for item in pp {
				guard let key = item.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
					continue
				}

				params?.append([key, String(format: item.value, query)].joined(separator: "="))
			}
		}
		else {
			searchUrl = String(format: searchUrl, query)
		}

		guard let url = URL(string: searchUrl) else {
			return nil
		}

		var request = URLRequest(url: url)

		if let postParams = params?.joined(separator: "&") {
			request.httpMethod = "POST"
			request.httpBody = postParams.data(using: .utf8)
		}

		return request
	}
}
