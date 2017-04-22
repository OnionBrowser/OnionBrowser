//
//  OnionManager.swift
//  OnionBrowser2
//
//  Created by Mike Tigas on 4/22/17.
//  Copyright © 2017 jcs. All rights reserved.
//

import Foundation

@objc class OnionManager : NSObject {

	static let singleton = OnionManager()


	private static let torConf: TorConfiguration = {

		// Create tor data directory ($TMPDIR/tor) if it does not yet exist
		/*
		let dataDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("tor", isDirectory: true)
		do {
				try FileManager.default.createDirectory(atPath: dataDir.absoluteString, withIntermediateDirectories: true, attributes: nil)
		} catch let error as NSError {
				print(error.localizedDescription);
		}
		*/
		let dataDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)


		// Configure tor and return the configuration object
		let configuration = TorConfiguration()
		configuration.cookieAuthentication = true
		configuration.dataDirectory = dataDir
		configuration.arguments = [
			"--ignore-missing-torrc",
			"--clientonly", "1",
			"--socksport", "39050",
			"--controlport", "127.0.0.1:39060",
			"--log", "notice stdout"
		]
		return configuration
	}()

	private static let torThread: TorThread = {
		return TorThread(configuration: torConf)
	}()


	private static let torController = TorController(socketHost: "127.0.0.1", port: 39060)


	static func startTor(callback:@escaping (() -> Void)) {
		self.torThread.start()

		print("STARTING TOR");

		// Wait long enough for tor itself to have started
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute:{
			do {
				try self.torController.connect()
			} catch {
				print("Error info: \(error)")
			}

			let cookieURL = torConf.dataDirectory!.appendingPathComponent("control_auth_cookie")
			let cookie = try? Data(contentsOf: cookieURL)

			print("cookieURL: ", cookieURL as Any)
			print("cookie: ", cookie!)

			self.torController.authenticate(with: cookie!, completion: { (success, error) in
				print("HAY")
				if (success) {


					var completeObs:Any? = nil
					completeObs = torController.addObserver(forCircuitEstablished: { (established) in
						if (established) {
							print("ESTABLISHED")
							self.torController.removeObserver(completeObs)
						}
					}) // torController.addObserver


					var progressObs:Any? = nil
					progressObs = torController.addObserver(forStatusEvents: { (type:String, severity:String, action:String, arguments:[String : String]?) -> Bool in
						if (type == "STATUS_CLIENT" && action == "BOOTSTRAP") {

							let progress = arguments!["PROGRESS"]
							print("PROGRESS: ", progress!);

							if (Int(progress!) == 100) {
								self.torController.removeObserver(progressObs)
								callback()
							}
							return true;
						}
						return false;
					}) // torController.addObserver



				} // if success (authenticate)
				else { print("didn't connect to control port") }
			}) // controller authenticate
		}) //delay
	}// startTor


}
/*
				id observer = [controller addObserverForCircuitEstablished:^(BOOL established) {
					if (established) {
						// Clean up.
						[controller removeObserver:observer];
						return;
					}
				}];
				/*********************/
				/*
				[controller addObserverForStatusEvents:^BOOL(NSString * _Nonnull type, NSString * _Nonnull severity, NSString * _Nonnull action, NSDictionary<NSString *,NSString *> * _Nullable arguments) {
						NSLog(@"ZZZZ: %@ - %@ - %@", type, severity, action);
						return YES;
				}];
				*/
				/*********************/

			} else {
				NSLog(@"ZZZZ control port error: %@", error);
			}
		}];

	});
*/
