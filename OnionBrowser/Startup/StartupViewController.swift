//
//  StartupViewController.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.01.20.
//  Copyright (c) 2012-2020, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit
import UIImageViewAlignedSwift

class StartupViewController: UINavigationController {

	class func instantiate() -> UIViewController? {
		return UIStoryboard(name: "Startup", bundle: nil).instantiateInitialViewController()
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		isNavigationBarHidden = true

		if Settings.didIntro,
			let vc = storyboard?.instantiateViewController(withIdentifier:
				String(describing: ConnectingViewController.self)) as? ConnectingViewController {

			vc.autoClose = true
			viewControllers = [vc]

			return
		}

		let backgroundImg = UIImageViewAligned(frame: view.bounds)
		backgroundImg.image = UIImage(named: "background")
		backgroundImg.contentMode = .scaleAspectFill

		if UIView.userInterfaceLayoutDirection(for: view.semanticContentAttribute) == .rightToLeft {
			backgroundImg.alignRight = true
		}
		else {
			backgroundImg.alignLeft = true
		}

		view.insertSubview(backgroundImg, at: 0)
		backgroundImg.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
		backgroundImg.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
		backgroundImg.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
		backgroundImg.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
	}
}
