import Cocoa

/// Small transient overlay shown right after a switch: the layout's code ("RU") and, when several enabled
/// layouts share a code, the layout's name underneath so they can be told apart.
/// Created once; `show` only resizes and moves it to the screen under the mouse and restarts the fade timer.
final class HUD {
    private let panel: NSPanel
    private let codeLabel: NSTextField
    private let nameLabel: NSTextField
    private var hideWork: DispatchWorkItem?

    private let compactSize = NSSize(width: 124, height: 78)
    private let tallHeight: CGFloat = 104
    private let maxWidth: CGFloat = 420
    private let codeFont = NSFont.systemFont(ofSize: 34, weight: .bold)
    private let nameFont = NSFont.systemFont(ofSize: 13, weight: .semibold)

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: compactSize),
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

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: compactSize))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.appearance = NSAppearance(named: .darkAqua)
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 18
        effect.layer?.masksToBounds = true

        codeLabel = NSTextField(labelWithString: "")
        codeLabel.font = codeFont
        codeLabel.textColor = .white
        codeLabel.alignment = .center

        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = nameFont
        nameLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        nameLabel.alignment = .center
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.maximumNumberOfLines = 1

        effect.addSubview(codeLabel)
        effect.addSubview(nameLabel)
        panel.contentView = effect
    }

    /// `name` is shown under the code; pass it only when the code alone is ambiguous.
    func show(code: String, name: String? = nil, duration: TimeInterval = 0.6) {
        codeLabel.stringValue = code
        nameLabel.stringValue = name ?? ""
        nameLabel.isHidden = name == nil
        hideWork?.cancel()

        var size = compactSize
        if let name {
            let textWidth = (name as NSString).size(withAttributes: [.font: nameFont]).width
            size = NSSize(width: min(max(compactSize.width, ceil(textWidth) + 44), maxWidth), height: tallHeight)
        }

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = panel.frame.origin
        if let screen {
            let f = screen.visibleFrame
            origin = NSPoint(x: f.midX - size.width / 2, y: f.minY + f.height * 0.16)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
        layoutLabels(size)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in self?.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func layoutLabels(_ size: NSSize) {
        if nameLabel.isHidden {
            codeLabel.frame = NSRect(x: 0, y: (size.height - 44) / 2, width: size.width, height: 44)
        } else {
            codeLabel.frame = NSRect(x: 0, y: size.height - 44 - 10, width: size.width, height: 44)
            nameLabel.frame = NSRect(x: 16, y: 14, width: size.width - 32, height: 20)
        }
    }

    /// Debug (used by `--hud` with GLOBESWITCH_SNAPSHOT=path): renders the labels over a dark rounded
    /// background standing in for the blur, so the layout can be checked without screen-recording rights.
    func snapshot(to path: String) {
        guard let view = panel.contentView else { return }
        let size = view.bounds.size
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale),
                                         pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(white: 0.13, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: view.bounds, xRadius: 18, yRadius: 18).fill()
        if let labels = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: labels)
            let img = NSImage(size: size)
            img.addRepresentation(labels)
            img.draw(in: view.bounds)
        }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
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
