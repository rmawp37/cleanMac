import ApplicationServices
import Foundation

let systemDefinedEventTypeRawValue: UInt32 = 14
let systemDefinedEventType = CGEventType(rawValue: systemDefinedEventTypeRawValue) ?? .null

enum KeyboardBlockerError: LocalizedError {
    case tapCreationFailed

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed:
            return "Der globale HID-Keyboard-Event-Tap konnte nicht erstellt werden. Prufe die Accessibility-Freigabe."
        }
    }
}

final class KeyboardBlocker {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isBlocking: Bool {
        eventTap != nil
    }

    func startBlocking() throws {
        guard eventTap == nil else {
            return
        }

        let mask = Self.blockedEventMask()

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passRetained(event)
            }

            let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()
            return blocker.handle(proxy: proxy, type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw KeyboardBlockerError.tapCreationFailed
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    func stopBlocking() {
        guard let eventTap, let runLoopSource else {
            return
        }

        CGEvent.tapEnable(tap: eventTap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)

        self.runLoopSource = nil
        self.eventTap = nil
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard isBlocking else {
            return Unmanaged.passRetained(event)
        }

        if Self.shouldBlock(eventType: type) {
            return nil
        }

        switch type {
        default:
            return Unmanaged.passRetained(event)
        }
    }

    static func blockedEventMask() -> CGEventMask {
        CGEventMask((1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << systemDefinedEventType.rawValue))
    }

    static func shouldBlock(eventType: CGEventType) -> Bool {
        switch eventType {
        case .keyDown, .keyUp, .flagsChanged:
            return true
        case systemDefinedEventType:
            return true
        default:
            return false
        }
    }
}