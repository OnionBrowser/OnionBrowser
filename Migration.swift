/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

import UIKit
import CoreData


class Migration: NSObject {

    /**
        Migrates bookmarks and bridge settings of version 1.x to 2.x.
    */
    class func migrate() {
        let storeUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last?
            .appendingPathComponent("Settings.sqlite")

        let isReachable = try? storeUrl?.checkResourceIsReachable()

        // Check, if CoreData SQLite file is there, if so migrate bookmarks and bridge settings.
        if isReachable != nil && isReachable! != nil && isReachable!!
        {
            // Initialize CoreData.
            if let mom = NSManagedObjectModel.mergedModel(from: nil)
            {
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

                if oldBridges != nil && oldBridges!.count > 0
                {
                    let settings = UserDefaults.standard

                    // Don't show intro to bridge users - otherwise these settings are lost.
                    settings.set(true, forKey: DID_INTRO)

                    // Detect default Meek bridges.
                    if oldBridges!.count == 1
                    {
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

                    if let oldBookmarks = try? moc.fetch(request)
                    {
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
                        if store != nil
                        {
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
    }
}
