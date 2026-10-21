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

        // Never force-unwrap in the extension: a crash renders as a
        // blank/white widget with no retry until the next reload (issue #268).
        guard let interval = Calendar.autoupdatingCurrent.date(byAdding: .minute, value: 5, to: currentDate) else {
            completion(Timeline(entries: [WidgetEntry(date: currentDate)], policy: .after(currentDate.addingTimeInterval(5 * 60))))
            return
        }

        Task {
            // Event fetch failure still completes with an empty list so the
            // date grid always renders instead of going white.
            let events = (try? await Shift.shared.fetchEventsRangeUntilEndOfDay(from: currentDate)) ?? []
            let clendarEvents = events.compactMap(ClendarEvent.init)
            var entry = WidgetEntry(date: currentDate, events: clendarEvents)
            // Travel times are best effort. Any failure leaves the entry
            // without them and the rows render as before (issue #176).
            let mode = widgetTravelMode()
            entry.travelMode = mode
            entry.travelTimes = await TravelTimeProvider.travelTimes(for: events, mode: mode)
            let timeline = Timeline(entries: [entry], policy: .after(interval))
            completion(timeline)
        }
    }

    /// Travel mode chosen in Settings, shared via the app group file.
    private func widgetTravelMode() -> TravelMode {
        guard let containerURL = FileManager.appGroupContainerURL else { return TravelMode.defaultValue }
        let url = containerURL.appendingPathComponent(FileManager.travelMode)
        guard let value = try? String(contentsOf: url, encoding: .utf8) else {
            return TravelMode.defaultValue
        }
        return TravelMode(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? TravelMode.defaultValue
    }

    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry(date: Date())
    }
}
