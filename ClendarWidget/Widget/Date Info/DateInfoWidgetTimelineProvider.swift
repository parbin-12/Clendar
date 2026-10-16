//
//  ClendarWidgetTimeline.swift
//  ClendarWidgetExtension
//
//  Created by Vinh Nguyen on 10/31/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import SwiftUI
import WidgetKit
import Shift
import ClendarTheme

// Reference: https://wwdcbysundell.com/2020/getting-started-with-widgetkit/

struct DateInfoWidgetTimelineProvider: TimelineProvider {
    typealias Entry = WidgetEntry

    func getSnapshot(in _: Context, completion: @escaping (WidgetEntry) -> Void) {
        let entry = WidgetEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in _: Context, completion: @escaping (Timeline<WidgetEntry>) -> Void) {

        let currentDate = Date()

        // swiftlint:disable:next force_unwrapping
        let interval = Calendar.autoupdatingCurrent.date(byAdding: .minute, value: 5, to: currentDate)!

        Task {
            var entries = [WidgetEntry]()
            let events = (try? await Shift.shared.fetchEventsRangeUntilEndOfDay(from: currentDate)) ?? []
            let clendarEvents = events.compactMap(ClendarEvent.init)
            var entry = WidgetEntry(date: interval, events: clendarEvents)
            // Travel times are best effort. Any failure leaves the entry
            // without them and the rows render as before (issue #176).
            let mode = widgetTravelMode()
            entry.travelMode = mode
            entry.travelTimes = await TravelTimeProvider.travelTimes(for: events, mode: mode)
            entries.append(entry)

            let timeline = Timeline(entries: entries, policy: .after(interval))
            completion(timeline)
        }
    }

    /// Travel mode chosen in Settings, shared via the app group file.
    private func widgetTravelMode() -> TravelMode {
        let url = FileManager.appGroupContainerURL.appendingPathComponent(FileManager.travelMode)
        guard let value = try? String(contentsOf: url, encoding: .utf8) else {
            return TravelMode.defaultValue
        }
        return TravelMode(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? TravelMode.defaultValue
    }

    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry(date: Date())
    }
}
