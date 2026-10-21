//
//  WidgetEntry.swift
//  ClendarWidgetExtension
//
//  Created by Vinh Nguyen on 10/31/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import SwiftUI
import WidgetKit
import ClendarTheme

struct WidgetEntry: TimelineEntry {
	var date: Date
	var events: [ClendarEvent] = []
	// Travel time in seconds by event identifier, plus the mode used.
	// Filled by the timeline provider so rows render synchronously.
	var travelMode: TravelMode = .car
	var travelTimes: [String: TimeInterval] = [:]

	func travelSeconds(for event: ClendarEvent) -> TimeInterval? {
		guard let identifier = event.event?.eventIdentifier else { return nil }
		return travelTimes[identifier]
	}
}
