import Foundation

/// macOS's own action for the 🌐 key: System Settings → Keyboard → "Press 🌐 key to".
/// Stored as com.apple.HIToolbox AppleFnUsageType.
enum NativeFnSetting {
    enum Usage: Int, CustomStringConvertible {
        case doNothing = 0, changeInputSource = 1, showEmoji = 2, startDictation = 3

        var description: String {
            switch self {
            case .doNothing: return "Ничего не делать"
            case .changeInputSource: return "Сменить источник ввода"
            case .showEmoji: return "Показать эмодзи и символы"
            case .startDictation: return "Начать диктовку"
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
