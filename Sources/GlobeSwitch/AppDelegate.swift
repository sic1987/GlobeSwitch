import Carbon
import Cocoa
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private let tap = FnTap()
    private let hud = HUD()
    private var permissionTimer: Timer?
    private var tapRetries = 0
    private var lastSwitchMs: Double = 0

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "GlobeSwitch")
            button.toolTip = "GlobeSwitch — layout switching on the 🌐 key"
        }
        menu.delegate = self
        statusItem.menu = menu

        InputSources.shared.onChange = { [weak self] in self?.updateIcon() }
        InputSources.shared.warmUp()
        tap.swallowFn = Settings.swallowFn
        tap.onFnTap = { [weak self] in self?.switchNext() }

        ensureAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        tap.stop()
    }

    // MARK: - Switching

    private func switchNext() {
        let sources = InputSources.shared
        let before = sources.currentID() ?? "?"
        let t0 = CFAbsoluteTimeGetCurrent()
        guard let target = sources.selectNext() else { Log.sw.notice("switch: no enabled sources"); return }
        let status = sources.lastSelectStatus
        let after = sources.currentID() ?? "?"
        lastSwitchMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        Log.sw.notice("switch \(before, privacy: .public) -> \(target.id, privacy: .public): status=\(status) now=\(after, privacy: .public) \(self.lastSwitchMs, format: .fixed(precision: 1)) ms")

        if after == target.id {
            showHUD(for: target)
            return
        }
        // Did not take: try again shortly with a freshly resolved reference.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self else { return }
            var retryStatus: OSStatus = -1
            if let ref = sources.freshRef(for: target.id) {
                retryStatus = TISSelectInputSource(ref)
            }
            let now = sources.currentID() ?? "?"
            Log.sw.notice("switch retry -> \(target.id, privacy: .public): status=\(retryStatus) now=\(now, privacy: .public)")
            if let current = sources.current() { self.showHUD(for: current) }
        }
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let source = InputSources.shared.enabled.first(where: { $0.id == id }) else { return }
        InputSources.shared.select(source)
        showHUD(for: source)
    }

    private func showHUD(for source: InputSource) {
        guard Settings.showHUD else { return }
        hud.show(code: source.shortCode, name: InputSources.shared.disambiguator(for: source))
    }

    // MARK: - Accessibility permission + event tap

    private func ensureAccessibility() {
        if AXIsProcessTrusted() { startTap(); return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self?.startTap()
        }
    }

    private func startTap() {
        if tap.start() {
            tapRetries = 0
            Settings.relaunchedForTap = false
            Log.tap.notice("event tap started (swallowFn=\(self.tap.swallowFn))")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.offerToDisableNativeAction()
            }
        } else {
            tapRetries += 1
            Log.tap.notice("event tap NOT created, attempt \(self.tapRetries), AXIsProcessTrusted=\(AXIsProcessTrusted())")
            // A permission granted while the app runs is sometimes applied only to a fresh process:
            // after ~10 s of failures relaunch once, then keep retrying quietly.
            if tapRetries == 5, !Settings.relaunchedForTap {
                Settings.relaunchedForTap = true
                relaunch()
                return
            }
            let delay: TimeInterval = tapRetries < 30 ? 2 : 10
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.startTap() }
        }
        updateIcon()
    }

    private func relaunch() {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func updateIcon() {
        statusItem.button?.appearsDisabled = !tap.isRunning
    }

    // MARK: - The system's own 🌐 action

    private func offerToDisableNativeAction() {
        guard !Settings.nativeOfferDismissed else { return }
        let usage = NativeFnSetting.read()
        // No key stored = the system default, which on a Mac with a 🌐 key and two layouts is "Change Input Source".
        let conflicts = usage == .changeInputSource || (usage == nil && InputSources.shared.enabled.count > 1)
        guard conflicts else { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Turn off the system's own 🌐 layout switching?"
        alert.informativeText = """
        macOS currently also switches the layout on the 🌐 key (System Settings → Keyboard → "Press 🌐 key to"). \
        GlobeSwitch intercepts the key itself, but to make sure the system action never fires as well, \
        it is best set to "Do Nothing".

        If the system still switches the layout on its own after this, log out and back in.
        """
        alert.addButton(withTitle: "Turn Off")
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"

        let response = alert.runModal()
        if alert.suppressionButton?.state == .on { Settings.nativeOfferDismissed = true }
        switch response {
        case .alertFirstButtonReturn:
            if NativeFnSetting.write(.doNothing) {
                Settings.nativeOfferDismissed = true
            } else {
                openKeyboardSettings()
            }
        case .alertSecondButtonReturn:
            openKeyboardSettings()
        default:
            break
        }
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let sources = InputSources.shared
        let currentID = sources.currentID()

        if tap.isRunning {
            let status = NSMenuItem(title: "Active — press 🌐 to switch the layout", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            if lastSwitchMs > 0 {
                let timing = NSMenuItem(title: String(format: "Last switch: %.1f ms", lastSwitchMs),
                                        action: nil, keyEquivalent: "")
                timing.isEnabled = false
                menu.addItem(timing)
            }
        } else {
            let item = NSMenuItem(title: "No Accessibility permission — open settings…",
                                  action: #selector(openAccessibilitySettings), keyEquivalent: "")
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())

        for source in sources.enabled {
            let item = NSMenuItem(title: "\(source.shortCode)   \(source.name)",
                                  action: #selector(selectSource(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = source.id
            item.state = source.id == currentID ? .on : .off
            menu.addItem(item)
        }
        if sources.enabled.count < 2 {
            let hint = NSMenuItem(title: "Add a second layout: System Settings → Keyboard → Input Sources",
                                  action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        menu.addItem(.separator())

        addToggle("Show layout indicator", on: Settings.showHUD, action: #selector(toggleHUD))
        addToggle("Intercept 🌐 from the system", on: Settings.swallowFn, action: #selector(toggleSwallow),
                  tip: "The system's own 🌐 key action (input source, emoji, dictation) does not fire. Turn this off only if the 🌐 key is set to \"Do Nothing\" in macOS settings, otherwise the layout switches twice.")
        addToggle("Launch at login", on: loginEnabled, action: #selector(toggleLogin))
        menu.addItem(.separator())

        let keyboard = NSMenuItem(title: "System 🌐 key action…",
                                  action: #selector(openKeyboardSettings), keyEquivalent: "")
        keyboard.target = self
        menu.addItem(keyboard)
        let about = NSMenuItem(title: "About GlobeSwitch", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func addToggle(_ title: String, on: Bool, action: Selector, tip: String? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        item.toolTip = tip
        menu.addItem(item)
    }

    @objc private func toggleHUD() { Settings.showHUD.toggle() }

    @objc private func toggleSwallow() {
        Settings.swallowFn.toggle()
        tap.swallowFn = Settings.swallowFn
    }

    private var loginEnabled: Bool { SMAppService.mainApp.status == .enabled }

    @objc private func toggleLogin() {
        do {
            if loginEnabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch {
            NSLog("GlobeSwitch: login item: %@", error.localizedDescription)
        }
    }

    @objc private func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "GlobeSwitch",
            .applicationVersion: version,
            .credits: NSAttributedString(string: """
            Switches the keyboard layout on the 🌐 (Fn) key — instantly, without the system indicator and its delays.

            Author: sicdesign · sicdesign87@gmail.com
            github.com/sic1987/GlobeSwitch
            """),
        ])
    }
}
