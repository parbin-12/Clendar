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
            let entry = WidgetEntry(date: currentDate, events: clendarEvents)
            let timeline = Timeline(entries: [entry], policy: .after(interval))
            completion(timeline)
        }
    }

    func placeholder(in _: Context) -> WidgetEntry {
        WidgetEntry(date: Date())
    }
}
