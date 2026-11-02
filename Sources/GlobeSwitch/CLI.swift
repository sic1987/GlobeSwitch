import Foundation

/// Command-line diagnostics so the switching core can be checked without the GUI or permissions.
enum CLI {
    static func run(_ args: [String]) -> Int32 {
        switch args[0] {
        case "--list", "-l":
            let sources = InputSources.shared
            if sources.enabled.isEmpty { print("No enabled input sources"); return 1 }
            let current = sources.currentID()
            for s in sources.enabled {
                let mark = s.id == current ? "*" : " "
                let code = s.shortCode.padding(toLength: 4, withPad: " ", startingAt: 0)
                print("\(mark) \(code) \(s.name)  [\(s.id)]")
            }
            if let usage = NativeFnSetting.read() {
                print("System 🌐 key action: \(usage)")
            } else {
                print("System 🌐 key action: default (key not set)")
            }
            return 0
        case "--next", "-n":
            InputSources.shared.warmUp()
            let t0 = CFAbsoluteTimeGetCurrent()
            guard let next = InputSources.shared.selectNext() else { print("No enabled input sources"); return 1 }
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            print(String(format: "→ %@ (%@) in %.2f ms", next.shortCode, next.name, ms))
            return 0
        case "--help", "-h":
            print(usage)
            return 0
        default:
            fputs("Unknown option: \(args[0])\n\(usage)\n", stderr)
            return 2
        }
    }

    static let usage = """
    GlobeSwitch — keyboard layout switching on the 🌐 (Fn) key
      no arguments     run the app (menu-bar icon)
      --list, -l       list the enabled input sources (* = current)
      --next, -n       switch to the next input source and print the time
    """
}
