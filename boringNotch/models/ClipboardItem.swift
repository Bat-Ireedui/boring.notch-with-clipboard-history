//
//  ClipboardItem.swift
//  boringNotch
//
//  Created by Bat-Ireedui on 2026-09-04.
//

import AppKit
import Foundation

struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    enum Kind: Codable, Equatable, Hashable {
        case text(String)
        case link(URL)
        /// Image stored on disk as PNG under the clipboard storage directory.
        case image(fileName: String, width: Int, height: Int)
        /// One or more file URLs (stored as paths).
        case files([String])
    }

    let id: UUID
    let kind: Kind
    /// Stable identifier of the content, used to de-duplicate consecutive copies.
    let fingerprint: String
    var createdAt: Date
    let sourceBundleID: String?
    var isPinned: Bool

    init(
        id: UUID = UUID(),
        kind: Kind,
        fingerprint: String,
        createdAt: Date = Date(),
        sourceBundleID: String?,
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.fingerprint = fingerprint
        self.createdAt = createdAt
        self.sourceBundleID = sourceBundleID
        self.isPinned = isPinned
    }

    // MARK: - Presentation helpers

    var symbolName: String {
        switch kind {
        case .text(let text):
            return looksLikeCode(text) ? "chevron.left.forwardslash.chevron.right" : "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .files(let paths): return paths.count > 1 ? "doc.on.doc" : "doc"
        }
    }

    var kindLabel: String {
        switch kind {
        case .text(let text):
            let count = text.count
            if looksLikeCode(text) { return "Code" }
            return count == 1 ? "1 char" : "\(count) chars"
        case .link: return "Link"
        case .image(_, let width, let height): return "\(width)×\(height)"
        case .files(let paths): return paths.count == 1 ? "File" : "\(paths.count) files"
        }
    }

    /// Short, single-string preview suitable for a card body.
    var previewText: String {
        switch kind {
        case .text(let text):
            return String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(400))
        case .link(let url):
            return url.absoluteString
        case .image(let fileName, _, _):
            return fileName
        case .files(let paths):
            return paths.map { ($0 as NSString).lastPathComponent }.joined(separator: ", ")
        }
    }

    var isText: Bool {
        if case .text = kind { return true }
        return false
    }

    var isLink: Bool {
        if case .link = kind { return true }
        return false
    }

    var isImage: Bool {
        if case .image = kind { return true }
        return false
    }

    var isFiles: Bool {
        if case .files = kind { return true }
        return false
    }

    var fileURLs: [URL] {
        if case .files(let paths) = kind {
            return paths.map { URL(fileURLWithPath: $0) }
        }
        return []
    }

    var linkURL: URL? {
        if case .link(let url) = kind { return url }
        return nil
    }

    var usesMonospacedFont: Bool {
        if case .text(let text) = kind { return looksLikeCode(text) }
        return false
    }

    private func looksLikeCode(_ text: String) -> Bool {
        guard text.count > 12 else { return false }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let indented = lines.filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }.count
        let codeTokens: [String] = ["{", "}", "();", "=>", "->", "</", "/>", "#include", "import ", "func ", "def ", "const ", "let ", "var ", "return "]
        let tokenHits = codeTokens.filter { text.contains($0) }.count
        return (lines.count > 1 && indented >= max(1, lines.count / 3)) || tokenHits >= 3
    }
}
