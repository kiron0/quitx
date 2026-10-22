import Testing
import Foundation
@testable import QuitX

@Suite("Changelog Provider & Window Tests")
@MainActor
struct ChangelogTests {
    @Test("ChangelogProvider parses markdown with versions, sections, and items")
    func testChangelogParsing() {
        let sampleMarkdown = """
        # Changelog

        ## 2.0.0

        ### Added

        - New dark mode theme: fully customizable colors.
        - Real-time battery graphs.

        ### Fixed

        - Memory leak on timer invalidation.

        ## 1.9.0

        ### Changed

        - Improved startup latency by 40%.
        """

        let releases = ChangelogProvider.parse(markdown: sampleMarkdown)
        #expect(releases.count == 2)

        let first = releases[0]
        #expect(first.version == "2.0.0")
        #expect(first.sections.count == 2)
        #expect(first.sections[0].title == "Added")
        #expect(first.sections[0].items.count == 2)
        #expect(first.sections[0].items[0].contains("New dark mode theme"))
        #expect(first.sections[1].title == "Fixed")
        #expect(first.sections[1].items.count == 1)

        let second = releases[1]
        #expect(second.version == "1.9.0")
        #expect(second.sections.count == 1)
        #expect(second.sections[0].title == "Changed")
    }

    @Test("ChangelogProvider returns non-empty releases from disk or fallback")
    func testChangelogProviderReleases() {
        let releases = ChangelogProvider.releases()
        #expect(!releases.isEmpty)
        #expect(releases.contains(where: { $0.version == "1.1.7" || $0.version == "1.1.6" }))

        for release in releases {
            #expect(!release.version.isEmpty)
            #expect(!release.sections.isEmpty)
        }
    }

    @Test("ChangelogWindowController showIfUpdated honors first launch vs update state")
    func testShowIfUpdatedLogic() {
        let suiteName = "test_changelog_\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let currentVersion = UpdateChecker.shared.currentVersion
        let controller = ChangelogWindowController.shared

        // 1. Brand new first launch: firstLaunchSeen is false
        defaults.set(false, forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen)
        defaults.removeObject(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)
        controller.showIfUpdated(defaults: defaults)

        // Must record current version so it won't pop over welcome window
        #expect(defaults.string(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion) == currentVersion)

        // 2. Already on same version: no update
        defaults.set(true, forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen)
        defaults.set(currentVersion, forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)
        controller.showIfUpdated(defaults: defaults)
        #expect(defaults.string(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion) == currentVersion)

        // 3. User updated from older version
        defaults.set("1.0.0", forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)
        controller.showIfUpdated(defaults: defaults)
        #expect(defaults.string(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion) == currentVersion)
        controller.close()
    }

    @Test("Changelog window lifecycle and activation state")
    func testWindowOpenClose() {
        let controller = ChangelogWindowController.shared
        controller.close()
        #expect(!controller.isOpen)

        controller.show(version: "1.1.7")
        #expect(controller.isOpen)

        controller.close()
        #expect(!controller.isOpen)
    }

    @Test("What's New appears only after a real upgrade")
    func presentationRules() {
        #expect(ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: "1.1.6", firstLaunchSeen: true, welcomeIsOpen: false))
        #expect(ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: nil, firstLaunchSeen: true, welcomeIsOpen: false))
        #expect(ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: "", firstLaunchSeen: true, welcomeIsOpen: false))
        #expect(!ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: "1.1.7", firstLaunchSeen: true, welcomeIsOpen: false))
        #expect(!ChangelogWindowController.shouldPresent(currentVersion: "1.1.6", lastSeenVersion: "1.1.7", firstLaunchSeen: true, welcomeIsOpen: false))
        #expect(!ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: nil, firstLaunchSeen: false, welcomeIsOpen: false))
        #expect(!ChangelogWindowController.shouldPresent(currentVersion: "1.1.7", lastSeenVersion: "1.0.0", firstLaunchSeen: true, welcomeIsOpen: true))
        #expect(!ChangelogWindowController.shouldPresent(currentVersion: "", lastSeenVersion: "1.0.0", firstLaunchSeen: true, welcomeIsOpen: false))
    }

    @Test("Upgrading from a build without the last-seen key opens What's New once")
    func upgradeFromLegacyBuild() {
        let suiteName = "test_changelog_legacy_\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = ChangelogWindowController.shared
        controller.close()

        defaults.set(true, forKey: QuitXConstants.UserDefaultsKeys.firstLaunchSeen)
        defaults.removeObject(forKey: QuitXConstants.UserDefaultsKeys.lastSeenVersion)
        controller.showIfUpdated(defaults: defaults)
        #expect(controller.isOpen)
        controller.close()

        controller.showIfUpdated(defaults: defaults)
        #expect(!controller.isOpen)
    }

    @Test("Bundled release notes cover the running version and stay well-formed")
    func releaseNotesIntegrity() {
        let releases = ChangelogProvider.releases()
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Support/Info.plist")
        let plist = NSDictionary(contentsOf: plistURL)
        let shippingVersion = plist?["CFBundleShortVersionString"] as? String
        #expect(shippingVersion != nil)
        #expect(releases.first?.version == shippingVersion, "add release notes for the new version before shipping")
        #expect(Set(releases.map(\.version)).count == releases.count)
        for (newer, older) in zip(releases, releases.dropFirst()) {
            #expect(VersionComparator.isGreaterThan(newer.version, older.version))
        }
        for release in releases {
            #expect(!release.summary.isEmpty)
            #expect(Set(release.sections.map(\.id)).count == release.sections.count)
            for section in release.sections {
                #expect(!section.items.isEmpty)
                #expect(Set(section.items).count == section.items.count)
                for item in section.items {
                    #expect(!String(ChangelogView.renderedItem(item).characters).contains("**"))
                }
            }
        }
    }

    @Test("Release note markdown renders without localization side effects")
    func renderedItems() {
        #expect(String(ChangelogView.renderedItem("**Bold** 100% `code`").characters) == "Bold 100% code")
        #expect(String(ChangelogView.renderedItem("Unclosed **bold").characters).contains("Unclosed"))
        #expect(String(ChangelogView.renderedItem("").characters).isEmpty)
    }

    @Test("Search matches versions, summaries, sections and items")
    func searchMatching() {
        let release = ReleaseChangelog("9.9.9", "Spaces fix", [("Fixes", ["**Docker** quits"])])
        #expect(release.matches(""))
        #expect(release.matches("  "))
        #expect(release.matches("9.9"))
        #expect(release.matches("spaces"))
        #expect(release.matches("fixes"))
        #expect(release.matches("docker"))
        #expect(!release.matches("chrome"))
    }
}
