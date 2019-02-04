/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

import UIKit
import CoreData


class Migration: NSObject {

    private static var cspTranslation = [
        HOST_SETTINGS_CSP_STRICT,
        HOST_SETTINGS_CSP_BLOCK_CONNECT,
        HOST_SETTINGS_CSP_OPEN
    ]

    /**
        Migrates bookmarks, bridge settings and miscelaneous other settings of version 1.x to 2.x.
    */
    @objc class func migrate() {
        let settings = UserDefaults.standard

        let storeUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last?
            .appendingPathComponent("Settings.sqlite")

        var isReachable = try? storeUrl?.checkResourceIsReachable()

        // Check, if CoreData SQLite file is there, if so migrate bookmarks and bridge settings.
        if (isReachable ?? false) ?? false {

            // Initialize CoreData.
            if let mom = NSManagedObjectModel.mergedModel(from: nil) {
                let psc = NSPersistentStoreCoordinator.init(managedObjectModel: mom)

                let moc = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
                moc.persistentStoreCoordinator = psc

                let store = try? psc.addPersistentStore(ofType: NSSQLiteStoreType,
                                                        configurationName: nil,
                                                        at: storeUrl,
                                                        options: nil)

                // Migrate bridges. Needs to be done in the main thread, otherwise it's too late.
                let request = NSFetchRequest<Bridge>.init(entityName: "Bridge")
                let oldBridges = try? moc.fetch(request)

                if (oldBridges?.count ?? 0) > 0 {
                    // Don't show intro to bridge users - otherwise these settings are lost.
                    settings.set(true, forKey: DID_INTRO)

                    // Detect default Meek bridges.
                    if oldBridges!.count == 1 {
                        let ob = oldBridges![0];

                        if ob.conf == OnionManager.meekAmazonBridges[0]
                        {
                            settings.set(USE_BRIDGES_MEEKAMAZON, forKey: USE_BRIDGES)
                        }
                        else if ob.conf == OnionManager.meekAzureBridges[0] {
                            settings.set(USE_BRIDGES_MEEKAZURE, forKey: USE_BRIDGES)
                        }
                    }
                    else {
                        var newBridges = [String]()

                        for ob in oldBridges! {
                            newBridges.append(ob.conf)
                        }

                        settings.set(USE_BRIDGES_CUSTOM, forKey: USE_BRIDGES)
                        settings.set(newBridges, forKey: CUSTOM_BRIDGES)
                    }

                    settings.synchronize()
                }

                // Jump into a background thread to do the rest of the migration.
                DispatchQueue.global(qos: .background).async {
                    // Migrate bookmarks.
                    let request = NSFetchRequest<OldBookmark>.init(entityName: "Bookmark")
                    request.sortDescriptors = [NSSortDescriptor.init(key: "order", ascending: true)]

                    if let oldBookmarks = try? moc.fetch(request) {
                        let newBookmarks = Bookmark.list()

                        for ob in oldBookmarks {
                            let nb = Bookmark.init()
                            nb.name = ob.title
                            nb.setUrlString(ob.url)

                            newBookmarks?.add(nb)
                        }

                        Bookmark.persistList()
                    }

                    // Remove old CoreData storage.
                    do {
                        if store != nil {
                            try moc.persistentStoreCoordinator?.remove(store!)
                        }

                        try FileManager.default.removeItem(at: storeUrl!)
                    } catch {
                        // This should not happen.
                        // Can't do anything now. We tried...
                    }
                }
            }
        }

        let settingsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .last?.appendingPathComponent("Settings.plist")

        isReachable = try? settingsUrl?.checkResourceIsReachable()

        // Check, if Settings.plist file is there, if so, migrate some, which apply to Endless, too.
        if (isReachable ?? false) ?? false {
            
            DispatchQueue.global(qos: .background).async {
                if let raw = FileManager.default.contents(atPath: settingsUrl!.path) {
                    let oldSettings = try? PropertyListSerialization.propertyList(
                        from: raw,
                        options: .mutableContainersAndLeaves,
                        format: nil)
                        as? [String: Any]

                    // Homepage setting.
                    if let homepage = oldSettings??["homepage"] as? String {
                        if !homepage.isEmpty && homepage != "onionbrowser:home"
                        {
                            settings.set(homepage, forKey: "homepage")
                            settings.synchronize()
                        }
                    }

                    // Do-Not-Track header.
                    if let dnt = oldSettings??["dnt"] as? Int
                    {
                        // 1.X had 3 settings: 0 = unset, 1 = cantrack, 2 = notrack
                        // Endless has only two options "send_dnt" true or false.
                        // Translation table: 0 => false, 1 => false, 2 => true
                        settings.set(dnt == 2, forKey: "send_dnt")
                        settings.synchronize()
                    }

                    // Content security policy setting. For legacy reasons named "javascript".
                    if let csp = oldSettings??["javascript"] as? Int {
                        // From the 1.X sources:
                        // #define CONTENTPOLICY_STRICT 0 // Blocks nearly every CSP type
                        // #define CONTENTPOLICY_BLOCK_CONNECT 1 // Blocks `connect-src` (XHR, CORS, WebSocket)
                        // #define CONTENTPOLICY_PERMISSIVE 2 // Allows all content (DANGEROUS: websockets leak outside tor)

                        if let defaultHostSettings = HostSettings.default() {
                            defaultHostSettings.setSetting(HOST_SETTINGS_KEY_CSP,
                                                            toValue: cspTranslation[csp])
                            defaultHostSettings.save()
                        }
                    }

                    // Minimal TLS version. Only the "1.2 only" setting will be migrated, as 
                    // the "SSL v3" setting is not supported in Endless.
                    if let tlsver = oldSettings??["tlsver"] as? Int {
                        // From the 1.X sources:
                        // #define X_TLSVER_ANY 0
                        // #define X_TLSVER_TLS1 1
                        // #define X_TLSVER_TLS1_2_ONLY 2

                        if tlsver == 2 {
                            if let defaultHostSettings = HostSettings.default() {
                                defaultHostSettings.setSetting(HOST_SETTINGS_KEY_TLS,
                                                               toValue: HOST_SETTINGS_TLS_12)
                                defaultHostSettings.save()
                            }
                        }
                    }
                }

                do {
                    try FileManager.default.removeItem(at: settingsUrl!)
                } catch {
                    // This should not happen.
                    // Can't do anything now. We tried...
                }
            }
        }
    }
}
