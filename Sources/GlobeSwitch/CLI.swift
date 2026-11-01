import Foundation

/// Command-line diagnostics so the switching core can be checked without the GUI or permissions.
enum CLI {
    static func run(_ args: [String]) -> Int32 {
        switch args[0] {
        case "--list", "-l":
            let sources = InputSources.shared
            if sources.enabled.isEmpty { print("Нет включённых раскладок"); return 1 }
            let current = sources.currentID()
            for s in sources.enabled {
                let mark = s.id == current ? "*" : " "
                let code = s.shortCode.padding(toLength: 4, withPad: " ", startingAt: 0)
                print("\(mark) \(code) \(s.name)  [\(s.id)]")
            }
            if let usage = NativeFnSetting.read() {
                print("Системное действие клавиши 🌐: \(usage)")
            } else {
                print("Системное действие клавиши 🌐: по умолчанию (ключ не задан)")
            }
            return 0
        case "--next", "-n":
            InputSources.shared.warmUp()
            let t0 = CFAbsoluteTimeGetCurrent()
            guard let next = InputSources.shared.selectNext() else { print("Нет включённых раскладок"); return 1 }
            let ms = (CFAbsoluteTimeGetCurrent() - t0) * 1000
            print(String(format: "→ %@ (%@) за %.2f мс", next.shortCode, next.name, ms))
            return 0
        case "--help", "-h":
            print(usage)
            return 0
        default:
            fputs("Неизвестный параметр: \(args[0])\n\(usage)\n", stderr)
            return 2
        }
    }

    static let usage = """
    GlobeSwitch — переключение раскладки по клавише 🌐 (Fn)
      без параметров   запустить приложение (значок в строке меню)
      --list, -l       показать включённые раскладки (* — текущая)
      --next, -n       переключить на следующую раскладку и показать время
    """
}
