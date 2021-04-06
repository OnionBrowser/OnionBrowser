//
//  Tab+Keyboard.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 21.11.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

/**
Encapsulates all keyboard handling of a `Tab`.
*/
extension Tab {

	/**
	A Keyboard Map Entry.
	*/
	private struct Kme {
		let keycode: Int
		let keypressKeycode: Int
		let shiftKeycode: Int

		init(_ keycode: Int, _ keypressKeycode: Int, _ shiftKeycode: Int) {
			self.keycode = keycode
			self.keypressKeycode = keypressKeycode
			self.shiftKeycode = shiftKeycode
		}

		init(_ keycode: Int, _ keypressKeycode: Character, _ shiftKeycode: Character) {
			self.init(keycode, Int(keypressKeycode.asciiValue ?? 0), Int(shiftKeycode.asciiValue ?? 0))
		}

		init(_ keycode: Character, _ keypressKeycode: Character, _ shiftKeycode: Character) {
			self.init(Int(keycode.asciiValue ?? 0), keypressKeycode, shiftKeycode)
		}
	}

	private static let keyboardMap: [String: Kme] = [
		UIKeyCommand.inputEscape: Kme(27, 0, 0),

		"`": Kme(192, "`", "~"),
		"1": Kme("1", "1", "!"),
		"2": Kme("2", "2", "@"),
		"3": Kme("3", "3", "#"),
		"4": Kme("4", "4", "$"),
		"5": Kme("5", "5", "%"),
		"6": Kme("6", "6", "^"),
		"7": Kme("7", "7", "&"),
		"8": Kme("8", "8", "*"),
		"9": Kme("9", "9", "("),
		"0": Kme("0", "0", ")"),
		"-": Kme(189, "-", "_"),
		"=": Kme(187, "=", "+"),
		"\u{8}": Kme(8, 0, 0),

		"\t": Kme(9, 0, 0),
		"q": Kme("Q", "q", "Q"),
		"w": Kme("W", "w", "W"),
		"e": Kme("E", "e", "E"),
		"r": Kme("R", "r", "R"),
		"t": Kme("T", "t", "T"),
		"y": Kme("Y", "y", "Y"),
		"u": Kme("U", "u", "U"),
		"i": Kme("I", "i", "I"),
		"o": Kme("O", "o", "O"),
		"p": Kme("P", "p", "P"),
		"[": Kme(219, "[", "{"),
		"]": Kme(221, "]", "}"),
		"\\": Kme(220, "\\", "|"),

		"a": Kme("A", "a", "A"),
		"s": Kme("S", "s", "S"),
		"d": Kme("D", "d", "D"),
		"f": Kme("F", "f", "F"),
		"g": Kme("G", "g", "G"),
		"h": Kme("H", "h", "H"),
		"j": Kme("J", "j", "J"),
		"k": Kme("K", "k", "K"),
		"l": Kme("L", "l", "L"),
		";": Kme(186, ";", ":"),
		"'": Kme(222, "'", "\""),
		"\r": Kme(13, 0, 0),

		"z": Kme("Z", "z", "Z"),
		"x": Kme("X", "x", "X"),
		"c": Kme("C", "c", "C"),
		"v": Kme("V", "v", "V"),
		"b": Kme("B", "b", "B"),
		"n": Kme("N", "n", "N"),
		"m": Kme("M", "m", "M"),
		",": Kme(188, ",", "<"),
		".": Kme(190, ".", ">"),
		"/": Kme(191, "/", "/"),

		" ": Kme(" ", " ", " "),
		UIKeyCommand.inputLeftArrow: Kme(37, 0, 0),
		UIKeyCommand.inputUpArrow: Kme(38, 0, 0),
		UIKeyCommand.inputRightArrow: Kme(39, 0, 0),
		UIKeyCommand.inputDownArrow: Kme(40, 0, 0)
	]

	@objc
	func handleKeyCommand(_ command: UIKeyCommand) {
		let shiftKey = command.modifierFlags.contains(.shift)
		let ctrlKey = command.modifierFlags.contains(.control)
		let altKey = command.modifierFlags.contains(.alternate)
		let cmdKey = command.modifierFlags.contains(.command)

		var keycode = 0
		var keypressKeycode = 0
		let keyAction: String?

		if let input = command.input,
			let entry = Tab.keyboardMap[input] {

			keycode = entry.keycode
			keypressKeycode = shiftKey ? entry.shiftKeycode : entry.keypressKeycode
		}

		if keycode < 1 {
			return print("[Tab \(index)] unknown hardware keyboard input: \"\(command.input ?? "")\"")
		}

		switch command.input {
		case " ":
			keyAction = "__endless.smoothScroll(0, window.innerHeight * 0.75, 0, 0);"

		case UIKeyCommand.inputLeftArrow:
			keyAction = "__endless.smoothScroll(-75, 0, 0, 0);"

		case UIKeyCommand.inputRightArrow:
			keyAction = "__endless.smoothScroll(75, 0, 0, 0);"

		case UIKeyCommand.inputUpArrow:
			keyAction = cmdKey
				? "__endless.smoothScroll(0, 0, 1, 0);"
				: "__endless.smoothScroll(0, -75, 0, 0);"

		case UIKeyCommand.inputDownArrow:
			keyAction = cmdKey
				? "__endless.smoothScroll(0, 0, 0, 1);"
				: "__endless.smoothScroll(0, 75, 0, 0);"

		default:
			keyAction = nil
		}

		let js = String(format: "__endless.injectKey(%d, %d, %@, %@, %@, %@, %@);",
						keycode,
						keypressKeycode,
						(ctrlKey ? "true" : "false"),
						(altKey ? "true" : "false"),
						(shiftKey ? "true" : "false"),
						(cmdKey ? "true" : "false"),
						(keyAction != nil ? "function() { \(keyAction!) }" : "null"))

		print("[Tab \(index)] hardware keyboard input: \"\(command.input ?? "")\", keycode=\(keycode), keypressKeycode=\(keypressKeycode), modifierFlags=\(command.modifierFlags): shiftKey=\(shiftKey), ctrlKey=\(ctrlKey), altKey=\(altKey), cmdKey=\(cmdKey)")
		print("[Tab \(index)] injected JS: \(js)")

		stringByEvaluatingJavaScript(from: js)
	}
}
