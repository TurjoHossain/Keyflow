import SwiftUI
import UIKit

struct RootView: View {
    var body: some View {
        TabView {
            ClipboardView()
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
            ShortcutsView()
                .tabItem { Label("Shortcuts", systemImage: "bolt.fill") }
            SetupView()
                .tabItem { Label("Setup", systemImage: "keyboard") }
        }
    }
}

// MARK: - Clipboard

struct ClipboardView: View {
    @State private var clips: [Clip] = []
    @State private var query = ""
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var filtered: [Clip] {
        if query.isEmpty { return clips }
        return clips.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                if filtered.isEmpty {
                    Text("No clipboard items yet. Copy something, then tap the + button to save it here, or let the keyboard collect it.")
                        .foregroundStyle(.secondary)
                }
                ForEach(filtered) { clip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(clip.text).lineLimit(4)
                        Text(Store.shared.remainingText(for: clip))
                            .font(.caption)
                            .foregroundStyle(clip.pinned ? Color.orange : Color.secondary)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Store.shared.togglePin(clip.id)
                            reload()
                        } label: {
                            Label(clip.pinned ? "Unpin" : "Pin", systemImage: "pin")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Store.shared.deleteClip(clip.id)
                            reload()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button("Copy") { UIPasteboard.general.string = clip.text }
                        Button(clip.pinned ? "Unpin" : "Pin") {
                            Store.shared.togglePin(clip.id)
                            reload()
                        }
                    }
                }
            }
            .searchable(text: $query)
            .navigationTitle("Clipboard")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear recent") {
                        Store.shared.clearRecent()
                        reload()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if let text = UIPasteboard.general.string {
                            Store.shared.addClip(text)
                            reload()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: reload)
            .onReceive(timer) { _ in reload() }
        }
    }

    private func reload() {
        clips = Store.shared.loadClips()
    }
}

// MARK: - Shortcuts

struct ShortcutsView: View {
    @State private var items: [Shortcut] = []
    @State private var editing: Shortcut?

    var body: some View {
        NavigationStack {
            List {
                if items.isEmpty {
                    Text("No shortcuts yet. Tap + to add one, for example omw expands to On my way!")
                        .foregroundStyle(.secondary)
                }
                ForEach(items) { item in
                    Button {
                        editing = item
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.trigger).font(.headline)
                            Text(item.expansion)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    var list = items
                    list.remove(atOffsets: offsets)
                    Store.shared.saveShortcuts(list)
                    reload()
                }
            }
            .navigationTitle("Shortcuts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = Shortcut(id: UUID(), trigger: "", expansion: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editing) { item in
                ShortcutEditor(shortcut: item) { saved in
                    Store.shared.upsertShortcut(saved)
                    reload()
                }
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        Store.shared.reloadShortcuts()
        items = Store.shared.shortcuts
    }
}

struct ShortcutEditor: View {
    @Environment(\.dismiss) var dismiss
    @State private var shortcut: Shortcut
    private let onSave: (Shortcut) -> Void

    init(shortcut: Shortcut, onSave: @escaping (Shortcut) -> Void) {
        _shortcut = State(initialValue: shortcut)
        self.onSave = onSave
    }

    private var isValid: Bool {
        let trigger = shortcut.trigger.trimmingCharacters(in: .whitespaces)
        return !trigger.isEmpty && !trigger.contains(" ") && !shortcut.expansion.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shortcut (one word)") {
                    TextField("e.g. omw", text: $shortcut.trigger)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Expands to") {
                    TextField("On my way!", text: $shortcut.expansion, axis: .vertical)
                        .lineLimit(1...5)
                }
            }
            .navigationTitle("Shortcut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(shortcut)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Setup

struct SetupView: View {
    @State private var giphyKey = ""
    @State private var lastUse: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("1. Add the keyboard") {
                    Text("Settings, General, Keyboard, Keyboards, Add New Keyboard, then choose KeyFlow.")
                    Text("Tap KeyFlow in that list and turn on Allow Full Access. It is needed for clipboard capture, GIFs, haptics and paste. Everything is stored only on your device.")
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings", destination: url)
                    }
                }

                Section("2. Switch to it") {
                    Text("In any text field, tap the globe key to switch to KeyFlow. Touch and drag on the space bar to move the cursor.")
                }

                Section("Connection with the keyboard") {
                    if let lastUse = lastUse {
                        Label("Sharing works. Keyboard last used \(lastUse.formatted(date: .abbreviated, time: .shortened))", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Not shared yet", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Use the keyboard once, then come back. If this stays empty, your signing method does not allow the app and keyboard to share data. The keyboard still works on its own, and you can manage clipboard and shortcuts inside the keyboard's panels.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Button("Refresh") { lastUse = Store.shared.lastKeyboardUse }
                }

                Section("GIFs and stickers") {
                    TextField("Giphy API key", text: $giphyKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save key") { Store.shared.giphyKey = giphyKey }
                    if let url = URL(string: "https://developers.giphy.com") {
                        Link("Get a free Giphy API key", destination: url)
                    }
                    Text("If the app and keyboard do not share data, copy the key and tap the button inside the keyboard's GIF panel instead.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("KeyFlow")
            .onAppear {
                giphyKey = Store.shared.giphyKey
                lastUse = Store.shared.lastKeyboardUse
            }
        }
    }
}
