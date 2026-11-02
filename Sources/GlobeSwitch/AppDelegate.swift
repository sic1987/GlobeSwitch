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
            button.toolTip = "GlobeSwitch — раскладка по клавише 🌐"
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
            if Settings.showHUD { hud.show(target.shortCode) }
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
            if Settings.showHUD { self.hud.show(sources.current()?.shortCode ?? "?") }
        }
    }

    @objc private func selectSource(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let source = InputSources.shared.enabled.first(where: { $0.id == id }) else { return }
        InputSources.shared.select(source)
        if Settings.showHUD { hud.show(source.shortCode) }
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
        alert.messageText = "Отключить системное переключение раскладки по клавише 🌐?"
        alert.informativeText = """
        Сейчас macOS тоже меняет раскладку по клавише 🌐 (Настройки → Клавиатура → «Нажатие клавиши 🌐»). \
        GlobeSwitch перехватывает клавишу сам, но чтобы системное действие точно не срабатывало вторым, \
        его лучше выключить («Ничего не делать»).

        Если после этого система всё ещё переключает раскладку сама — выйдите из системы и войдите снова.
        """
        alert.addButton(withTitle: "Отключить")
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Позже")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Больше не спрашивать"

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
            let status = NSMenuItem(title: "Активно — нажмите 🌐 для смены раскладки", action: nil, keyEquivalent: "")
            status.isEnabled = false
            menu.addItem(status)
            if lastSwitchMs > 0 {
                let timing = NSMenuItem(title: String(format: "Последнее переключение: %.1f мс", lastSwitchMs),
                                        action: nil, keyEquivalent: "")
                timing.isEnabled = false
                menu.addItem(timing)
            }
        } else {
            let item = NSMenuItem(title: "Нет разрешения «Универсальный доступ» — открыть…",
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
            let hint = NSMenuItem(title: "Добавьте вторую раскладку: Настройки → Клавиатура → Источники ввода",
                                  action: nil, keyEquivalent: "")
            hint.isEnabled = false
            menu.addItem(hint)
        }
        menu.addItem(.separator())

        addToggle("Показывать индикатор раскладки", on: Settings.showHUD, action: #selector(toggleHUD))
        addToggle("Перехватывать 🌐 у системы", on: Settings.swallowFn, action: #selector(toggleSwallow),
                  tip: "Системное действие клавиши 🌐 (смена источника ввода, эмодзи, диктовка) не срабатывает. Выключайте только если в настройках macOS для клавиши 🌐 выбрано «Ничего не делать», иначе раскладка переключится дважды.")
        addToggle("Запускать при входе в систему", on: loginEnabled, action: #selector(toggleLogin))
        menu.addItem(.separator())

        let keyboard = NSMenuItem(title: "Системное действие клавиши 🌐…",
                                  action: #selector(openKeyboardSettings), keyEquivalent: "")
        keyboard.target = self
        menu.addItem(keyboard)
        let about = NSMenuItem(title: "О GlobeSwitch", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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
            Переключение раскладки по клавише 🌐 (Fn) — мгновенно, без системного индикатора и задержек.

            Автор: sicdesign · sicdesign87@gmail.com
            github.com/sic1987/GlobeSwitch
            """),
        ])
    }
}
