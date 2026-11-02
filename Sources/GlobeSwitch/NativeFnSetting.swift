import Foundation

/// macOS's own action for the 🌐 key: System Settings → Keyboard → "Press 🌐 key to".
/// Stored as com.apple.HIToolbox AppleFnUsageType.
enum NativeFnSetting {
    enum Usage: Int, CustomStringConvertible {
        case doNothing = 0, changeInputSource = 1, showEmoji = 2, startDictation = 3

        var description: String {
            switch self {
            case .doNothing: return "Do Nothing"
            case .changeInputSource: return "Change Input Source"
            case .showEmoji: return "Show Emoji & Symbols"
            case .startDictation: return "Start Dictation"
            }
        }
    }

    private static let domain = "com.apple.HIToolbox" as CFString
    private static let key = "AppleFnUsageType" as CFString

    static func read() -> Usage? {
        guard let n = CFPreferencesCopyAppValue(key, domain) as? Int else { return nil }
        return Usage(rawValue: n)
    }

    @discardableResult
    static func write(_ usage: Usage) -> Bool {
        CFPreferencesSetAppValue(key, NSNumber(value: usage.rawValue), domain)
        return CFPreferencesAppSynchronize(domain)
    }
}
