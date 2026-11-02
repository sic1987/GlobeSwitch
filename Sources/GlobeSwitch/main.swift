import Cocoa

// `GlobeSwitch --list` / `--next` are command-line diagnostics; anything else starts the menu-bar app.
let cliArgs = Array(CommandLine.arguments.dropFirst())
if cliArgs.first == "--hud" {
    // Preview the indicator for 3 s: GlobeSwitch --hud [CODE [NAME]]
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let hud = HUD()
    hud.show(code: cliArgs.count > 1 ? cliArgs[1] : "RU", name: cliArgs.count > 2 ? cliArgs[2] : nil, duration: 3)
    if let path = ProcessInfo.processInfo.environment["GLOBESWITCH_SNAPSHOT"] {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { hud.snapshot(to: path); exit(0) }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { exit(0) }
    app.run()
}
if let first = cliArgs.first, first.hasPrefix("--") {
    exit(CLI.run(cliArgs))
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
