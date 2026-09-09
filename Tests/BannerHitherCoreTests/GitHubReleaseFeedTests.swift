import XCTest
@testable import BannerHitherCore

final class GitHubReleaseFeedTests: XCTestCase {
    private let payload = """
    {
      "tag_name": "v0.2.0",
      "html_url": "https://github.com/KJeon10/BannerHither/releases/tag/v0.2.0",
      "draft": false,
      "prerelease": false,
      "published_at": "2026-10-01T09:00:00Z",
      "assets": [
        {"name": "BannerHither-0.2.0.dmg.sha256", "browser_download_url": "https://github.com/KJeon10/BannerHither/releases/download/v0.2.0/BannerHither-0.2.0.dmg.sha256"},
        {"name": "BannerHither-0.2.0.dmg", "browser_download_url": "https://github.com/KJeon10/BannerHither/releases/download/v0.2.0/BannerHither-0.2.0.dmg"}
      ]
    }
    """

    func testDecodesTagPageAndDiskImage() throws {
        let release = try GitHubReleaseFeed.decode(Data(payload.utf8))
        XCTAssertEqual(release.version, AppVersion("0.2.0"))
        XCTAssertEqual(release.tag, "v0.2.0")
        XCTAssertEqual(release.pageURL.absoluteString, "https://github.com/KJeon10/BannerHither/releases/tag/v0.2.0")
        XCTAssertEqual(release.downloadURL?.lastPathComponent, "BannerHither-0.2.0.dmg")
        XCTAssertEqual(release.publishedAt, Date(timeIntervalSince1970: 1_790_845_200))
    }

    func testReleaseWithoutDiskImageHasNoDownloadURL() throws {
        let json = #"{"tag_name": "v0.2.0", "html_url": "https://example.com/v0.2.0", "assets": []}"#
        let release = try GitHubReleaseFeed.decode(Data(json.utf8))
        XCTAssertNil(release.downloadURL)
        XCTAssertNil(release.publishedAt)
    }

    func testNonNumericTagIsRejected() {
        let json = #"{"tag_name": "latest", "html_url": "https://example.com/latest"}"#
        XCTAssertThrowsError(try GitHubReleaseFeed.decode(Data(json.utf8))) { error in
            XCTAssertEqual(error as? UpdateCheckError, .unrecognizedVersion("latest"))
        }
    }

    func testGarbageIsRejected() {
        XCTAssertThrowsError(try GitHubReleaseFeed.decode(Data("not json".utf8))) { error in
            guard case .invalidFeed = error as? UpdateCheckError else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    func testReadsAFileURLFeed() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("feed-\(UUID().uuidString).json")
        try Data(payload.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let feed = GitHubReleaseFeed(url: url, userAgent: "BannerHitherTests/1")
        let release = try await feed.latestRelease()
        XCTAssertEqual(release.tag, "v0.2.0")
    }

    func testLatestReleaseURL() {
        XCTAssertEqual(
            GitHubReleaseFeed.latestReleaseURL(repository: "KJeon10/BannerHither").absoluteString,
            "https://api.github.com/repos/KJeon10/BannerHither/releases/latest"
        )
    }
}
