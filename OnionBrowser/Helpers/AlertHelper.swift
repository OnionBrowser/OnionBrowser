//
//  AlertHelper.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 18.01.19.
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

public class AlertHelper {

    public typealias ActionHandler = (UIAlertAction) -> Void

    /**
     Creates and immediately presents a `UIAlertController`.
     Alert style is `.alert`, presentation will be animated.

     if `actions` is ommitted, it will have one action of type `.default` labeled "OK".

     - parameter controller: The `UIViewController` to present on.
     - parameter message: The alert message. Optional.
     - parameter title: The alert title. Optional, defaults to localized "Error".
     - parameter style: The alert style, defaults to `.alert`.
     - parameter actions: A list of actions. Optional, defaults to one localized "OK" default action.
    */
    public class func present(_ controller: UIViewController,
                       message: String? = nil,
                       title: String? = NSLocalizedString("Error", comment: ""),
                       style: UIAlertController.Style = .alert,
                       actions: [UIAlertAction]? = [defaultAction()]) {

        controller.present(build(message: message, title: title, style: style, actions: actions),
                           animated: true)
    }

    /**
     Creates a `UIAlertController`.
     Alert style is `.alert`.

     if `actions` is ommitted, it will have one action of type `.default` labeled "OK".

     - parameter message: The alert message. Optional.
     - parameter title: The alert title. Optional, defaults to localized "Error".
     - parameter actions: A list of actions. Optional, defaults to one localized "OK" default action.
     */
    public class func build(message: String? = nil,
                     title: String? = NSLocalizedString("Error", comment: ""),
                     style: UIAlertController.Style = .alert,
                     actions: [UIAlertAction]? = [defaultAction()]) -> UIAlertController {

        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: style)

        for action in actions ?? [] {
            alert.addAction(action)
        }

        return alert
    }
    
    /**
     - parameter title: The action's title. Optional, defaults to localized "OK".
     - parameter handler: The callback when the user tapped the action.
     - returns: A default `UIAlertAction`.
     */
    public class func defaultAction(_ title: String? = NSLocalizedString("OK", comment: ""),
                             handler: ActionHandler? = nil) -> UIAlertAction {
        return UIAlertAction(title: title, style: .default, handler: handler)
    }

    /**
     - parameter title: The action's title. Optional, defaults to localized "Cancel".
     - parameter handler: The callback when the user tapped the action. Optional.
     - returns: A cancel `UIAlertAction`.
     */
	public class func cancelAction(_ title: String? = NSLocalizedString("Cancel", comment: ""),
                            handler: ActionHandler? = nil) -> UIAlertAction {
        return UIAlertAction(title: title, style: .cancel, handler: handler)
    }

    /**
     - parameter title: The action's title.
     - parameter handler: The callback when the user tapped the action.
     - returns: A destructive `UIAlertAction`.
     */
    public class func destructiveAction(_ title: String?, handler: ActionHandler? = nil) -> UIAlertAction {
        return UIAlertAction(title: title, style: .destructive, handler: handler)
    }


    /**
     Add a `UITextField` to a given `UIAlertController`.

     - parameter alert: The alert controller to add the text field to.
     - parameter placeholder: The placeholder string. Defaults to `nil`.
     - parameter text: The text content to begin with. Defaults to `nil`.
     - parameter configurationHandler: A block for configuring the text field
        further. This block has no return value and takes
        a single parameter corresponding to the text field object.
        Use that parameter to change the text field properties.
    */
    public class func addTextField(_ alert: UIAlertController, placeholder: String? = nil,
                            text: String? = nil, configurationHandler: ((UITextField) -> Void)? = nil) {
        alert.addTextField() { textField in
            textField.clearButtonMode = .whileEditing
            textField.placeholder = placeholder
            textField.text = text

            configurationHandler?(textField)
        }
    }

    /**
     Add a `UITextField` in password entry style to a given `UIAlertController`.

     - parameter alert: The alert controller to add the text field to.
     - parameter placeholder: The placeholder string. Defaults to `nil`.
     - parameter text: The text content to begin with. Defaults to `nil`.
     - parameter configurationHandler: A block for configuring the text field
         further. This block has no return value and takes
         a single parameter corresponding to the text field object.
         Use that parameter to change the text field properties.
     */
    public class func addPasswordField(_ alert: UIAlertController, placeholder: String? = nil,
                                text: String? = nil, configurationHandler: ((UITextField) -> Void)? = nil) {
        addTextField(alert, placeholder: placeholder, text: text) { textField in
            textField.autocorrectionType = .no
            textField.autocapitalizationType = .none
            textField.keyboardType = .asciiCapable
            textField.isSecureTextEntry = true

            configurationHandler?(textField)
        }
    }
}
