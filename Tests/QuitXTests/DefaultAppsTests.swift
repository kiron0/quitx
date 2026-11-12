import AppKit
import Foundation
import Testing
import UniformTypeIdentifiers
@testable import QuitX

private final class FakeDefaultAppsBackend: DefaultAppsBackend, @unchecked Sendable {
    private let lock = NSLock()
    private var defaults: [String: URL]
    private let candidates: [String: [URL]]
    private let failing: Set<String>

    init(defaults: [String: URL], candidates: [String: [URL]], failing: Set<String> = []) {
        self.defaults = defaults
        self.candidates = candidates
        self.failing = failing
    }

    func defaultApp(for target: DefaultAppTarget) -> URL? {
        lock.lock(); defer { lock.unlock() }
        return defaults[target.id]
    }

    func candidateApps(for target: DefaultAppTarget) -> [URL] {
        candidates[target.id] ?? []
    }

    func setDefault(_ appURL: URL, for target: DefaultAppTarget) async throws {
        if failing.contains(target.id) { throw DefaultAppsError.unknownType(target.title) }
        lock.lock(); defer { lock.unlock() }
        defaults[target.id] = appURL
    }
}

@Suite("Default Apps")
struct DefaultAppsTests {
    private static let safari = URL(fileURLWithPath: "/Applications/Safari.app")
    private static let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")

    private static let browser = DefaultAppCategory(
        id: "browser",
        title: "Web Browser",
        symbol: "safari",
        detail: "Links.",
        targets: [.urlScheme("http"), .urlScheme("https")]
    )

    private static func freshDefaults() -> UserDefaults {
        let name = "quitx.tests.defaultapps.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    private static func waitUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<300 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test("Parses extensions, schemes and type identifiers")
    func parse() {
        #expect(DefaultAppTarget.parse(".ts") == .fileExtension("ts"))
        #expect(DefaultAppTarget.parse("*.MD") == .fileExtension("md"))
        #expect(DefaultAppTarget.parse("json") == .fileExtension("json"))
        #expect(DefaultAppTarget.parse("vscode:") == .urlScheme("vscode"))
        #expect(DefaultAppTarget.parse("Slack://") == .urlScheme("slack"))
        #expect(DefaultAppTarget.parse("public.json") == .contentType("public.json"))
        #expect(DefaultAppTarget.parse("") == nil)
        #expect(DefaultAppTarget.parse("1abc:") == nil)
        #expect(DefaultAppTarget.parse("bad ext") == nil)
        #expect(DefaultAppTarget.parse("no.such.type.quitx") == nil)
    }

    @Test("Refuses folders, apps, every-file types and file links")
    func blocksBroadTargets() {
        #expect(DefaultAppTarget.contentType("public.folder").isTooBroad)
        #expect(DefaultAppTarget.contentType("public.data").isTooBroad)
        #expect(DefaultAppTarget.contentType("com.apple.application-bundle").isTooBroad)
        #expect(DefaultAppTarget.fileExtension("app").isTooBroad)
        #expect(DefaultAppTarget.urlScheme("file").isTooBroad)
        #expect(!DefaultAppTarget.contentType("com.adobe.pdf").isTooBroad)
        #expect(!DefaultAppTarget.urlScheme("mailto").isTooBroad)
    }

    @Test("Display text names the extension or scheme")
    func titles() {
        #expect(DefaultAppTarget.contentType("com.adobe.pdf").title == ".pdf")
        #expect(DefaultAppTarget.fileExtension("ts").title == ".ts")
        #expect(DefaultAppTarget.urlScheme("mailto").title == "mailto:")
        #expect(DefaultAppTarget.urlScheme("mailto").sampleURL?.scheme == "mailto")
        #expect(DefaultAppTarget.fileExtension("ts").contentTypes.contains { $0.identifier == "public.mpeg-2-transport-stream" })
    }

    @Test("Built-in categories resolve on this Mac and use valid symbols")
    @MainActor
    func categories() {
        let model = DefaultAppsModel(backend: FakeDefaultAppsBackend(defaults: [:], candidates: [:]), defaults: Self.freshDefaults())
        #expect(model.categories.contains { $0.id == "browser" })
        #expect(model.categories.contains { $0.id == "pdf" })
        #expect(model.categories.contains { $0.id == "code" })
        for category in model.categories {
            #expect(!category.targets.isEmpty)
            #expect(NSImage(systemSymbolName: category.symbol, accessibilityDescription: nil) != nil)
            #expect(category.targets.allSatisfy { !$0.isTooBroad && $0.isResolvable })
            #expect(Set(category.targets.map(\.id)).count == category.targets.count)
        }
    }

    @Test("Reads document types and URL schemes from an app's Info.plist")
    func declaredTargets() {
        let plist: [String: Any] = [
            "CFBundleDocumentTypes": [
                ["LSItemContentTypes": ["com.adobe.pdf", "public.folder", "public.data"]],
                ["CFBundleTypeExtensions": ["ts", "*", "TSX"]],
                ["LSItemContentTypes": ["public.png"], "LSHandlerRank": "None"],
                ["LSItemContentTypes": ["com.adobe.pdf"]],
            ],
            "CFBundleURLTypes": [
                ["CFBundleURLSchemes": ["vscode", "File", "9bad"]],
            ],
        ]
        let targets = DefaultAppsScanner.declaredTargets(infoPlist: plist)
        #expect(targets.contains(.contentType("com.adobe.pdf")))
        #expect(targets.contains(.fileExtension("ts")))
        #expect(targets.contains(.urlScheme("vscode")))
        #expect(!targets.contains(.contentType("public.folder")))
        #expect(!targets.contains(.contentType("public.data")))
        #expect(!targets.contains(.contentType("public.png")))
        #expect(!targets.contains(.urlScheme("file")))
        #expect(targets.filter { $0 == .contentType("com.adobe.pdf") }.count == 1)
    }

    @Test("Duplicate app copies collapse to one, preferring the current default")
    func dedupe() {
        let copy = HandlerApp(url: URL(fileURLWithPath: "/Users/me/Downloads/Safari.app"), bundleID: "com.apple.Safari", name: "Safari")
        let main = HandlerApp(url: Self.safari, bundleID: "com.apple.Safari", name: "Safari")
        let chrome = HandlerApp(url: Self.chrome, bundleID: "com.google.Chrome", name: "Google Chrome")
        let result = DefaultAppsScanner.dedupe([copy, chrome, main], preferring: nil)
        #expect(result.map(\.name) == ["Google Chrome", "Safari"])
        #expect(result.last?.url == Self.safari)
        let preferred = DefaultAppsScanner.dedupe([main, copy], preferring: copy)
        #expect(preferred.first?.url == copy.url)
    }

    @Test("Changing a category sets every target, records history and undo restores it")
    @MainActor
    func setAndUndo() async {
        let backend = FakeDefaultAppsBackend(
            defaults: ["scheme:http": Self.safari, "scheme:https": Self.safari],
            candidates: ["scheme:http": [Self.safari, Self.chrome], "scheme:https": [Self.safari, Self.chrome]]
        )
        let model = DefaultAppsModel(backend: backend, defaults: Self.freshDefaults(), categories: [Self.browser])
        model.refresh()
        await Self.waitUntil { model.hasLoaded }
        #expect(model.summary(for: model.categories[0]).app?.url == Self.safari)
        #expect(model.choices(for: Self.browser.targets).map(\.count) == [2, 2])

        let chrome = HandlerApp(url: Self.chrome, bundleID: "com.google.Chrome", name: "Google Chrome")
        model.setDefault(chrome, for: Self.browser.targets)
        #expect(model.isBusy)
        await Self.waitUntil { !model.isBusy }
        #expect(model.entry(for: .urlScheme("http"))?.current?.url == Self.chrome)
        #expect(model.entry(for: .urlScheme("https"))?.current?.url == Self.chrome)
        #expect(model.history.count == 1)
        #expect(model.message?.isError == false)

        model.undoLast()
        await Self.waitUntil { !model.isBusy && model.entry(for: .urlScheme("http"))?.current?.url == Self.safari }
        #expect(model.entry(for: .urlScheme("https"))?.current?.url == Self.safari)
        #expect(model.history.isEmpty)
    }

    @Test("A failed change reports an error and records no history")
    @MainActor
    func failure() async {
        let backend = FakeDefaultAppsBackend(
            defaults: ["scheme:http": Self.safari],
            candidates: ["scheme:http": [Self.safari, Self.chrome]],
            failing: ["scheme:http"]
        )
        let category = DefaultAppCategory(id: "b", title: "B", symbol: "safari", detail: "", targets: [.urlScheme("http")])
        let model = DefaultAppsModel(backend: backend, defaults: Self.freshDefaults(), categories: [category])
        model.refresh()
        await Self.waitUntil { model.hasLoaded }
        model.setDefault(HandlerApp(url: Self.chrome, bundleID: "com.google.Chrome", name: "Google Chrome"), for: [.urlScheme("http")])
        await Self.waitUntil { !model.isBusy && model.message != nil }
        #expect(model.message?.isError == true)
        #expect(model.history.isEmpty)
        #expect(model.entry(for: .urlScheme("http"))?.current?.url == Self.safari)
    }

    @Test("A change macOS silently ignored is reported, not claimed")
    @MainActor
    func unchangedMessage() {
        let chrome = HandlerApp(url: Self.chrome, bundleID: "com.google.Chrome", name: "Google Chrome")
        let safari = HandlerApp(url: Self.safari, bundleID: "com.apple.Safari", name: "Safari")
        let target = DefaultAppTarget.urlScheme("http")
        let unchanged = DefaultAppsModel.resultMessage(
            app: chrome,
            targets: [target],
            failures: [],
            refreshed: [target.id: DefaultAppEntry(target: target, current: safari, candidates: [])]
        )
        #expect(unchanged.isError)
        let changed = DefaultAppsModel.resultMessage(
            app: chrome,
            targets: [target],
            failures: [],
            refreshed: [target.id: DefaultAppEntry(target: target, current: chrome, candidates: [])]
        )
        #expect(!changed.isError)
        #expect(changed.text == "Google Chrome now opens http:.")
    }

    @Test("Custom types persist, reject bad input and never duplicate")
    @MainActor
    func customTargets() {
        let defaults = Self.freshDefaults()
        let model = DefaultAppsModel(backend: FakeDefaultAppsBackend(defaults: [:], candidates: [:]), defaults: defaults, categories: [])
        #expect(model.addCustom(".ts"))
        #expect(model.addCustom("vscode:"))
        #expect(!model.addCustom(".ts"))
        #expect(!model.addCustom("public.folder"))
        #expect(model.message?.isError == true)
        #expect(!model.addCustom("not a type"))
        #expect(model.customTargets == [.fileExtension("ts"), .urlScheme("vscode")])

        let reloaded = DefaultAppsModel(backend: FakeDefaultAppsBackend(defaults: [:], candidates: [:]), defaults: defaults, categories: [])
        #expect(reloaded.customTargets == [.fileExtension("ts"), .urlScheme("vscode")])
        reloaded.removeCustom(.fileExtension("ts"))
        #expect(DefaultAppsModel.loadCustomTargets(from: defaults) == [.urlScheme("vscode")])
    }

    @Test("Default Apps lives under Applications and is searchable")
    func settingsTab() {
        #expect(SettingsTab(rawValue: "Default Apps") == .defaultApps)
        #expect(SettingsTab.defaultApps.category == .applications)
        #expect(SettingsTab.defaultApps.matches("browser"))
        #expect(SettingsTab.defaultApps.matches("open with"))
        #expect(SettingsFeature.defaultApps.tab == .defaultApps)
    }
}
