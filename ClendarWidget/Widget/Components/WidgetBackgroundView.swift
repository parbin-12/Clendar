//
//  WidgetBackgroundView.swift
//  Clendar
//
//  Created by Vinh Nguyen on 13/01/2021.
//  Copyright © 2021 Vinh Nguyen. All rights reserved.
//

import SwiftUI

struct WidgetBackgroundView: View {
    @Environment(\.colorScheme) var colorScheme

    @ViewBuilder
    var body: some View {
        switch WidgetTheme(rawValue: widgetThemeFromFile) {
        case .system:
            Color(colorScheme == .dark ? .lavixA : .hueC)
        case .dark:
            Color(.lavixA)
        case .light:
            Color(.hueC)
        case .E4ECF5:
            Color(hex: 0xE4ECF5)
        default:
            Color(.hueC)
        }
    }

    private var widgetThemeFromFile: Int {
        // Nil container (missing entitlements) or missing file falls back
        // to the default theme instead of crashing the extension, which
        // WidgetKit would render as a blank/white widget (issue #268).
        guard let containerURL = FileManager.appGroupContainerURL else { return 0 }
        let url = containerURL.appendingPathComponent(FileManager.widgetTheme)
        guard let value = try? String(contentsOf: url, encoding: .utf8) else { return 0 }
        return value.parseInt() ?? 0
    }
}
