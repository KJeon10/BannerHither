import BannerHitherCore
import Foundation

/// Facts about this build, read from the bundle when running as an app.
enum AppInfo {
    static let name = "BannerHither"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "io.github.kjeon10.BannerHither"

    /// GitHub repository in `owner/name` form; releases are read from here.
    static let repository = "KJeon10/BannerHither"
    static let repositoryURL = URL(string: "https://github.com/KJeon10/BannerHither")!
    static let releasesURL = URL(string: "https://github.com/KJeon10/BannerHither/releases")!
    static let licenseURL = URL(string: "https://github.com/KJeon10/BannerHither/blob/main/LICENSE")!

    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    static var versionDescription: String {
        "\(name) \(version) (\(buildNumber))"
    }

    /// The running version as a comparable value; a bare `swift run` binary counts as 0.
    static var currentVersion: AppVersion {
        AppVersion(version) ?? AppVersion([0])
    }

    /// Sent with the update check so GitHub can tell the requests apart from a browser.
    static var userAgent: String {
        "\(name)/\(version)"
    }

    /// `true` when running from a `.app` bundle rather than a bare SwiftPM executable.
    static var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
