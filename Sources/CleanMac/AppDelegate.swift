import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appController: AppController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appController = AppController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        appController?.shutdown()
    }
}