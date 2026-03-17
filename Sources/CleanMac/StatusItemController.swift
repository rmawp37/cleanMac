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
        guard let imageURL = Bundle.module.url(forResource: "logo", withExtension: "png") else {
            let fallbackName = isLocked ? "lock.fill" : "keyboard"
            let fallbackImage = NSImage(systemSymbolName: fallbackName, accessibilityDescription: nil)
            fallbackImage?.isTemplate = true
            return fallbackImage
        }

        let image = NSImage(contentsOf: imageURL)
        image?.size = NSSize(width: 18, height: 18)
        image?.isTemplate = false
        return image
    }
}