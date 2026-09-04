//
//  ClipboardHistoryView.swift
//  boringNotch
//
//  Created by Bat-Ireedui on 2026-09-04.
//

import AppKit
import Defaults
import SwiftUI

// MARK: - Filter

enum ClipboardFilter: String, CaseIterable, Identifiable {
    case all, text, links, images, files, pinned

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "text.alignleft"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "doc"
        case .pinned: return "pin"
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .links: return "Links"
        case .images: return "Images"
        case .files: return "Files"
        case .pinned: return "Pinned"
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.isText
        case .links: return item.isLink
        case .images: return item.isImage
        case .files: return item.isFiles
        case .pinned: return item.isPinned
        }
    }
}

// MARK: - History view

struct ClipboardHistoryView: View {
    @EnvironmentObject var vm: BoringViewModel
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var filter: ClipboardFilter = .all
    @State private var confirmingClear = false
    @State private var clearResetTask: Task<Void, Never>?
    @State private var closeTask: Task<Void, Never>?
    @Namespace private var filterNamespace

    private var filteredItems: [ClipboardItem] {
        manager.items
            .filter(filter.matches)
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                return lhs.createdAt > rhs.createdAt
            }
    }

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            if filteredItems.isEmpty {
                emptyState
            } else {
                cards
            }
        }
        .onDisappear {
            clearResetTask?.cancel()
            confirmingClear = false
        }
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(ClipboardFilter.allCases) { option in
                    Button {
                        withAnimation(.smooth(duration: 0.25)) { filter = option }
                    } label: {
                        Image(systemName: option.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 30, height: 20)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(filter == option ? .white : .gray)
                    .background {
                        if filter == option {
                            Capsule()
                                .fill(Color(nsColor: .secondarySystemFill))
                                .matchedGeometryEffect(id: "clipboardFilter", in: filterNamespace)
                        }
                    }
                    .help(option.label)
                }
            }
            .padding(2)
            .background(Capsule().fill(Color.white.opacity(0.05)))

            Spacer(minLength: 0)

            Text(countLabel)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.gray)
                .lineLimit(1)

            Button(action: handleClear) {
                HStack(spacing: 4) {
                    Image(systemName: confirmingClear ? "trash.fill" : "trash")
                    if confirmingClear {
                        Text("Clear?")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(
                    Capsule().fill(confirmingClear ? Color.red.opacity(0.4) : Color.white.opacity(0.05))
                )
                .foregroundStyle(confirmingClear ? .white : .gray)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(manager.items.isEmpty)
            .opacity(manager.items.isEmpty ? 0.4 : 1)
            .help("Clear unpinned items")
            .animation(.smooth(duration: 0.2), value: confirmingClear)
        }
    }

    private var countLabel: String {
        let count = filteredItems.count
        if filter == .all {
            return count == 1 ? "1 item" : "\(count) items"
        }
        return "\(count) of \(manager.items.count)"
    }

    private func handleClear() {
        clearResetTask?.cancel()
        if confirmingClear {
            withAnimation(.smooth) {
                manager.clear()
                confirmingClear = false
            }
            return
        }
        confirmingClear = true
        clearResetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            confirmingClear = false
        }
    }

    // MARK: Cards

    private var cards: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(filteredItems) { item in
                        ClipboardItemCard(item: item, now: context.date) {
                            copy(item)
                        }
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .animation(.smooth(duration: 0.25), value: manager.items)
            }
            .scrollIndicators(.never)
        }
        .frame(maxHeight: .infinity)
    }

    private func copy(_ item: ClipboardItem) {
        manager.copy(item)
        guard Defaults[.clipboardCloseNotchAfterCopy] else { return }
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled else { return }
            vm.close()
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(
                Color.white.opacity(0.1),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [10])
            )
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: filter == .all ? "doc.on.clipboard" : filter.symbol)
                        .symbolVariant(.fill)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white, .gray)
                        .imageScale(.large)
                    Text(filter == .all ? "Nothing copied yet" : "No \(filter.label.lowercased()) in history")
                        .foregroundStyle(.gray)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.medium)
                    if filter == .all {
                        Text("Copied text, links, images and files show up here")
                            .font(.caption)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Card

struct ClipboardItemCard: View {
    let item: ClipboardItem
    let now: Date
    let onCopy: () -> Void

    @ObservedObject private var manager = ClipboardManager.shared
    @State private var isHovering = false
    @State private var showCopied = false
    @State private var copiedTask: Task<Void, Never>?

    private let cardWidth: CGFloat = 158
    private let cornerRadius: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(8)
        .frame(width: cardWidth)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white.opacity(isHovering ? 0.12 : 0.06))
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Color.white.opacity(item.isPinned ? 0.28 : 0.08), lineWidth: 1)
        )
        .overlay {
            if showCopied {
                copiedOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .scaleEffect(isHovering ? 1.015 : 1)
        .onTapGesture(perform: handleCopy)
        .onHover { hovering in
            withAnimation(.smooth(duration: 0.18)) { isHovering = hovering }
        }
        .contextMenu { contextMenu }
        .help(item.previewText)
        .onDisappear { copiedTask?.cancel() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 5) {
            sourceIcon
            Text(item.kindLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.gray)
                .lineLimit(1)

            Spacer(minLength: 2)

            if isHovering && !showCopied {
                cardActionButton(item.isPinned ? "pin.slash.fill" : "pin.fill", help: item.isPinned ? "Unpin" : "Pin") {
                    withAnimation(.smooth) { manager.togglePin(item) }
                }
                cardActionButton("xmark", help: "Delete") {
                    withAnimation(.smooth) { manager.remove(item) }
                }
            } else {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .rotationEffect(.degrees(45))
                }
                Text(relativeTime)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .frame(height: 16)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundleID = item.sourceBundleID, let icon = AppIconAsNSImage(for: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
        } else {
            Image(systemName: item.symbolName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.gray)
                .frame(width: 14, height: 14)
        }
    }

    private func cardActionButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.white.opacity(0.15)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch item.kind {
        case .text(let text):
            Text(item.previewText.isEmpty ? text : item.previewText)
                .font(item.usesMonospacedFont ? .system(size: 10.5, design: .monospaced) : .system(size: 11.5))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)

        case .link(let url):
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.gray)
                    Text(url.host ?? url.absoluteString)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(url.absoluteString)
                    .font(.system(size: 10))
                    .foregroundStyle(.gray)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }

        case .image:
            if let image = manager.image(for: item) {
                Color.clear
                    .overlay {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.gray)
            }

        case .files(let paths):
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: -8) {
                    ForEach(Array(paths.prefix(3).enumerated()), id: \.offset) { _, path in
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                    }
                    if paths.count > 3 {
                        Text("+\(paths.count - 3)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                            .padding(.leading, 12)
                    }
                }
                Text(item.previewText)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private var copiedOverlay: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.black.opacity(0.65))
            .overlay {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.green)
                    Text("Copied")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
    }

    // MARK: Context menu

    @ViewBuilder
    private var contextMenu: some View {
        Button("Copy", action: handleCopy)
        Button(item.isPinned ? "Unpin" : "Pin") { manager.togglePin(item) }
        Divider()
        if let url = item.linkURL {
            Button("Open in Browser") { NSWorkspace.shared.open(url) }
        }
        if item.isFiles {
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting(item.fileURLs)
            }
        }
        Divider()
        Button("Delete", role: .destructive) { manager.remove(item) }
    }

    // MARK: Helpers

    private func handleCopy() {
        copiedTask?.cancel()
        withAnimation(.smooth(duration: 0.2)) { showCopied = true }
        onCopy()
        copiedTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.smooth(duration: 0.25)) { showCopied = false }
        }
    }

    private var relativeTime: String {
        let seconds = max(0, Int(now.timeIntervalSince(item.createdAt)))
        switch seconds {
        case 0..<60: return "now"
        case 60..<3600: return "\(seconds / 60)m"
        case 3600..<86400: return "\(seconds / 3600)h"
        default: return "\(seconds / 86400)d"
        }
    }
}

#Preview {
    ClipboardHistoryView()
        .environmentObject(BoringViewModel())
        .frame(width: 600, height: 130)
        .padding()
        .background(.black)
}
