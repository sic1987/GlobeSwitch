import os

/// Unified-log channels. Read with:
///   log show --predicate 'subsystem == "com.sicdesign.GlobeSwitch"' --last 5m --style compact
/// Only Fn / media-key events and switch results are logged, never ordinary keystrokes.
enum Log {
    static let tap = Logger(subsystem: "com.sicdesign.GlobeSwitch", category: "tap")
    static let sw = Logger(subsystem: "com.sicdesign.GlobeSwitch", category: "switch")
}
