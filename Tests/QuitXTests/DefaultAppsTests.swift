import AppKit
import SwiftUI
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

    @Test("Validator explains each problem and offers a fix where it can")
    func validator() {
        let checks = DefaultAppsInputValidator.checks(
            for: ".ts, vscode:, public.folder, https://example.com/path, .TS",
            existing: [],
            categories: []
        )
        #expect(checks.map(\.level) == [.ok, .ok, .error, .error, .error])
        #expect(checks[0].target == .fileExtension("ts"))
        #expect(checks[1].target == .urlScheme("vscode"))
        #expect(checks[2].detail.contains("won't change"))
        #expect(checks[3].suggestion == "https:")
        #expect(checks[4].detail.contains("twice"))

        #expect(DefaultAppsInputValidator.check("1abc:").detail.contains("start with a letter"))
        #expect(DefaultAppsInputValidator.check(":").detail.contains("before the colon"))
        #expect(DefaultAppsInputValidator.check(".ts$").detail.contains("\u{201C}$\u{201D}"))
        #expect(DefaultAppsInputValidator.check(".").detail.contains("after the dot"))
        #expect(DefaultAppsInputValidator.check("my ext").suggestion == "myext")
        #expect(DefaultAppsInputValidator.check("com.example.json").suggestion == ".json")
        #expect(DefaultAppsInputValidator.check(".qxzzunknown").level == .warning)
        #expect(DefaultAppsInputValidator.check(".pdf", existing: [.contentType("com.adobe.pdf")]).level == .ok)
        #expect(DefaultAppsInputValidator.check(".pdf", existing: [.fileExtension("pdf")]).level == .error)

        let pdf = DefaultAppCategory(id: "pdf", title: "PDF Viewer", symbol: "doc", detail: "", targets: [.contentType("com.adobe.pdf")])
        #expect(DefaultAppsInputValidator.check(".pdf", categories: [pdf]).detail.contains("Also under PDF Viewer"))

        let many = (0..<25).map { ".x\($0)" }.joined(separator: ",")
        let limited = DefaultAppsInputValidator.checks(for: many, existing: [], categories: [])
        #expect(limited.filter { $0.level == .error }.count == 5)
        #expect(DefaultAppsInputValidator.tokens(" .a ;\n.b,, ") == [".a", ".b"])
    }

    @Test("Field adds ready entries, keeps broken ones, applies fixes and looks up apps")
    @MainActor
    func inputFlow() async {
        let backend = FakeDefaultAppsBackend(
            defaults: ["ext:md": URL(fileURLWithPath: "/System/Applications/TextEdit.app")],
            candidates: ["ext:md": [URL(fileURLWithPath: "/System/Applications/TextEdit.app"), Self.chrome]]
        )
        let model = DefaultAppsModel(backend: backend, defaults: Self.freshDefaults(), categories: [])
        model.customInput = ".md, bad$, https://example.com"
        #expect(model.inputChecks.count == 3)
        #expect(model.addableInputCount == 1)
        #expect(model.hasInputErrors)

        await Self.waitUntil { model.inputHandlers["ext:md"] != nil }
        #expect(model.inputHandlers["ext:md"]?.count == 2)
        #expect(model.inputHandlers["ext:md"]?.current?.name == "TextEdit")

        model.applySuggestion(model.inputChecks[2])
        #expect(model.customInput == ".md, bad$, https:")

        model.addCustomFromInput()
        #expect(model.customTargets == [.fileExtension("md"), .urlScheme("https")])
        #expect(model.customInput == "bad$")
        #expect(model.message?.isError == false)

        model.appendExample(".json")
        #expect(model.customInput == "bad$, .json")
        #expect(!model.isExampleAvailable(".md"))
        #expect(model.isExampleAvailable(".json"))
    }

    @Test("Render the Custom page with live validation")
    @MainActor
    func renderCustom() async throws {
        let qa = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".qa")
        guard FileManager.default.fileExists(atPath: qa.path) else { return }
        let dir = qa.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let model = DefaultAppsModel.shared
        let previousMode = model.mode
        let previousInput = model.customInput
        model.mode = .custom
        model.customInput = ".ts, vscode:, https://example.com, .bad$, public.folder"
        defer {
            model.customInput = previousInput
            model.mode = previousMode
        }
        for dark in [true, false] {
            let hosting = NSHostingView(rootView: ScrollView { DefaultAppsTabView() }.frame(width: SettingsTab.contentWidth, height: 620))
            hosting.frame = NSRect(x: 0, y: 0, width: SettingsTab.contentWidth, height: 620)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.backgroundColor = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
            window.contentView = hosting
            try await Task.sleep(nanoseconds: 900_000_000)
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("default-apps-custom-\(dark ? "dark" : "light").png"))
            window.contentView = nil
        }
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
