# Clipboard History

This fork adds a clipboard history feature to boring.notch.

## What changed

- **New Clipboard tab** in the open notch (next to Home and Shelf). Everything you copy shows up as a card: plain text, code (auto-detected, shown in a monospaced font), links (domain + URL), images (thumbnail) and files (icons + names). Each card shows the source app icon and a relative timestamp.
- **Click a card to copy it back** to the pasteboard. A "Copied" flash confirms it and the notch closes so you can paste with ⌘V. Hovering reveals pin and delete buttons. The context menu offers Copy, Pin/Unpin, Open in Browser (links), Reveal in Finder (files) and Delete.
- **Filter bar** (All, Text, Links, Images, Files, Pinned), an item counter and a two-click Clear button that keeps pinned items.
- **Keyboard shortcut ⇧⌘C** opens the notch directly on the Clipboard tab; pressing it again closes the notch. The shortcut can be changed in Settings.
- **Settings › Clipboard** page: enable/disable history, capture images, close notch after copying, history size (25–200 items), shortcut recorder and a clear-history dialog.

## Privacy and storage

- Content flagged by password managers as concealed or transient (`org.nspasteboard.ConcealedType`, `org.nspasteboard.TransientType`) is never recorded.
- History is persisted as JSON plus PNG files under the app's sandbox container in `Application Support/boringNotch/Clipboard`, so it survives restarts.
- Consecutive copies of identical content are de-duplicated. Pinned items are never trimmed by the size limit.

## Implementation

| File | Purpose |
| --- | --- |
| `boringNotch/models/ClipboardItem.swift` | Codable model for a history entry (text, link, image, files) plus presentation helpers |
| `boringNotch/managers/ClipboardManager.swift` | Polls `NSPasteboard.general` every 0.5 s, captures items, de-duplicates, enforces the size limit and persists to disk |
| `boringNotch/components/Clipboard/ClipboardHistoryView.swift` | The notch tab: filter bar, card list, empty state and the card view |
| `boringNotch/components/Settings/ClipboardSettingsView.swift` | Settings page |
| `boringNotch/enums/generic.swift` | New `NotchViews.clipboard` case |
| `boringNotch/models/Constants.swift` | New `Defaults` keys for the feature |
| `boringNotch/components/Tabs/TabSelectionView.swift`, `BoringHeader.swift` | Tabs are now computed from settings so the Clipboard tab can appear independently of the Shelf |
| `boringNotch/ContentView.swift` | Renders the clipboard view when the tab is selected |
| `boringNotch/boringNotchApp.swift` | Starts the manager at launch and handles the ⇧⌘C shortcut |
| `boringNotch/components/Settings/SettingsView.swift` | Sidebar entry and shortcut recorder |
