//
//  WidgetEventRow.swift
//  ClendarWidgetExtension
//
//  Created by Vinh Nguyen on 10/31/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import Foundation
import SwiftUI
import ClendarTheme

struct WidgetEventRow: View {
	var id = UUID()
	let event: ClendarEvent
	var travelSeconds: TimeInterval?
	var travelMode: TravelMode = .car

	var body: some View {
		// NOTE: no animation/scaleEffect/isFocused here. Widgets render as
		// static snapshots on iOS 17; animation modifiers can blank the
		// widget (white screen, issue #268).
		HStack(spacing: 5) {
			WidgetEventColorBar(event: event)
			WidgetEventRowLabel(event: event, travelSeconds: travelSeconds, travelMode: travelMode)
		}
	}
}

struct WidgetEventRowLabel: View {
	let event: ClendarEvent
	var travelSeconds: TimeInterval?
	var travelMode: TravelMode = .car

	var body: some View {
        VStack(alignment: .leading) {
            let message = event.event?.title ?? "-"
            let title = event.event?.durationText(startDateOnly: true) ?? "-"
            let titleAndMessage = "[\(title)] \(message)"
            Text(titleAndMessage)
                .font(.semiboldFontWithSize(12))
                .foregroundColor(Color(.gray))
                .lineLimit(2)
            if let travelSeconds = travelSeconds {
                Text(TravelETA(seconds: travelSeconds, distanceMeters: 0, isEstimate: travelMode == .bike).displayText(mode: travelMode))
                    .font(.semiboldFontWithSize(11))
                    .foregroundColor(Color(.gray))
                    .lineLimit(1)
            }
        }
	}
}

struct WidgetEventColorBar: View {
	let event: ClendarEvent

	var body: some View {
        Capsule(style: .circular)
            .fill(event.calendarColor)
			.frame(width: 3)
	}
}
