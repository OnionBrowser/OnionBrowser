//
//  BrowsingViewController+UIResponder.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 15.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas). All rights reserved.
//

import UIKit

extension BrowsingViewController {

	override var keyCommands: [UIKeyCommand]? {
		// If settings are up or something else, ignore shortcuts.
		if !(view.window?.rootViewController is BrowsingViewController)
			|| presentedViewController != nil
		{
			return nil
		}

		var commands = [
			UIKeyCommand(title: NSLocalizedString("Go Back", comment: ""),
						 action: #selector(handle(_:)), input: "[", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Go Forward", comment: ""),
						 action: #selector(handle(_:)), input: "]", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Show Bookmarks", comment: ""),
						 action: #selector(handle(_:)), input: "b", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Focus URL Field", comment: ""),
						 action: #selector(handle(_:)), input: "l", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Reload Tab", comment: ""),
						 action: #selector(handle(_:)), input: "r", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Create New Tab", comment: ""),
						 action: #selector(handle(_:)), input: "t", modifierFlags: .command),
			UIKeyCommand(title: NSLocalizedString("Close Tab", comment: ""),
						 action: #selector(handle(_:)), input: "w", modifierFlags: .command),
		]

		for i in 1 ... 10 {
			commands.append(UIKeyCommand(
				title: String(format: NSLocalizedString("Switch to Tab %d", comment: ""), i),
				action: #selector(handle(_:)), input: String(i % 10), modifierFlags: .command))
		}

		return commands
	}

	@objc
	private func handle(_ keyCommand: UIKeyCommand) {
		if keyCommand.modifierFlags == .command {
			switch keyCommand.input {
			case "b":
				showBookmarks()
				return

			case "l":
				focusSearchField()
				return

			case "r":
				currentTab?.refresh()
				return

			case "t":
				addEmptyTabAndFocus()
				return

			case "w":
				removeCurrentTab()
				return

			case "[":
				currentTab?.goBack()
				return

			case "]":
				currentTab?.goForward()
				return

			default:
				for i in 0 ... 9 {
					if keyCommand.input == String(i) {
						switchToTab(i == 0 ? tabs.count - 1 : i - 1)
						return
					}
				}
			}
		}
	}
}
