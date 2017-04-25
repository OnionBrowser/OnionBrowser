/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

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
            "--log", "notice stdout",
            "--clientuseipv4", "1",
            "--clientuseipv6", "1"
        ]
        return configuration
    }()

    // MARK: -

    private let torThread: TorThread = {
        return TorThread(configuration: OnionManager.torConf)
    }()

    private let torController = TorController(socketHost: "127.0.0.1", port: 39060)


    func startTor(delegate: OnionManagerDelegate) {
        self.torThread.start()

        print("STARTING TOR");

        // Wait long enough for tor itself to have started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute:{
            do {
                try self.torController.connect()
            } catch {
                print("Error info: \(error)")
            }

            let cookieURL = OnionManager.torConf.dataDirectory!.appendingPathComponent("control_auth_cookie")
            let cookie = try? Data(contentsOf: cookieURL)

            print("cookieURL: ", cookieURL as Any)
            print("cookie: ", cookie!)

            self.torController.authenticate(with: cookie!, completion: { (success, error) in
                print("HAY")
                if (success) {


                    var completeObs:Any? = nil
                    completeObs = self.torController.addObserver(forCircuitEstablished: { (established) in
                        if (established) {
                            print("ESTABLISHED")
                            self.torController.removeObserver(completeObs)
                        }
                    }) // torController.addObserver


                    var progressObs:Any? = nil
                    progressObs = self.torController.addObserver(forStatusEvents: { (type:String, severity:String, action:String, arguments:[String : String]?) -> Bool in
                        if (type == "STATUS_CLIENT" && action == "BOOTSTRAP") {

                            let progress = arguments!["PROGRESS"]

                            delegate.torConnProgress(Int(progress!)!)

                            if (Int(progress!) == 100) {
                                self.torController.removeObserver(progressObs)
                                delegate.torConnFinished()
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
