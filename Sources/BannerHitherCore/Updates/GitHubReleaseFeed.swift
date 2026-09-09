import Foundation

/// Reads the newest published release of a GitHub repository through the public REST API.
///
/// `releases/latest` already excludes drafts and pre-releases. The request is anonymous and
/// carries nothing but the standard headers plus the app's `User-Agent`; GitHub allows sixty
/// such requests per hour and address, far more than a daily check needs. Any URL that
/// returns the same JSON shape works, including a `file://` URL, which is how the check can
/// be exercised without a network.
public struct GitHubReleaseFeed: ReleaseFeedFetching {
    public let url: URL
    public let userAgent: String
    private let session: URLSession

    public init(url: URL, userAgent: String, session: URLSession = GitHubReleaseFeed.makeSession()) {
        self.url = url
        self.userAgent = userAgent
        self.session = session
    }

    public init(repository: String, userAgent: String) {
        self.init(url: Self.latestReleaseURL(repository: repository), userAgent: userAgent)
    }

    /// `https://api.github.com/repos/<owner>/<name>/releases/latest`.
    public static func latestReleaseURL(repository: String) -> URL {
        URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    }

    /// A session that neither caches nor waits for connectivity: a failed check is simply retried
    /// the next day.
    public static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    public func latestRelease() async throws -> ReleaseInfo {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }
        return try Self.decode(data)
    }

    /// Turns a `releases/latest` payload into a `ReleaseInfo`; the disk image is the first
    /// asset whose name ends in `.dmg`.
    public static func decode(_ data: Data) throws -> ReleaseInfo {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let payload: Payload
        do {
            payload = try decoder.decode(Payload.self, from: data)
        } catch {
            throw UpdateCheckError.invalidFeed(String(describing: error))
        }
        guard let version = AppVersion(payload.tagName) else {
            throw UpdateCheckError.unrecognizedVersion(payload.tagName)
        }
        let image = payload.assets?.first { $0.name.lowercased().hasSuffix(".dmg") }
        return ReleaseInfo(
            version: version,
            tag: payload.tagName,
            pageURL: payload.htmlUrl,
            downloadURL: image?.browserDownloadUrl,
            publishedAt: payload.publishedAt
        )
    }

    private struct Payload: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }

        let tagName: String
        let htmlUrl: URL
        let publishedAt: Date?
        let assets: [Asset]?
    }
}
