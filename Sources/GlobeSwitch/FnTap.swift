import Cocoa
import Carbon

/// Watches the keyboard at the HID level and reports a clean tap of the Fn/🌐 key:
/// Fn pressed and released with no other key, modifier, mouse button or media key in between,
/// so Fn+arrows, Fn+F-keys, Fn+E (emoji) and the like keep working and never switch the layout.
final class FnTap {
    /// Delete the Fn modifier events so macOS's own 🌐-key action never fires.
    var swallowFn = true
    /// Called on the main thread on every clean Fn tap.
    var onFnTap: (() -> Void)?
    private(set) var isRunning = false

    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    private var fnDown = false
    private var comboUsed = false

    private static let fnKeyCode = Int64(kVK_Function)   // 63: Fn/🌐 arrives as a flagsChanged event
    private static let globeKeyCode: Int64 = 179         // some keyboards report 🌐 as a plain key instead
    private static let sysDefinedType: UInt32 = 14       // NX_SYSDEFINED: brightness, volume, media keys

    /// Creates the event tap on the main run loop. Needs the Accessibility permission.
    func start() -> Bool {
        if isRunning { return true }
        var mask: CGEventMask = 0
        let types: [CGEventType] = [.flagsChanged, .keyDown, .keyUp,
                                    .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel]
        for t in types { mask |= CGEventMask(1) << CGEventMask(t.rawValue) }
        mask |= CGEventMask(1) << CGEventMask(Self.sysDefinedType)

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(tap: .cghidEventTap,
                                           place: .headInsertEventTap,
                                           options: .defaultTap,
                                           eventsOfInterest: mask,
                                           callback: fnTapCallback,
                                           userInfo: userInfo) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        self.port = port
        self.source = source
        isRunning = true
        return true
    }

    func stop() {
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        port = nil
        source = nil
        isRunning = false
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            // The system switches a slow or idle tap off; switch it back on.
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
            return pass

        case .flagsChanged:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.fnKeyCode {
                fnChanged(down: event.flags.contains(.maskSecondaryFn))
                return swallowFn ? nil : pass
            }
            if fnDown { comboUsed = true }   // Shift/Ctrl/… pressed while Fn is held
            return pass

        case .keyDown:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.globeKeyCode {
                fnChanged(down: true)
                return swallowFn ? nil : pass
            }
            if fnDown { comboUsed = true }
            return pass

        case .keyUp:
            if event.getIntegerValueField(.keyboardEventKeycode) == Self.globeKeyCode {
                fnChanged(down: false)
                return swallowFn ? nil : pass
            }
            return pass

        default:
            // Mouse buttons, scroll wheel, system-defined (brightness / media) keys.
            if fnDown { comboUsed = true }
            return pass
        }
    }

    private func fnChanged(down: Bool) {
        if down {
            fnDown = true
            comboUsed = false
        } else if fnDown {
            fnDown = false
            if !comboUsed { onFnTap?() }
        }
    }
}

private func fnTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                           userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<FnTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type: type, event: event)
}
