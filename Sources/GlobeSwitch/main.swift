import Cocoa

// `GlobeSwitch --list` / `--next` are command-line diagnostics; anything else starts the menu-bar app.
let cliArgs = Array(CommandLine.arguments.dropFirst())
if let first = cliArgs.first, first.hasPrefix("--") {
    exit(CLI.run(cliArgs))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
