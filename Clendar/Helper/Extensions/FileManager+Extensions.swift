//
//  FileManager+Extensions.swift
//  Clendar
//
//  Created by Vinh Nguyen on 13/01/2021.
//  Copyright © 2021 Vinh Nguyen. All rights reserved.
//

import Foundation

extension FileManager {
    // swiftlint:disable:next force_unwrapping
    static let appGroupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.vinhnx.Clendar")!
}

extension FileManager {
    static let widgetTheme = "widgetTheme.txt"
    static let travelMode = "travelMode.txt"
}
