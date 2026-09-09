import Foundation
import os

/// Central factory for `os.Logger` instances so every category shares one subsystem.
///
/// Follow the app's activity with:
///
///     log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
public enum AppLog {
    public static let subsystem: String = Bundle.main.bundleIdentifier ?? "io.github.kjeon10.BannerHither"

    public static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
