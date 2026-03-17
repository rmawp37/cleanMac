import AppKit

@MainActor
final class AppController {
    private let capsLockRemapper = CapsLockRemapper()
    private let keyboardBlocker = KeyboardBlocker()
    private let statusItemController: StatusItemController
    private var accessibilityPromptWasRequested = false
    private var accessibilityPollTimer: Timer?
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
    }

    func shutdown() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        accessibilityPollTimer?.invalidate()
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

        guard Permissions.isAccessibilityTrusted(prompt: false) else {
            requestAccessibilityPermissionIfNeeded()
            refreshUI()
            return
        }

        stopAccessibilityPolling()
        accessibilityPromptWasRequested = false

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

    private func requestAccessibilityPermissionIfNeeded() {
        guard !accessibilityPromptWasRequested else {
            startAccessibilityPolling()
            return
        }

        accessibilityPromptWasRequested = true
        _ = Permissions.isAccessibilityTrusted(prompt: true)
        startAccessibilityPolling()
    }

    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else {
            return
        }

        accessibilityPollTimer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleAccessibilityPoll),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
    }

    @objc private func handleAccessibilityPoll() {
        if Permissions.isAccessibilityTrusted(prompt: false) {
            accessibilityPromptWasRequested = false
            stopAccessibilityPolling()
            refreshUI()
        }
    }
}