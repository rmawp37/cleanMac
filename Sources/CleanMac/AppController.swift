import AppKit

@MainActor
final class AppController {
    private let capsLockRemapper = CapsLockRemapper()
    private let keyboardBlocker = KeyboardBlocker()
    private let statusItemController: StatusItemController
    private var wakeObserver: Any?

    init() {
        statusItemController = StatusItemController()
        statusItemController.onToggleRequested = { [weak self] in
            self?.toggleKeyboardLock()
        }
        statusItemController.onOpenAccessibilityRequested = {
            Permissions.openAccessibilitySettings()
        }
        statusItemController.onQuitRequested = {
            NSApp.terminate(nil)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.unlockAfterWake()
            }
        }

        refreshUI()

        if !Permissions.isAccessibilityTrusted(prompt: false) {
            statusItemController.showPermissionHint()
        }
    }

    func shutdown() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        keyboardBlocker.stopBlocking()
        capsLockRemapper.restoreOriginalMapping()
    }

    private func toggleKeyboardLock() {
        if keyboardBlocker.isBlocking {
            keyboardBlocker.stopBlocking()
            capsLockRemapper.restoreOriginalMapping()
            refreshUI()
            return
        }

        guard Permissions.isAccessibilityTrusted(prompt: true) else {
            statusItemController.showPermissionHint()
            refreshUI()
            return
        }

        do {
            try capsLockRemapper.applyLockedMapping()
            try keyboardBlocker.startBlocking()
        } catch {
            keyboardBlocker.stopBlocking()
            capsLockRemapper.restoreOriginalMapping()
            statusItemController.showFailure(message: error.localizedDescription)
        }

        refreshUI()
    }

    private func unlockAfterWake() {
        guard keyboardBlocker.isBlocking else {
            return
        }

        keyboardBlocker.stopBlocking()
        capsLockRemapper.restoreOriginalMapping()
        refreshUI()
    }

    private func refreshUI() {
        statusItemController.update(isLocked: keyboardBlocker.isBlocking)
    }
}