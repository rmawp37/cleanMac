import AppKit

enum AppEnvironment {
    static var bundleURL: URL {
        Bundle.main.bundleURL.standardizedFileURL
    }

    static var isRunningFromAppBundle: Bool {
        bundleURL.pathExtension == "app"
    }

    static var isInstalledInApplications: Bool {
        bundleURL.path == "/Applications/CleanMac.app"
    }

    static var installedAppURL: URL {
        URL(fileURLWithPath: "/Applications/CleanMac.app")
    }

    static func launchInstalledAppIfAvailable() -> Bool {
        let installedURL = installedAppURL
        guard FileManager.default.fileExists(atPath: installedURL.path) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: installedURL, configuration: configuration) { _, _ in }
        return true
    }
}