import Foundation

/// Facts about this build, read from the bundle when running as an app.
enum AppInfo {
    static let name = "BannerHither"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.github.kjeon10.BannerHither"

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var versionDescription: String {
        "\(name) \(version) (\(buildNumber))"
    }

    /// `true` when running from a `.app` bundle rather than a bare SwiftPM executable.
    static var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
