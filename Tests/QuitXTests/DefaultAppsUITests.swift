import AppKit
import SwiftUI
import Testing
@testable import QuitX

extension GUIIntegrationTests.SnapshotTests {
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

    @Test("Render the app chooser window")
    @MainActor
    func renderChooser() async throws {
        let qa = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent(".qa")
        guard FileManager.default.fileExists(atPath: qa.path) else { return }
        let dir = qa.appendingPathComponent("snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let preview = HandlerApp(url: URL(fileURLWithPath: "/System/Applications/Preview.app"))
        let request = DefaultAppsChooserRequest(
            title: "Choose an App for PDF Viewer",
            subtitle: "PDF document",
            suggested: [preview, HandlerApp(url: URL(fileURLWithPath: "/Applications/Safari.app"))],
            current: preview,
            confirmTitle: "Use App",
            onChoose: { _ in }
        )
        let model = DefaultAppsChooserModel(request: request)
        model.load()
        for _ in 0..<100 where model.isLoading { try await Task.sleep(for: .milliseconds(50)) }
        model.moveSelection(by: 3)
        for dark in [true, false] {
            let size = DefaultAppsAppChooserWindowController.size
            let hosting = NSHostingView(rootView: DefaultAppsAppChooserView(model: model, onChoose: { _ in }, onBrowse: {}, onCancel: {}))
            hosting.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            window.backgroundColor = dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)
            window.contentView = hosting
            try await Task.sleep(nanoseconds: 900_000_000)
            hosting.layoutSubtreeIfNeeded()
            guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
            hosting.cacheDisplay(in: hosting.bounds, to: rep)
            try rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("default-apps-chooser-\(dark ? "dark" : "light").png"))
            window.contentView = nil
        }
    }
}

extension GUIIntegrationTests.WindowLayoutTests {
    @Test("App chooser window stays exact size and fills bottom edge without transparency")
    @MainActor
    func chooserWindowFillsBottom() async throws {
        let store = ConfigStore.shared
        let previousGlass = store.config.liquidGlassEnabled
        store.config.liquidGlassEnabled = false
        defer { store.config.liquidGlassEnabled = previousGlass }

        let controller = DefaultAppsAppChooserWindowController.shared
        defer { controller.close() }
        controller.present(DefaultAppsChooserRequest(
            title: "Choose an App",
            subtitle: "Test",
            suggested: [],
            current: nil,
            confirmTitle: "Use App",
            onChoose: { _ in }
        ))

        guard let window = controller.window, let contentView = window.contentView else {
            Issue.record("Chooser window failed to open")
            return
        }
        window.layoutIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))

        #expect(window.frame.size == DefaultAppsAppChooserWindowController.size)
        #expect(contentView.bounds.size == DefaultAppsAppChooserWindowController.size)

        if let rep = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds) {
            contentView.cacheDisplay(in: contentView.bounds, to: rep)
            let bottomColor = rep.colorAt(x: rep.pixelsWide / 2, y: rep.pixelsHigh - 2)
            #expect((bottomColor?.alphaComponent ?? 0) >= 0.99)
        }
    }
}
