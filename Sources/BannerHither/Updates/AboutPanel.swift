import AppKit

/// The standard About panel: icon, name, version and copyright come from the bundle; the
/// credits area carries a tagline and links to the project.
@MainActor
enum AboutPanel {
    static func show() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .applicationVersion: AppInfo.version,
            .version: AppInfo.buildNumber,
            .credits: credits(),
        ])
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let base: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph,
        ]

        let text = NSMutableAttributedString(string: L10n.aboutTagline + "\n\n", attributes: base)
        let links: [(title: String, url: URL)] = [
            ("GitHub", AppInfo.repositoryURL),
            ("Releases", AppInfo.releasesURL),
            (L10n.aboutLicense, AppInfo.licenseURL),
        ]
        for (index, link) in links.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: "  ·  ", attributes: base))
            }
            var attributes = base
            attributes[.link] = link.url
            text.append(NSAttributedString(string: link.title, attributes: attributes))
        }
        return text
    }
}
