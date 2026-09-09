import AppKit

@main
enum BannerHitherApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // Menu bar only: no Dock icon, no main menu, no app switcher entry.
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
