//
//  EventViewer.swift
//  Clendar
//
//  Created by Vĩnh Nguyễn on 12/18/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import EventKit
import SwiftUI
import ClendarTheme

struct EventViewer: View {
    var event: ClendarEvent
    @EnvironmentObject var store: SharedStore
    @State private var didShowEventEdit = false

    @ViewBuilder
    private var editButton: some View {
        #if os(watchOS)
        editEventButton
        #else
        editEventButton
            .keyboardShortcut("e", modifiers: [.command, .shift])
        #endif

    }

    private var editEventButton: some View {
        Button(action: { didShowEventEdit.toggle() }, label: {})
           .buttonStyle(SolidButtonStyle(imageName: "square.and.pencil", title: "Edit Event", backgroundColor: event.calendarColor))
           .sheet(isPresented: $didShowEventEdit) {
               #if !os(watchOS)
               EventEditorWrapperView(event: event)
                   .environmentObject(store)
                   .modifier(ModalBackgroundModifier(backgroundColor: store.appBackgroundColor))
               #endif
           }
    }

    private var mapViewWidth: CGFloat {
        #if os(watchOS)
        return 150
        #else
        return 300
        #endif
    }

    private func makeEventInfoListView(_ event: EKEvent) -> some View {
        VStack(alignment: .leading, spacing: 30) {
            InfoWrapView(config: InfoWrapView.InfoViewConfig(title: "Start time", titleImageName: "hourglass.tophalf.fill")) {
                Text(event.startDate.toFullEventDate(calendar: store.calendar)).modifier(MediumTextModifider())
            }

            InfoWrapView(config: InfoWrapView.InfoViewConfig(title: "End time", titleImageName: "hourglass.bottomhalf.fill")) {
                Text(event.endDate.toFullEventDate(calendar: store.calendar)).modifier(MediumTextModifider())
            }

            InfoWrapView(config: InfoWrapView.InfoViewConfig(title: "All day", titleImageName: "tray.full")) {
                Text(event.isAllDay.asString).modifier(MediumTextModifider())
            }

            InfoWrapView(config: InfoWrapView.InfoViewConfig(title: "Is Recurring", titleImageName: "repeat")) {
                Text(event.hasRecurrenceRules.asString).modifier(MediumTextModifider())
            }

        }
    }

    private var eventContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Unwrap(event.event) { (event: EKEvent) in
                    Text(event.title)
                        .modifier(BoldTextModifider(fontSize: 20, color: .appDark))

                    Divider()

                    makeEventInfoListView(event)

                    #if !os(watchOS)
                    Unwrap(event.structuredLocation?.geoLocation?.coordinate) { (coordinate) in
                        Divider()

                        VStack(alignment: .leading, spacing: 10) {
                            Label("Location", systemImage: "map")
                                .modifier(BoldTextModifider(fontSize: 13, color: .primaryColor))
                            MapWrapperView(location: Location(coordinate: coordinate))
                        }
                    }

                    if event.location != nil || event.structuredLocation != nil {
                        Divider()
                        TravelTimeSection(event: event)
                    }
                    #endif
                }
            }
            .modifier(EventViewerPaddingModifier())
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            eventContentView

            #if !os(watchOS)
            editButton
            #endif
        }
        .navigationTitle("Event")
        .accentColor(event.calendarColor)
        .modifier(EventViewerPaddingModifier())
    }
}

#if !os(watchOS)
// Travel time to the appointment (issue #176). The mode picker here is
// local to this screen. The global default lives in Settings.
private struct TravelTimeSection: View {
    let event: EKEvent

    @State private var modeRaw: String = SettingsManager.travelMode
    @State private var etaText: String?
    @State private var leaveText: String?

    private var mode: TravelMode {
        TravelMode(rawValue: modeRaw) ?? TravelMode.defaultValue
    }

    var body: some View {
        InfoWrapView(config: InfoWrapView.InfoViewConfig(title: "Travel time", titleImageName: mode.systemImageName)) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: $modeRaw) {
                    ForEach(TravelMode.allCases, id: \.self) { item in
                        Text(item.localizedText).tag(item.rawValue)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                if let etaText = etaText {
                    Text(etaText).modifier(MediumTextModifider())
                }
                if let leaveText = leaveText {
                    Text(leaveText).modifier(MediumTextModifider())
                }
            }
        }
        .task(id: modeRaw) {
            await load()
        }
    }

    private func load() async {
        etaText = nil
        leaveText = nil
        let current = mode
        guard let destination = await TravelTimeProvider.coordinate(for: event, allowGeocode: true),
              let origin = await TravelTimeProvider.currentLocation() else {
            etaText = NSLocalizedString("Location unavailable", comment: "")
            return
        }
        guard let eta = await TravelTimeProvider.eta(from: origin.coordinate, to: destination, mode: current) else {
            etaText = NSLocalizedString("Route unavailable", comment: "")
            return
        }
        etaText = eta.displayText(mode: current)
        let leaveDate = event.startDate.addingTimeInterval(-eta.seconds)
        if leaveDate <= Date() {
            leaveText = NSLocalizedString("Leave now", comment: "")
        } else {
            leaveText = NSLocalizedString("Leave at ", comment: "") + leaveDate.toHourAndMinuteString()
        }
    }
}
#endif

// swiftlint:disable:next private_over_fileprivate
fileprivate struct EventViewerPaddingModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if os(watchOS)
        return content
        #else
        return content.padding()
        #endif
    }
}
