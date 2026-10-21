//
//  QuickEventWrapperView.swift
//  Clendar
//
//  Created by Vĩnh Nguyễn on 11/19/20.
//  Copyright © 2020 Vinh Nguyen. All rights reserved.
//

import ClendarTheme
import EventKit
import SwiftUI
import Shift
import UIKit

struct QuickEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var store: SharedStore
    @StateObject private var quickEventStore = TextFieldObserver()
    @State private var parsedText = ""
    @State private var isAllDay = false
    @State private var startTime = Date()
    @State private var endTime = Date().offsetWithDefaultDuration

    var body: some View {
        VStack {
            HStack {
                Button(
                    action: {
                        genLightHaptic()
                        presentationMode.wrappedValue.dismiss()
                    },
                    label: {
                        Image(systemName: "chevron.down")
                            .font(.boldFontWithSize(20))
                    }
                )
                    .accentColor(.appRed)
                    .keyboardShortcut(.escape)
                    .help("Collapse this view")

                Spacer()
                Text("New Event")
                    .font(.semiboldFontWithSize(15))
                Spacer()

                Button(
                    action: {
                        createNewEvent()
                    },
                    label: {
                        Image(systemName: "calendar.badge.plus")
                            .font(.boldFontWithSize(20))
                    }
                )
                    .accentColor(.appRed)
                    .disabled(quickEventStore.searchText.isEmpty)
                    .keyboardShortcut("s", modifiers: [.command])
                    .help("Create new event")
            }

            Divider()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer()

                    InlinePredictionTextField(
                        text: $quickEventStore.searchText,
                        placeholder: NSLocalizedString("read a book this Friday 8PM...", comment: ""),
                        onSubmit: {
                            parse(quickEventStore.searchText)
                        }
                    )
                    .frame(maxWidth: .infinity)
                    .accessibility(label: Text("Input event"))

                    Toggle("All day", isOn: $isAllDay)
                        .keyboardShortcut(.tab)
                        .font(.mediumFontWithSize(15))
                        .toggleStyle(SwitchToggleStyle(tint: .appRed))
                        .fixedSize()

                    if !isAllDay {
                        Divider()

                        VStack {
                            Text("Start time")
                                .font(.semiboldFontWithSize(15))
                            DatePicker("Start time", selection: $startTime)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .font(.mediumFontWithSize(15))
                                .accessibility(label: Text("Select event start time"))
                        }

                        Divider()

                        VStack {
                            Text("End time")
                                .font(.semiboldFontWithSize(15))
                            DatePicker("End time", selection: $endTime)
                                .datePickerStyle(GraphicalDatePickerStyle())
                                .font(.mediumFontWithSize(15))
                                .accessibility(label: Text("Select event end time"))
                        }
                    }
                }
                .padding(.bottom, 300)
            }
        }
        .onReceive(quickEventStore.$debouncedText) { output in
            self.parse(output)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .preferredColorScheme(appColorScheme)
        .environment(\.colorScheme, appColorScheme)
        .background(store.appBackgroundColor.edgesIgnoringSafeArea(.all))
    }
}

extension QuickEventView {
    // MARK: - Private

    @discardableResult
    private func parse(_ text: String) -> Bool {
        guard text.isEmpty == false else { return false }
        guard let result = NaturalInputParser().parse(text) else { return false }
        parsedText = result.parsedText
        startTime = result.startDate
        endTime = result.endDate ?? result.startDate.offsetWithDefaultDuration
        return true
    }

    private func createNewEvent() {
        guard quickEventStore.searchText.isEmpty == false else { return }
        Task {
            do {
                let calendar = Shift.shared.eventStore.defaultCalendarFromSettings
                let createdEvent = try await Shift.shared.createEvent(
                    parsedText,
                    startDate: startTime,
                    endDate: endTime,
                    isAllDay: isAllDay,
                    calendar: calendar
                )

                genSuccessHaptic()
                self.presentationMode.wrappedValue.dismiss()
                self.store.selectedDate = createdEvent.startDate
            } catch {
                genErrorHaptic()
                AlertManager.showWithError(error)
            }
        }
    }
}

private struct InlinePredictionTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let textField = UITextField()
        textField.delegate = context.coordinator
        textField.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        textField.font = .regularFontWithSize(18)
        textField.textColor = .appDark
        textField.autocorrectionType = .yes
        textField.returnKeyType = .done
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .font: UIFont.regularFontWithSize(18),
                .foregroundColor: UIColor.placeholderText
            ]
        )
        textField.accessibilityLabel = NSLocalizedString("Input event", comment: "")
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        if #available(iOS 17.0, *) {
            textField.inlinePredictionType = .yes
        }
        return textField
    }

    func updateUIView(_ textField: UITextField, context: Context) {
        context.coordinator.parent = self
        if textField.text != text {
            textField.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InlinePredictionTextField

        init(_ parent: InlinePredictionTextField) {
            self.parent = parent
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            parent.onSubmit()
            return false
        }
    }
}
