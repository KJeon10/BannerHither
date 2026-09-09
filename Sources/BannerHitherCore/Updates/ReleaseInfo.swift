import Foundation

/// What the app needs to know about a published release.
public struct ReleaseInfo: Equatable, Sendable {
    public let version: AppVersion
    /// The release tag as published, e.g. `v0.2.0`.
    public let tag: String
    /// The release page, always available.
    public let pageURL: URL
    /// Direct link to the disk image attached to the release, when there is one.
    public let downloadURL: URL?
    public let publishedAt: Date?

    public init(version: AppVersion, tag: String, pageURL: URL, downloadURL: URL? = nil, publishedAt: Date? = nil) {
        self.version = version
        self.tag = tag
        self.pageURL = pageURL
        self.downloadURL = downloadURL
        self.publishedAt = publishedAt
    }
}

/// Source of "what is the newest release?" answers. The only network access in the app goes
/// through an implementation of this protocol.
public protocol ReleaseFeedFetching: Sendable {
    func latestRelease() async throws -> ReleaseInfo
}

public enum UpdateCheckError: Error, Equatable, Sendable, LocalizedError {
    /// The server answered with a non-success HTTP status.
    case httpStatus(Int)
    /// The response could not be decoded.
    case invalidFeed(String)
    /// The release tag is not a numeric version.
    case unrecognizedVersion(String)

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let status):
            return "The server answered with HTTP status \(status)."
        case .invalidFeed(let detail):
            return "The release feed could not be read (\(detail))."
        case .unrecognizedVersion(let tag):
            return "The release tag \"\(tag)\" is not a version number."
        }
    }
}
