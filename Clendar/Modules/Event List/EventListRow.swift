//
//  EventListRow.swift
//  Clendar
//
//  Created by Vĩnh Nguyễn on 11/20/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import SwiftUI
import EventKit
import ClendarTheme

struct EventListRow: View {
    var id = UUID() // somehow this fix problem when row should be reload after changes. Reference: https://github.com/onmyway133/blog/issues/625
    var event: ClendarEvent?

    @State private var travelText: String?

    var body: some View {
        if let ekEvent = event?.event {
            GroupBox(
                label:
                    Text(ekEvent.durationText().localizedUppercase)
                    .accessibility(label: Text("Event duration"))
                    .font(.boldFontWithSize(15))
                    .foregroundColor(Color(ekEvent.calendar.cgColor)),
                content: {
                    Text(ekEvent.title)
                        .accessibility(label: Text("Title of the event"))
                        .lineLimit(2)
                        .font(.mediumFontWithSize(17))
                        .foregroundColor(.appDark)
                        .padding(.top, 5)
                    if let travelText = travelText {
                        Text(travelText)
                            .accessibility(label: Text("Travel time to the event"))
                            .lineLimit(1)
                            .font(.mediumFontWithSize(13))
                            .foregroundColor(.gray)
                            .padding(.top, 2)
                    }
                }
            )
            .opacity(ekEvent.isExpired() ? 0.3 : 1.0) // gray out past events https://github.com/vinhnx/Clendar/issues/146
            .groupBoxStyle(CardGroupBoxStyle())
            .task {
                await loadTravelTime(event: ekEvent)
            }
        }
        else {
            EmptyView().redacted(reason: .placeholder)
        }
    }

    private func loadTravelTime(event: EKEvent) async {
        let mode = TravelMode(rawValue: SettingsManager.travelMode) ?? TravelMode.defaultValue
        guard let destination = await TravelTimeProvider.coordinate(for: event, allowGeocode: true),
              let origin = await TravelTimeProvider.currentLocation() else {
            return
        }
        guard let eta = await TravelTimeProvider.eta(from: origin.coordinate, to: destination, mode: mode) else {
            return
        }
        travelText = eta.displayText(mode: mode)
    }
}
