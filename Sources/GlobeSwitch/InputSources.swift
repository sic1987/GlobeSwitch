import Carbon
import Foundation
import os

/// One enabled keyboard input source (a layout such as "Russian - PC" or an input mode).
struct InputSource {
    let ref: TISInputSource
    let id: String
    let name: String
    let languages: [String]

    /// Two-letter code shown in the HUD: "RU", "EN", "UK"…
    var shortCode: String {
        if let lang = languages.first, !lang.isEmpty {
            let base = lang.split(separator: "-").first.map(String.init) ?? lang
            return base.uppercased()
        }
        return String(name.prefix(3)).uppercased()
    }

    init(ref: TISInputSource) {
        self.ref = ref
        id = InputSources.property(ref, kTISPropertyInputSourceID) ?? "?"
        name = InputSources.property(ref, kTISPropertyLocalizedName) ?? id
        languages = InputSources.property(ref, kTISPropertyInputSourceLanguages) ?? []
    }
}

/// Cached list of the enabled keyboard input sources, in the order of the system's input menu,
/// plus the "select next" operation used on every 🌐 tap.
final class InputSources {
    static let shared = InputSources()

    private(set) var enabled: [InputSource] = []
    /// Fired on the main queue when the list or the selected source changes.
    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    private init() {
        refresh()
        let center = DistributedNotificationCenter.default()
        observers.append(center.addObserver(
            forName: Notification.Name(kTISNotifyEnabledKeyboardInputSourcesChanged as String),
            object: nil, queue: .main) { [weak self] _ in self?.refresh() })
        observers.append(center.addObserver(
            forName: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil, queue: .main) { [weak self] _ in
                Log.sw.notice("system: selected source is now \(self?.currentID() ?? "?", privacy: .public)")
                self?.onChange?()
            })
    }

    static func property<T>(_ ref: TISInputSource, _ key: CFString) -> T? {
        guard let ptr = TISGetInputSourceProperty(ref, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as? T
    }

    /// Re-reads the enabled sources (called at start and whenever the system list changes).
    func refresh() {
        let filter: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsEnabled as String: true,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        var list: [InputSource] = []
        if let cf = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue(),
           let refs = (cf as NSArray) as? [TISInputSource] {
            list = refs.map(InputSource.init)
        }
        enabled = Self.sortedLikeSystemMenu(list)
        onChange?()
    }

    /// The first real switch in a process costs 100–250 ms (the text-input server's per-process set-up);
    /// a round trip to the other source and back at start pays that once, so the first 🌐 tap is as fast as the rest.
    func warmUp() {
        guard enabled.count >= 2, let currentID = currentID(),
              let current = enabled.first(where: { $0.id == currentID }),
              let other = enabled.first(where: { $0.id != currentID }) else { return }
        select(other)
        select(current)
    }

    /// Identifier of the source the system currently types with.
    func currentID() -> String? {
        guard let ref = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return Self.property(ref, kTISPropertyInputSourceID)
    }

    func current() -> InputSource? {
        guard let id = currentID() else { return nil }
        if let known = enabled.first(where: { $0.id == id }) { return known }
        guard let ref = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return InputSource(ref: ref)
    }

    /// Selects the source after the current one (wrapping) and returns it.
    @discardableResult
    func selectNext() -> InputSource? {
        guard !enabled.isEmpty else { return nil }
        let currentID = currentID()
        let index = enabled.firstIndex { $0.id == currentID } ?? -1
        let next = enabled[(index + 1) % enabled.count]
        select(next)
        return next
    }

    /// Result of the last TISSelectInputSource call (noErr = 0).
    private(set) var lastSelectStatus: OSStatus = noErr

    @discardableResult
    func select(_ source: InputSource) -> Bool {
        lastSelectStatus = TISSelectInputSource(source.ref)
        return lastSelectStatus == noErr
    }

    /// A fresh TISInputSource for the id (the cached ref could in theory go stale); nil if not enabled.
    func freshRef(for id: String) -> TISInputSource? {
        let filter: [String: Any] = [kTISPropertyInputSourceID as String: id]
        guard let cf = TISCreateInputSourceList(filter as CFDictionary, false)?.takeRetainedValue(),
              let refs = (cf as NSArray) as? [TISInputSource] else { return nil }
        return refs.first
    }

    /// Orders the sources like the system's input menu (com.apple.HIToolbox AppleEnabledInputSources);
    /// anything the preference does not list keeps its position at the end.
    private static func sortedLikeSystemMenu(_ list: [InputSource]) -> [InputSource] {
        guard let prefs = CFPreferencesCopyAppValue("AppleEnabledInputSources" as CFString,
                                                    "com.apple.HIToolbox" as CFString) as? [[String: Any]],
              !prefs.isEmpty else { return list }
        func rank(_ s: InputSource) -> Int {
            for (i, entry) in prefs.enumerated() {
                let kind = entry["InputSourceKind"] as? String ?? ""
                if kind == "Keyboard Layout", let name = entry["KeyboardLayout Name"] as? String {
                    if s.id == "com.apple.keylayout.\(name)" || s.id.hasSuffix(".\(name)") { return i }
                } else if kind == "Input Mode", let mode = entry["Input Mode"] as? String, s.id == mode {
                    return i
                }
            }
            return Int.max
        }
        return list.enumerated()
            .sorted { a, b in
                let ra = rank(a.element), rb = rank(b.element)
                return ra != rb ? ra < rb : a.offset < b.offset
            }
            .map { $0.element }
    }
}
