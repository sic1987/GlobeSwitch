import Foundation

/// User preferences (UserDefaults of the app).
enum Settings {
    private static let defaults = UserDefaults.standard

    private static func bool(_ key: String, default value: Bool) -> Bool {
        defaults.object(forKey: key) as? Bool ?? value
    }

    /// Show the "RU"/"EN" overlay after every switch.
    static var showHUD: Bool {
        get { bool("showHUD", default: true) }
        set { defaults.set(newValue, forKey: "showHUD") }
    }

    /// Delete the Fn modifier events so the system's own 🌐 action never fires alongside ours.
    static var swallowFn: Bool {
        get { bool("swallowFn", default: true) }
        set { defaults.set(newValue, forKey: "swallowFn") }
    }

    /// The user answered the "disable the system's 🌐 action?" question for good.
    static var nativeOfferDismissed: Bool {
        get { bool("nativeOfferDismissed", default: false) }
        set { defaults.set(newValue, forKey: "nativeOfferDismissed") }
    }
}
