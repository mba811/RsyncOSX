//
//  PersistentStorageConfigurationJSON.swift
//  RsyncOSX
//
//  Created by Thomas Evensen on 20/10/2020.
//  Copyright © 2020 Thomas Evensen. All rights reserved.
//
// swiftlint:disable line_length

import Foundation

class PersistentStorageConfigurationJSON: PersistentStorageConfiguration {
    // Saving Configuration from MEMORY to persistent store
    // Reads Configurations from MEMORY and saves to persistent Store
    override func saveconfigInMemoryToPersistentStore() {
        if let configurations = self.configurations?.getConfigurations() {
            self.writeToStore(configurations: configurations)
        }
    }

    // Add new configuration in memory to permanent storage
    override func newConfigurations(dict: NSMutableDictionary) {
        var array = [NSDictionary]()
        if let configs: [Configuration] = self.configurations?.getConfigurations() {
            for i in 0 ..< configs.count {
                if let dict: NSMutableDictionary = ConvertConfigurations(index: i).configuration {
                    array.append(dict)
                }
            }
            dict.setObject(self.maxhiddenID + 1, forKey: "hiddenID" as NSCopying)
            array.append(dict)
            self.configurations?.appendconfigurationstomemory(dict: array[array.count - 1])
            self.saveconfigInMemoryToPersistentStore()
        }
    }

    private func writeToStore(configurations: [Configuration]?) {
        let store = ReadWriteConfigurationsJSON(configurations: configurations, profile: self.profile)
        store.writeJSONToPersistentStore()
        self.configurationsDelegate?.reloadconfigurationsobject()
        if ViewControllerReference.shared.menuappisrunning {
            Notifications().showNotification(message: "Sending reload message to menu app")
            DistributedNotificationCenter.default().postNotificationName(NSNotification.Name("no.blogspot.RsyncOSX.reload"), object: nil, deliverImmediately: true)
        }
    }
}