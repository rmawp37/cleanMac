import AppKit

@MainActor
final class StatusItemController: NSObject {
    var onToggleRequested: (() -> Void)?
    var onOpenAccessibilityRequested: (() -> Void)?
    var onQuitRequested: (() -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let toggleMenuItem = NSMenuItem(title: "Lock keyboard", action: nil, keyEquivalent: "")
    private let permissionMenuItem = NSMenuItem(title: "Open Accessibility Settings", action: nil, keyEquivalent: "")

    override init() {
        super.init()

        configureButton()
        configureMenu()
    }

    func update(isLocked: Bool) {
        if let button = statusItem.button {
            button.image = icon(isLocked: isLocked)
            button.toolTip = isLocked ? "Keyboard is locked" : "Keyboard is unlocked"
        }

        toggleMenuItem.title = isLocked ? "Unlock keyboard" : "Lock keyboard"
    }

    func showPermissionHint() {
        let alert = NSAlert()
        alert.messageText = "Accessibility permission required"
        alert.informativeText = "CleanMac needs Accessibility access to block keyboard input while keeping the mouse and trackpad active."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Close")

        if alert.runModal() == .alertFirstButtonReturn {
            onOpenAccessibilityRequested?()
        }
    }

    func showFailure(message: String) {
        let alert = NSAlert()
        alert.messageText = "Keyboard lock could not be enabled"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showRunInstalledAppHint(currentLocation: String, installedLocation: String) {
        let alert = NSAlert()
        alert.messageText = "CleanMac switched to the installed app"
        alert.informativeText = "The current process is running from an unstable development or temporary path:\n\n\(currentLocation)\n\nAccessibility permission should be granted to the installed app at:\n\n\(installedLocation)"
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showInstallAppHint(currentLocation: String) {
        let alert = NSAlert()
        alert.messageText = "Install the app to Applications first"
        alert.informativeText = "CleanMac is currently running from:\n\n\(currentLocation)\n\nFor reliable Accessibility permission and keyboard locking, install and run /Applications/CleanMac.app instead of using swift run or a temporary build path."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else {
            onToggleRequested?()
            return
        }

        if currentEvent.type == .rightMouseUp || currentEvent.modifierFlags.contains(.control) {
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
            return
        }

        onToggleRequested?()
    }

    @objc private func handleToggleMenuItem() {
        onToggleRequested?()
    }

    @objc private func handleOpenAccessibility() {
        onOpenAccessibilityRequested?()
    }

    @objc private func handleQuit() {
        onQuitRequested?()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.image = icon(isLocked: false)
        button.target = self
        button.action = #selector(handleButtonClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configureMenu() {
        toggleMenuItem.target = self
        toggleMenuItem.action = #selector(handleToggleMenuItem)
        permissionMenuItem.target = self
        permissionMenuItem.action = #selector(handleOpenAccessibility)

        let quitMenuItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitMenuItem.target = self

        menu.addItem(toggleMenuItem)
        menu.addItem(permissionMenuItem)
        menu.addItem(.separator())
        menu.addItem(quitMenuItem)
    }

    private func icon(isLocked: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()

        NSColor.labelColor.setStroke()
        NSColor.labelColor.setFill()

        let keyboardRect = NSRect(x: 1.5, y: 4.5, width: 15, height: 9)
        let keyboardPath = NSBezierPath(roundedRect: keyboardRect, xRadius: 2.2, yRadius: 2.2)
        keyboardPath.lineWidth = 1.4
        keyboardPath.stroke()

        drawKeyboardKeys(in: keyboardRect)

        if isLocked {
            drawLockedBadge()
        } else {
            drawUnlockedAccent(in: keyboardRect)
        }

        image.unlockFocus()
        image.isTemplate = true

        return image
    }

    private func drawKeyboardKeys(in keyboardRect: NSRect) {
        let keySize = CGSize(width: 1.6, height: 1.3)
        let rowStartX = keyboardRect.minX + 1.6
        let topRowY = keyboardRect.maxY - 3.2
        let bottomRowY = keyboardRect.minY + 2.0

        for column in 0..<5 {
            let topKeyRect = NSRect(
                x: rowStartX + CGFloat(column) * 2.4,
                y: topRowY,
                width: keySize.width,
                height: keySize.height
            )
            NSBezierPath(roundedRect: topKeyRect, xRadius: 0.4, yRadius: 0.4).fill()
        }

        for column in 0..<4 {
            let bottomKeyRect = NSRect(
                x: rowStartX + 1.2 + CGFloat(column) * 2.6,
                y: bottomRowY,
                width: keySize.width,
                height: keySize.height
            )
            NSBezierPath(roundedRect: bottomKeyRect, xRadius: 0.4, yRadius: 0.4).fill()
        }

        let spaceBarRect = NSRect(x: keyboardRect.midX - 3.2, y: keyboardRect.minY + 0.8, width: 6.4, height: 1.1)
        NSBezierPath(roundedRect: spaceBarRect, xRadius: 0.5, yRadius: 0.5).fill()
    }

    private func drawLockedBadge() {
        let badgeRect = NSRect(x: 10.8, y: 10.1, width: 6.0, height: 6.0)
        let badgePath = NSBezierPath(ovalIn: badgeRect)
        badgePath.lineWidth = 1.2
        badgePath.stroke()

        let xPath = NSBezierPath()
        xPath.lineWidth = 1.3
        xPath.move(to: NSPoint(x: badgeRect.minX + 1.5, y: badgeRect.minY + 1.5))
        xPath.line(to: NSPoint(x: badgeRect.maxX - 1.5, y: badgeRect.maxY - 1.5))
        xPath.move(to: NSPoint(x: badgeRect.minX + 1.5, y: badgeRect.maxY - 1.5))
        xPath.line(to: NSPoint(x: badgeRect.maxX - 1.5, y: badgeRect.minY + 1.5))
        xPath.stroke()
    }

    private func drawUnlockedAccent(in keyboardRect: NSRect) {
        let accentRect = NSRect(x: keyboardRect.minX + 1.4, y: keyboardRect.maxY + 0.5, width: 3.6, height: 1.4)
        NSBezierPath(roundedRect: accentRect, xRadius: 0.7, yRadius: 0.7).fill()
    }
}