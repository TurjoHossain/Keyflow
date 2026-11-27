import UIKit

struct Clip: Codable, Identifiable, Equatable {
    var id: UUID
    var text: String
    var date: Date
    var pinned: Bool
}

struct Shortcut: Codable, Identifiable, Equatable {
    var id: UUID
    var trigger: String
    var expansion: String
}

struct MediaItem: Codable, Equatable {
    let id: String
    let preview: String
    let url: String
    let sticker: Bool
}

final class Store {
    static let shared = Store()
    static let groupID = "group.com.turjo.keyflow"
    /// Optional: paste your Giphy API key between the quotes to build it into the keyboard.
    static let builtInGiphyKey = ""

    private enum Keys {
        static let clips = "kf.clips"
        static let shortcuts = "kf.shortcuts"
        static let emojiRecents = "kf.emojiRecents"
        static let emojiFavorites = "kf.emojiFavorites"
        static let mediaRecents = "kf.mediaRecents"
        static let mediaFavorites = "kf.mediaFavorites"
        static let words = "kf.words"
        static let pairs = "kf.pairs"
        static let giphy = "kf.giphyKey"
        static let heartbeat = "kf.heartbeat"
        static let pasteboardCount = "kf.pasteboardCount"
    }

    private let defaults: UserDefaults
    private var words: [String: Int] = [:]
    private var pairs: [String: [String: Int]] = [:]
    private var learnedLoaded = false
    private var dirtyCount = 0
    private(set) var shortcuts: [Shortcut] = []

    private init() {
        defaults = UserDefaults(suiteName: Store.groupID) ?? UserDefaults.standard
        shortcuts = decode([Shortcut].self, key: Keys.shortcuts) ?? []
    }

    private func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func encode<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    // MARK: - Clipboard

    func loadClips() -> [Clip] {
        let all = decode([Clip].self, key: Keys.clips) ?? []
        let cutoff = Date().addingTimeInterval(-3600)
        let kept = all.filter { $0.pinned || $0.date > cutoff }
        if kept.count != all.count { encode(kept, key: Keys.clips) }
        return kept.sorted { a, b in
            if a.pinned != b.pinned { return a.pinned }
            return a.date > b.date
        }
    }

    private func saveClips(_ clips: [Clip]) {
        encode(clips, key: Keys.clips)
    }

    func addClip(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var clips = loadClips()
        if let i = clips.firstIndex(where: { $0.text == text }) {
            clips[i].date = Date()
        } else {
            clips.append(Clip(id: UUID(), text: text, date: Date(), pinned: false))
        }
        saveClips(clips)
    }

    func togglePin(_ id: UUID) {
        var clips = loadClips()
        if let i = clips.firstIndex(where: { $0.id == id }) {
            clips[i].pinned.toggle()
            clips[i].date = Date()
            saveClips(clips)
        }
    }

    func deleteClip(_ id: UUID) {
        saveClips(loadClips().filter { $0.id != id })
    }

    func clearRecent() {
        saveClips(loadClips().filter { $0.pinned })
    }

    func remainingText(for clip: Clip) -> String {
        if clip.pinned { return "Pinned" }
        let left = 3600 - Date().timeIntervalSince(clip.date)
        let minutes = max(1, Int(left / 60))
        return "Expires in \(minutes) min"
    }

    func captureFromPasteboard() {
        let board = UIPasteboard.general
        let count = board.changeCount
        if count == defaults.integer(forKey: Keys.pasteboardCount) { return }
        defaults.set(count, forKey: Keys.pasteboardCount)
        guard board.hasStrings, let text = board.string else { return }
        addClip(text)
    }

    // MARK: - Shortcuts

    func reloadShortcuts() {
        shortcuts = decode([Shortcut].self, key: Keys.shortcuts) ?? []
    }

    func saveShortcuts(_ list: [Shortcut]) {
        shortcuts = list
        encode(list, key: Keys.shortcuts)
    }

    func upsertShortcut(_ item: Shortcut) {
        var list = shortcuts
        let trigger = item.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trigger.isEmpty, !item.expansion.isEmpty else { return }
        var clean = item
        clean.trigger = trigger
        if let i = list.firstIndex(where: { $0.id == item.id }) {
            list[i] = clean
        } else if let i = list.firstIndex(where: { $0.trigger.lowercased() == trigger.lowercased() }) {
            list[i].expansion = clean.expansion
        } else {
            list.append(clean)
        }
        saveShortcuts(list)
    }

    func addShortcut(trigger: String, expansion: String) {
        upsertShortcut(Shortcut(id: UUID(), trigger: trigger, expansion: expansion))
    }

    func deleteShortcut(_ id: UUID) {
        saveShortcuts(shortcuts.filter { $0.id != id })
    }

    func shortcutMatching(_ word: String) -> Shortcut? {
        let lower = word.lowercased()
        return shortcuts.first { $0.trigger.lowercased() == lower }
    }

    // MARK: - Emoji

    var emojiRecents: [String] {
        return decode([String].self, key: Keys.emojiRecents) ?? []
    }

    var emojiFavorites: [String] {
        return decode([String].self, key: Keys.emojiFavorites) ?? []
    }

    func recordEmoji(_ emoji: String) {
        var list = emojiRecents.filter { $0 != emoji }
        list.insert(emoji, at: 0)
        if list.count > 40 { list = Array(list.prefix(40)) }
        encode(list, key: Keys.emojiRecents)
    }

    /// Returns true if the emoji is now a favorite.
    @discardableResult
    func toggleEmojiFavorite(_ emoji: String) -> Bool {
        var list = emojiFavorites
        if let i = list.firstIndex(of: emoji) {
            list.remove(at: i)
            encode(list, key: Keys.emojiFavorites)
            return false
        }
        list.insert(emoji, at: 0)
        encode(list, key: Keys.emojiFavorites)
        return true
    }

    // MARK: - GIFs and stickers

    var mediaRecents: [MediaItem] {
        return decode([MediaItem].self, key: Keys.mediaRecents) ?? []
    }

    var mediaFavorites: [MediaItem] {
        return decode([MediaItem].self, key: Keys.mediaFavorites) ?? []
    }

    func addRecentMedia(_ item: MediaItem) {
        var list = mediaRecents.filter { $0.id != item.id }
        list.insert(item, at: 0)
        if list.count > 40 { list = Array(list.prefix(40)) }
        encode(list, key: Keys.mediaRecents)
    }

    @discardableResult
    func toggleMediaFavorite(_ item: MediaItem) -> Bool {
        var list = mediaFavorites
        if let i = list.firstIndex(where: { $0.id == item.id }) {
            list.remove(at: i)
            encode(list, key: Keys.mediaFavorites)
            return false
        }
        list.insert(item, at: 0)
        encode(list, key: Keys.mediaFavorites)
        return true
    }

    var giphyKey: String {
        get {
            let saved = defaults.string(forKey: Keys.giphy) ?? ""
            return saved.isEmpty ? Store.builtInGiphyKey : saved
        }
        set {
            defaults.set(newValue.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Keys.giphy)
        }
    }

    // MARK: - Keyboard heartbeat (lets the app know it shares data with the keyboard)

    func markKeyboardUsed() {
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.heartbeat)
    }

    var lastKeyboardUse: Date? {
        let t = defaults.double(forKey: Keys.heartbeat)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    // MARK: - Word learning

    private func loadLearnedIfNeeded() {
        guard !learnedLoaded else { return }
        learnedLoaded = true
        words = decode([String: Int].self, key: Keys.words) ?? [:]
        pairs = decode([String: [String: Int]].self, key: Keys.pairs) ?? [:]
    }

    func learn(previous: String, word: String) {
        let w = word.lowercased()
        guard w.count >= 2 || w == "i" || w == "a",
              w.count <= 24,
              w.allSatisfy({ $0.isLetter || $0 == "'" }) else { return }
        loadLearnedIfNeeded()
        words[w, default: 0] += 1
        if !previous.isEmpty {
            pairs[previous, default: [:]][w, default: 0] += 1
        }
        dirtyCount += 1
        if dirtyCount >= 8 { flushLearning() }
    }

    func flushLearning() {
        guard learnedLoaded, dirtyCount > 0 else { return }
        dirtyCount = 0
        if words.count > 8000 { words = words.filter { $0.value > 1 } }
        if pairs.count > 5000 { pairs = pairs.filter { $0.value.values.reduce(0, +) > 1 } }
        encode(words, key: Keys.words)
        encode(pairs, key: Keys.pairs)
    }

    func learnedWords(prefix: String, previous: String, limit: Int) -> [String] {
        loadLearnedIfNeeded()
        let bigram = pairs[previous] ?? [:]
        var scored: [(String, Int)] = []
        for (w, c) in words where w.hasPrefix(prefix) && w != prefix && c >= 2 {
            scored.append((w, c + (bigram[w] ?? 0) * 5))
        }
        scored.sort { $0.1 > $1.1 }
        return scored.prefix(limit).map { $0.0 }
    }

    func nextWords(after previous: String, limit: Int) -> [String] {
        loadLearnedIfNeeded()
        guard let bigram = pairs[previous] else { return [] }
        let sorted = bigram.sorted { $0.value > $1.value }
        return sorted.prefix(limit).map { $0.key }
    }
}
