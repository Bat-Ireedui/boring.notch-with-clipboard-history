//
//  ClipboardSettingsView.swift
//  boringNotch
//
//  Created by Bat-Ireedui on 2026-09-04.
//

import Defaults
import KeyboardShortcuts
import SwiftUI

struct ClipboardSettings: View {
    @Default(.clipboardHistoryLimit) var historyLimit
    @Default(.clipboardHistoryEnabled) var historyEnabled
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var showClearConfirmation = false

    private let limitOptions = [25, 50, 100, 200]

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .clipboardHistoryEnabled) {
                    Text("Enable clipboard history")
                }
                Defaults.Toggle(key: .clipboardCaptureImages) {
                    Text("Capture images")
                }
                .disabled(!historyEnabled)
                Defaults.Toggle(key: .clipboardCloseNotchAfterCopy) {
                    Text("Close notch after copying an item")
                }
                .disabled(!historyEnabled)
                Picker("History size", selection: $historyLimit) {
                    ForEach(limitOptions, id: \.self) { option in
                        Text("\(option) items").tag(option)
                    }
                }
                .disabled(!historyEnabled)
            } header: {
                Text("General")
            } footer: {
                Text("Content marked as confidential by password managers is never recorded. Pinned items are kept regardless of the history size.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                KeyboardShortcuts.Recorder("Open clipboard history:", name: .clipboardHistoryPanel)
            } header: {
                Text("Shortcut")
            } footer: {
                Text("Opens the notch on the Clipboard tab. Press again to close it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Text(storageLabel)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Clear History…", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(manager.items.isEmpty)
                }
            } header: {
                Text("Storage")
            }
        }
        .confirmationDialog("Clear clipboard history?", isPresented: $showClearConfirmation) {
            Button("Clear Unpinned Items") { manager.clear() }
            Button("Clear Everything", role: .destructive) { manager.clear(includingPinned: true) }
            Button("Cancel", role: .cancel) {}
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Clipboard")
    }

    private var storageLabel: String {
        let total = manager.items.count
        let pinned = manager.pinnedItems.count
        if total == 0 { return "No items stored" }
        var label = total == 1 ? "1 item stored" : "\(total) items stored"
        if pinned > 0 { label += " (\(pinned) pinned)" }
        return label
    }
}
