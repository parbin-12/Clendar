//
//  FileManager+Extensions.swift
//  Clendar
//
//  Created by Vinh Nguyen on 13/01/2021.
//  Copyright © 2021 Vinh Nguyen. All rights reserved.
//

import Foundation

extension FileManager {
    // Optional: the App Group container is nil when entitlements are
    // missing (e.g. sideloaded builds). Never force-unwrap here: a crash
    // in the widget extension renders as a blank/white widget (issue #268).
    static var appGroupContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vinhnx.Clendar")
    }
}

extension FileManager {
    static let widgetTheme = "widgetTheme.txt"
}
