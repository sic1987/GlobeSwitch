import Cocoa

/// Small transient overlay with the new layout's code ("RU"), shown right after a switch.
/// Created once; `show` only moves it to the screen under the mouse and restarts the fade timer.
final class HUD {
    private let panel: NSPanel
    private let label: NSTextField
    private var hideWork: DispatchWorkItem?
    private let size = NSSize(width: 124, height: 78)

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true

        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.textColor = .white
        label.alignment = .center
        label.frame = NSRect(x: 0, y: (size.height - 44) / 2, width: size.width, height: 44)
        effect.addSubview(label)
        panel.contentView = effect
    }

    func show(_ text: String, duration: TimeInterval = 0.6) {
        label.stringValue = text
        hideWork?.cancel()

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let screen {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2, y: f.minY + f.height * 0.16))
        }
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.panel.alphaValue < 0.01 else { return }   // a newer `show` reset it
            self.panel.orderOut(nil)
        })
    }
}
