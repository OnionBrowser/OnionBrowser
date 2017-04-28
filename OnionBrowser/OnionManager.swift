/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

import Foundation

@objc class OnionManager : NSObject {

    static let singleton = OnionManager()

    private static let torBaseConf: TorConfiguration = {

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
            "--clientuseipv6", "1",
            "--ClientTransportPlugin", "obfs4 socks5 127.0.0.1:47351",
            "--ClientTransportPlugin", "meek_lite socks5 127.0.0.1:47352",
        ]
        return configuration
    }()
    
    // MARK: - Built-in configuration options
    
    public static let bridgeBuiltInObfs4Args = [
        "--bridge", "obfs4 154.35.22.10:15937 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0",
        "--bridge", "obfs4 198.245.60.50:443 752CF7825B3B9EA6A98C83AC41F7099D67007EA5 cert=xpmQtKUqQ/6v5X7ijgYE/f03+l2/EuQ1dexjyUhh16wQlu/cpXUGalmhDIlhuiQPNEKmKw iat-mode=0",
        "--bridge", "obfs4 192.99.11.54:443 7B126FAB960E5AC6A629C729434FF84FB5074EC2 cert=VW5f8+IBUWpPFxF+rsiVy2wXkyTQG7vEd+rHeN2jV5LIDNu8wMNEOqZXPwHdwMVEBdqXEw iat-mode=0",
        "--bridge", "obfs4 109.105.109.165:10527 8DFCD8FB3285E855F5A55EDDA35696C743ABFC4E cert=Bvg/itxeL4TWKLP6N1MaQzSOC6tcRIBv6q57DYAZc3b2AzuM+/TfB7mqTFEfXILCjEwzVA iat-mode=1",
        "--bridge", "obfs4 83.212.101.3:50002 A09D536DD1752D542E1FBB3C9CE4449D51298239 cert=lPRQ/MXdD1t5SRZ9MquYQNT9m5DV757jtdXdlePmRCudUU9CFUOX1Tm7/meFSyPOsud7Cw iat-mode=0",
        "--bridge", "obfs4 109.105.109.147:13764 BBB28DF0F201E706BE564EFE690FE9577DD8386D cert=KfMQN/tNMFdda61hMgpiMI7pbwU1T+wxjTulYnfw+4sgvG0zSH7N7fwT10BI8MUdAD7iJA iat-mode=2",
        "--bridge", "obfs4 154.35.22.11:16488 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0",
        "--bridge", "obfs4 154.35.22.12:80 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0",
        "--bridge", "obfs4 154.35.22.13:443 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0",
        "--bridge", "obfs4 154.35.22.10:80 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0",
        "--bridge", "obfs4 154.35.22.10:443 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0",
        "--bridge", "obfs4 154.35.22.11:443 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0",
        "--bridge", "obfs4 154.35.22.11:80 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0",
        "--bridge", "obfs4 154.35.22.9:12166 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0",
        "--bridge", "obfs4 154.35.22.9:80 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0",
        "--bridge", "obfs4 154.35.22.9:443 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0",
        "--bridge", "obfs4 154.35.22.12:4304 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0",
        "--bridge", "obfs4 154.35.22.13:16815 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0",
        "--bridge", "obfs4 192.95.36.142:443 CDF2E852BF539B82BD10E27E9115A31734E378C2 cert=qUVQ0srL1JI/vO6V6m/24anYXiJD3QP2HgzUKQtQ7GRqqUvs7P+tG43RtAqdhLOALP7DJQ iat-mode=1",
        "--bridge", "obfs4 85.17.30.79:443 FC259A04A328A07FED1413E9FC6526530D9FD87A cert=RutxZlu8BtyP+y0NX7bAVD41+J/qXNhHUrKjFkRSdiBAhIHIQLhKQ2HxESAKZprn/lR3KA iat-mode=0",
        "--bridge", "obfs4 38.229.1.78:80 C8CBDB2464FC9804A69531437BCF2BE31FDD2EE4 cert=Hmyfd2ev46gGY7NoVxA9ngrPF2zCZtzskRTzoWXbxNkzeVnGFPWmrTtILRyqCTjHR+s9dg iat-mode=1"
    ];

    // MARK: - OnionManager instance

    private let torController = TorController(socketHost: "127.0.0.1", port: 39060)
    private let obfsproxy = ObfsThread()

    
    private var torThread: TorThread?
    public var torConf: TorConfiguration
    
    override init() {
        torConf = OnionManager.torBaseConf
        super.init()
    }

    func startTor(delegate: OnionManagerDelegate) {
        self.torThread = TorThread(configuration: self.torConf)
        
        self.torThread!.start()
        self.obfsproxy.start()

        print("STARTING TOR");

        // Wait long enough for tor itself to have started
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute:{
            do {
                try self.torController.connect()
            } catch {
                print("Error info: \(error)")
            }

            let cookieURL = self.torConf.dataDirectory!.appendingPathComponent("control_auth_cookie")
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
