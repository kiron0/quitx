import AppKit
import Foundation
import UniformTypeIdentifiers

enum DefaultAppTarget: Hashable, Codable, Sendable, Identifiable {
    case contentType(String)
    case fileExtension(String)
    case urlScheme(String)

    var id: String {
        switch self {
        case .contentType(let identifier): return "type:\(identifier)"
        case .fileExtension(let ext): return "ext:\(ext)"
        case .urlScheme(let scheme): return "scheme:\(scheme)"
        }
    }

    var isURLScheme: Bool {
        if case .urlScheme = self { return true }
        return false
    }

    var primaryType: UTType? {
        switch self {
        case .contentType(let identifier): return UTType(identifier)
        case .fileExtension(let ext): return UTType(filenameExtension: ext)
        case .urlScheme: return nil
        }
    }

    var contentTypes: [UTType] {
        switch self {
        case .contentType(let identifier):
            return UTType(identifier).map { [$0] } ?? []
        case .fileExtension(let ext):
            let declared = UTType.types(tag: ext, tagClass: .filenameExtension, conformingTo: nil)
                .filter { !$0.isDynamic && !Self.isTooBroad($0) }
            if !declared.isEmpty { return declared }
            return UTType(filenameExtension: ext).map { [$0] } ?? []
        case .urlScheme:
            return []
        }
    }

    var isResolvable: Bool {
        switch self {
        case .contentType(let identifier): return UTType(identifier) != nil
        case .fileExtension: return !contentTypes.isEmpty
        case .urlScheme(let scheme): return URL(string: "\(scheme)://") != nil
        }
    }

    var isTooBroad: Bool {
        switch self {
        case .urlScheme(let scheme):
            return Self.blockedSchemes.contains(scheme)
        case .contentType(let identifier):
            guard let type = UTType(identifier) else { return false }
            return Self.isTooBroad(type)
        case .fileExtension(let ext):
            guard let type = UTType(filenameExtension: ext) else { return false }
            return Self.isTooBroad(type)
        }
    }

    var title: String {
        switch self {
        case .contentType(let identifier):
            if let ext = UTType(identifier)?.preferredFilenameExtension { return ".\(ext)" }
            return UTType(identifier)?.localizedDescription ?? identifier
        case .fileExtension(let ext):
            return ".\(ext)"
        case .urlScheme(let scheme):
            return "\(scheme):"
        }
    }

    var subtitle: String {
        switch self {
        case .contentType(let identifier):
            return UTType(identifier)?.localizedDescription?.capitalizedFirst ?? identifier
        case .fileExtension:
            let names = contentTypes.compactMap { $0.isDynamic ? nil : $0.localizedDescription?.capitalizedFirst }
            if names.isEmpty { return "Files without a declared type" }
            return names.joined(separator: ", ")
        case .urlScheme(let scheme):
            return "Links that start with \(scheme):"
        }
    }

    var sampleURL: URL? {
        guard case .urlScheme(let scheme) = self else { return nil }
        return URL(string: "\(scheme)://")
    }

    static let blockedSchemes: Set<String> = ["file"]

    static let blockedTypeIdentifiers: Set<String> = [
        "public.item",
        "public.data",
        "public.content",
        "public.composite-content",
        "public.directory",
        "public.folder",
        "public.volume",
        "public.mount-point",
        "public.symlink",
        "public.executable",
        "com.apple.bundle",
        "com.apple.package",
        "com.apple.application",
        "com.apple.application-bundle",
        "com.apple.application-file",
        "com.apple.alias-file",
        "com.apple.resolvable",
    ]

    static func isTooBroad(_ type: UTType) -> Bool {
        if blockedTypeIdentifiers.contains(type.identifier) { return true }
        if type.conforms(to: .application) || type.conforms(to: .directory) { return true }
        return false
    }

    static func parse(_ input: String) -> DefaultAppTarget? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = trimmed.lowercased()
        guard !text.isEmpty else { return nil }
        if text.hasSuffix("://") {
            text.removeLast(3)
            return isValidScheme(text) ? .urlScheme(text) : nil
        }
        if text.hasSuffix(":") {
            text.removeLast()
            return isValidScheme(text) ? .urlScheme(text) : nil
        }
        if text.hasPrefix("*.") { text.removeFirst(2) }
        if text.hasPrefix(".") {
            text.removeFirst()
            return isValidExtension(text) ? .fileExtension(text) : nil
        }
        if text.contains(".") {
            if let type = UTType(trimmed), !type.isDynamic { return .contentType(type.identifier) }
            return nil
        }
        return isValidExtension(text) ? .fileExtension(text) : nil
    }

    static func isValidScheme(_ scheme: String) -> Bool {
        guard scheme.count <= 64, let first = scheme.unicodeScalars.first,
              ("a"..."z").contains(Character(first)) else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789+-.")
        return scheme.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    static func isValidExtension(_ ext: String) -> Bool {
        guard !ext.isEmpty, ext.count <= 32 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_+.")
        return ext.unicodeScalars.allSatisfy { allowed.contains($0) } && !ext.hasPrefix(".") && !ext.hasSuffix(".")
    }
}

private extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

struct DefaultAppCategory: Identifiable, Sendable {
    let id: String
    let title: String
    let symbol: String
    let detail: String
    let targets: [DefaultAppTarget]

    static let all: [DefaultAppCategory] = [
        DefaultAppCategory(
            id: "browser",
            title: "Web Browser",
            symbol: "safari",
            detail: "Web links and saved web pages.",
            targets: [.urlScheme("http"), .urlScheme("https"), .contentType("public.html")]
        ),
        DefaultAppCategory(
            id: "email",
            title: "Email",
            symbol: "envelope",
            detail: "Email links and saved messages.",
            targets: [.urlScheme("mailto"), .contentType("com.apple.mail.email")]
        ),
        DefaultAppCategory(
            id: "pdf",
            title: "PDF Viewer",
            symbol: "doc.richtext",
            detail: "PDF documents.",
            targets: [.contentType("com.adobe.pdf")]
        ),
        DefaultAppCategory(
            id: "images",
            title: "Images",
            symbol: "photo",
            detail: "Photos, screenshots and graphics.",
            targets: [
                .contentType("public.jpeg"), .contentType("public.png"), .contentType("public.heic"),
                .contentType("com.compuserve.gif"), .contentType("public.tiff"), .contentType("org.webmproject.webp"),
                .contentType("com.microsoft.bmp"), .contentType("public.svg-image"),
            ]
        ),
        DefaultAppCategory(
            id: "video",
            title: "Video Player",
            symbol: "play.rectangle",
            detail: "Movies and screen recordings.",
            targets: [
                .contentType("public.mpeg-4"), .contentType("com.apple.quicktime-movie"), .contentType("com.apple.m4v-video"),
                .contentType("public.avi"), .contentType("org.matroska.mkv"), .contentType("org.webmproject.webm"),
            ]
        ),
        DefaultAppCategory(
            id: "music",
            title: "Music Player",
            symbol: "music.note",
            detail: "Songs and audio files.",
            targets: [
                .contentType("public.mp3"), .contentType("public.mpeg-4-audio"), .contentType("com.microsoft.waveform-audio"),
                .contentType("public.aiff-audio"), .contentType("org.xiph.flac"),
            ]
        ),
        DefaultAppCategory(
            id: "code",
            title: "Text & Code Editor",
            symbol: "chevron.left.forwardslash.chevron.right",
            detail: "Plain text, notes, configs and source code.",
            targets: [
                "txt", "md", "json", "yaml", "toml", "xml", "csv", "log",
                "js", "ts", "jsx", "tsx", "css", "swift", "py", "rb", "go", "rs",
                "c", "h", "cpp", "java", "kt", "php", "sh", "zsh",
            ].map { DefaultAppTarget.fileExtension($0) }
        ),
        DefaultAppCategory(
            id: "documents",
            title: "Office Documents",
            symbol: "doc.text",
            detail: "Word, Excel, PowerPoint and rich text files.",
            targets: [
                .contentType("org.openxmlformats.wordprocessingml.document"), .contentType("com.microsoft.word.doc"),
                .contentType("org.openxmlformats.spreadsheetml.sheet"), .contentType("com.microsoft.excel.xls"),
                .contentType("org.openxmlformats.presentationml.presentation"), .contentType("com.microsoft.powerpoint.ppt"),
                .contentType("public.rtf"), .contentType("org.oasis-open.opendocument.text"),
            ]
        ),
        DefaultAppCategory(
            id: "archives",
            title: "Archives",
            symbol: "archivebox",
            detail: "Zip, tar, gzip, RAR and 7-Zip archives.",
            targets: [
                .contentType("public.zip-archive"), .contentType("public.tar-archive"), .contentType("org.gnu.gnu-zip-archive"),
                .contentType("public.bzip2-archive"), .contentType("com.rarlab.rar-archive"), .contentType("org.7-zip.7-zip-archive"),
            ]
        ),
        DefaultAppCategory(
            id: "calendar",
            title: "Calendar & Contacts",
            symbol: "calendar",
            detail: "Event invites, calendar subscriptions and contact cards.",
            targets: [.contentType("com.apple.ical.ics"), .urlScheme("webcal"), .contentType("public.vcard")]
        ),
        DefaultAppCategory(
            id: "remote",
            title: "Terminal & Remote",
            symbol: "terminal",
            detail: "SSH, Telnet and file-transfer links.",
            targets: [.urlScheme("ssh"), .urlScheme("telnet"), .urlScheme("ftp"), .urlScheme("sftp")]
        ),
    ]
}

struct HandlerApp: Identifiable, Hashable, Sendable {
    let url: URL
    let bundleID: String?
    let name: String

    var id: String { url.standardizedFileURL.path }

    init(url: URL, bundleID: String?, name: String) {
        self.url = url
        self.bundleID = bundleID
        self.name = name
    }

    init(url: URL) {
        let standardized = url.standardizedFileURL
        self.url = standardized
        self.bundleID = Bundle(url: standardized)?.bundleIdentifier
        var display = FileManager.default.displayName(atPath: standardized.path)
        if display.lowercased().hasSuffix(".app") { display.removeLast(4) }
        self.name = display
    }

    var isInApplicationsFolder: Bool {
        let path = url.path
        let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path + "/"
        return path.hasPrefix("/Applications/") || path.hasPrefix("/System/Applications/") || path.hasPrefix(userApps)
    }

    func matches(_ other: HandlerApp?) -> Bool {
        guard let other else { return false }
        if let bundleID, let otherID = other.bundleID { return bundleID == otherID }
        return id == other.id
    }
}

struct DefaultAppEntry: Identifiable, Sendable {
    let target: DefaultAppTarget
    let current: HandlerApp?
    let candidates: [HandlerApp]

    var id: String { target.id }
}

struct DefaultAppChange: Identifiable, Sendable {
    let id = UUID()
    let app: HandlerApp
    let previous: [(target: DefaultAppTarget, app: HandlerApp)]
}

struct DefaultAppsMessage: Equatable, Sendable {
    let text: String
    let isError: Bool
}

struct DefaultAppInputCheck: Identifiable, Equatable, Sendable {
    enum Level: Equatable, Sendable {
        case ok
        case warning
        case error
    }

    let id: Int
    let token: String
    let target: DefaultAppTarget?
    let level: Level
    let title: String
    let detail: String
    var suggestion: String? = nil

    var canAdd: Bool { target != nil && level != .error }
}

struct DefaultAppInputHandlers: Equatable, Sendable {
    let current: HandlerApp?
    let count: Int
}

enum DefaultAppsInputValidator {
    static let maxTokens = 20
    static let separators = CharacterSet(charactersIn: ",;\n")

    static func tokens(_ input: String) -> [String] {
        input.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func checks(
        for input: String,
        existing: [DefaultAppTarget],
        categories: [DefaultAppCategory]
    ) -> [DefaultAppInputCheck] {
        var seen = Set<String>()
        return tokens(input).enumerated().map { index, token in
            guard index < maxTokens else {
                return DefaultAppInputCheck(
                    id: index,
                    token: token,
                    target: nil,
                    level: .error,
                    title: token,
                    detail: "Add up to \(maxTokens) at a time."
                )
            }
            let check = check(token, index: index, existing: existing, categories: categories, earlier: seen)
            if let target = check.target { seen.insert(target.id) }
            return check
        }
    }

    static func check(
        _ token: String,
        index: Int = 0,
        existing: [DefaultAppTarget] = [],
        categories: [DefaultAppCategory] = [],
        earlier: Set<String> = []
    ) -> DefaultAppInputCheck {
        func failure(_ detail: String, title: String? = nil, suggestion: String? = nil) -> DefaultAppInputCheck {
            DefaultAppInputCheck(id: index, token: token, target: nil, level: .error, title: title ?? token, detail: detail, suggestion: suggestion)
        }

        if token.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            let joined = token.components(separatedBy: .whitespacesAndNewlines).joined()
            let suggestion = DefaultAppTarget.parse(joined) != nil ? joined : nil
            return failure("Remove the spaces. To add several, separate them with commas.", suggestion: suggestion)
        }

        guard let target = DefaultAppTarget.parse(token) else {
            return diagnose(token, failure: failure)
        }
        let shown: String
        if case .contentType(let identifier) = target { shown = identifier } else { shown = target.title }

        if target.isTooBroad {
            return failure("\(shown) covers folders, apps or every file, so QuitX won't change it.", title: shown)
        }
        guard target.isResolvable else {
            return failure("macOS doesn't recognize \(shown).", title: shown)
        }
        if existing.contains(target) {
            return failure("Already in your list.", title: shown)
        }
        if earlier.contains(target.id) {
            return failure("Typed twice. It will be added once.", title: shown)
        }

        var notes: [String] = ["\(target.subtitle)."]
        if let category = categories.first(where: { category in category.targets.contains { $0.covers(target) } }) {
            notes.append("Also under \(category.title).")
        }

        if case .fileExtension = target, target.contentTypes.allSatisfy(\.isDynamic) {
            return DefaultAppInputCheck(
                id: index,
                token: token,
                target: target,
                level: .warning,
                title: shown,
                detail: "No app on this Mac declares \(target.title) yet. You can still pick one with Other App…"
            )
        }

        return DefaultAppInputCheck(
            id: index,
            token: token,
            target: target,
            level: .ok,
            title: shown,
            detail: notes.joined(separator: " ")
        )
    }

    private static func diagnose(
        _ token: String,
        failure: (String, String?, String?) -> DefaultAppInputCheck
    ) -> DefaultAppInputCheck {
        let lower = token.lowercased()

        if let range = lower.range(of: "://"), !lower.hasSuffix("://") {
            let scheme = String(lower[..<range.lowerBound])
            if DefaultAppTarget.isValidScheme(scheme) {
                return failure("Only the link scheme is needed, not the full address.", nil, "\(scheme):")
            }
        }

        if lower.hasSuffix(":") || lower.hasSuffix("://") {
            var scheme = lower
            if scheme.hasSuffix("://") { scheme.removeLast(3) } else { scheme.removeLast() }
            if scheme.isEmpty {
                return failure("Type a scheme name before the colon, like vscode:.", nil, nil)
            }
            if let first = scheme.first, !("a"..."z").contains(first) {
                return failure("Link schemes start with a letter, like vscode: or slack:.", nil, nil)
            }
            if scheme.count > 64 {
                return failure("Link schemes can be at most 64 characters.", nil, nil)
            }
            let bad = invalidCharacters(in: scheme, allowed: "abcdefghijklmnopqrstuvwxyz0123456789+-.")
            return failure("Link schemes can use letters, numbers, +, - and . only. Remove \(bad).", nil, nil)
        }

        var ext = lower
        if ext.hasPrefix("*.") { ext.removeFirst(2) } else if ext.hasPrefix(".") { ext.removeFirst() } else if ext.contains(".") {
            let last = ext.split(separator: ".").last.map(String.init) ?? ""
            let suggestion = DefaultAppTarget.isValidExtension(last) && UTType(filenameExtension: last).map { !$0.isDynamic } == true ? ".\(last)" : nil
            return failure("macOS doesn't know a type called \u{201C}\(token)\u{201D}. Check the spelling, or type an extension like .json.", nil, suggestion)
        }

        if ext.isEmpty {
            return failure("Type an extension after the dot, like .md.", nil, nil)
        }
        if ext.count > 32 {
            return failure("File extensions can be at most 32 characters.", nil, nil)
        }
        if ext.hasSuffix(".") {
            return failure("A file extension can't end with a dot.", nil, String(ext.dropLast()).isEmpty ? nil : ".\(ext.dropLast())")
        }
        let bad = invalidCharacters(in: ext, allowed: "abcdefghijklmnopqrstuvwxyz0123456789-_+.")
        if !bad.isEmpty {
            return failure("File extensions can use letters, numbers, -, _ and + only. Remove \(bad).", nil, nil)
        }
        return failure("Type an extension like .ts, a link scheme like vscode:, or a type like public.json.", nil, nil)
    }

    private static func invalidCharacters(in text: String, allowed: String) -> String {
        let allowedSet = Set(allowed)
        var bad: [Character] = []
        for character in text where !allowedSet.contains(character) && !bad.contains(character) {
            bad.append(character)
        }
        return bad.map { "\u{201C}\($0)\u{201D}" }.joined(separator: ", ")
    }
}

extension DefaultAppTarget {
    func covers(_ other: DefaultAppTarget) -> Bool {
        if self == other { return true }
        if isURLScheme || other.isURLScheme { return false }
        guard let mine = primaryType?.identifier, let theirs = other.primaryType?.identifier else { return false }
        return mine == theirs
    }
}

protocol DefaultAppsBackend: Sendable {
    func defaultApp(for target: DefaultAppTarget) -> URL?
    func candidateApps(for target: DefaultAppTarget) -> [URL]
    func setDefault(_ appURL: URL, for target: DefaultAppTarget) async throws
}

struct LaunchServicesDefaultAppsBackend: DefaultAppsBackend {
    func defaultApp(for target: DefaultAppTarget) -> URL? {
        if let url = target.sampleURL { return NSWorkspace.shared.urlForApplication(toOpen: url) }
        guard let type = target.primaryType else { return nil }
        return NSWorkspace.shared.urlForApplication(toOpen: type)
    }

    func candidateApps(for target: DefaultAppTarget) -> [URL] {
        if let url = target.sampleURL { return NSWorkspace.shared.urlsForApplications(toOpen: url) }
        var urls: [URL] = []
        for type in target.contentTypes {
            urls.append(contentsOf: NSWorkspace.shared.urlsForApplications(toOpen: type))
        }
        return urls
    }

    func setDefault(_ appURL: URL, for target: DefaultAppTarget) async throws {
        switch target {
        case .urlScheme(let scheme):
            try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpenURLsWithScheme: scheme)
        case .contentType, .fileExtension:
            let types = target.contentTypes
            guard !types.isEmpty else { throw DefaultAppsError.unknownType(target.title) }
            for type in types {
                try await NSWorkspace.shared.setDefaultApplication(at: appURL, toOpen: type)
            }
        }
    }
}

enum DefaultAppsError: LocalizedError {
    case unknownType(String)

    var errorDescription: String? {
        switch self {
        case .unknownType(let title): return "macOS doesn't know a file type for \(title)."
        }
    }
}

enum DefaultAppsScanner {
    static func entries(for targets: [DefaultAppTarget], backend: any DefaultAppsBackend) async -> [String: DefaultAppEntry] {
        var result: [String: DefaultAppEntry] = [:]
        var appCache: [String: HandlerApp] = [:]
        func app(_ url: URL) -> HandlerApp {
            let key = url.standardizedFileURL.path
            if let cached = appCache[key] { return cached }
            let made = HandlerApp(url: url)
            appCache[key] = made
            return made
        }
        for target in targets where result[target.id] == nil {
            if Task.isCancelled { break }
            let current = backend.defaultApp(for: target).map(app)
            let candidates = dedupe(backend.candidateApps(for: target).map(app), preferring: current)
            result[target.id] = DefaultAppEntry(target: target, current: current, candidates: candidates)
        }
        return result
    }

    static func dedupe(_ apps: [HandlerApp], preferring current: HandlerApp?) -> [HandlerApp] {
        var chosen: [String: HandlerApp] = [:]
        var order: [String] = []
        for app in apps {
            let key = app.bundleID ?? app.id
            guard let existing = chosen[key] else {
                chosen[key] = app
                order.append(key)
                continue
            }
            if rank(app, current: current) < rank(existing, current: current) {
                chosen[key] = app
            }
        }
        return order.compactMap { chosen[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func rank(_ app: HandlerApp, current: HandlerApp?) -> Int {
        if let current, app.id == current.id { return 0 }
        if app.isInApplicationsFolder { return 1 }
        return 2 + app.url.pathComponents.count
    }

    static func loadDeclaredTargets(of appURL: URL) async -> [DefaultAppTarget] {
        declaredTargets(of: appURL)
    }

    static func declaredTargets(of appURL: URL) -> [DefaultAppTarget] {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }
        return declaredTargets(infoPlist: plist)
    }

    static func declaredTargets(infoPlist: [String: Any]) -> [DefaultAppTarget] {
        var result: [DefaultAppTarget] = []
        var seen = Set<String>()
        var seenTypes = Set<String>()
        func add(_ target: DefaultAppTarget) {
            guard target.isResolvable, !target.isTooBroad, seen.insert(target.id).inserted else { return }
            if !target.isURLScheme, let type = target.primaryType {
                guard seenTypes.insert(type.identifier).inserted else { return }
            }
            result.append(target)
        }
        for document in infoPlist["CFBundleDocumentTypes"] as? [[String: Any]] ?? [] {
            if (document["LSHandlerRank"] as? String) == "None" { continue }
            let types = document["LSItemContentTypes"] as? [String] ?? []
            for identifier in types {
                add(.contentType(identifier))
            }
            if types.isEmpty {
                for ext in document["CFBundleTypeExtensions"] as? [String] ?? [] where ext != "*" {
                    let normalized = ext.lowercased()
                    if DefaultAppTarget.isValidExtension(normalized) { add(.fileExtension(normalized)) }
                }
            }
        }
        for urlType in infoPlist["CFBundleURLTypes"] as? [[String: Any]] ?? [] {
            for scheme in urlType["CFBundleURLSchemes"] as? [String] ?? [] {
                let normalized = scheme.lowercased()
                if DefaultAppTarget.isValidScheme(normalized) { add(.urlScheme(normalized)) }
            }
        }
        return result
    }
}

@MainActor
final class DefaultAppsModel: ObservableObject {
    static let shared = DefaultAppsModel()

    enum Mode: String, CaseIterable, Hashable {
        case categories = "Categories"
        case byApp = "By App"
        case custom = "Custom"
    }

    @Published var mode: Mode = .categories
    @Published private(set) var entries: [String: DefaultAppEntry] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var busyTargets: Set<String> = []
    @Published private(set) var history: [DefaultAppChange] = []
    @Published private(set) var customTargets: [DefaultAppTarget]
    @Published private(set) var knownApps: [HandlerApp] = []
    @Published private(set) var selectedApp: HandlerApp?
    @Published private(set) var selectedAppTargets: [DefaultAppTarget] = []
    @Published private(set) var isLoadingSelectedApp = false
    @Published var expandedCategories: Set<String> = []
    @Published var message: DefaultAppsMessage?
    @Published var customInput = "" {
        didSet {
            if customInput != oldValue { inputDidChange() }
        }
    }
    @Published private(set) var inputChecks: [DefaultAppInputCheck] = []
    @Published private(set) var inputHandlers: [String: DefaultAppInputHandlers] = [:]
    @Published private(set) var menuIcons: [String: NSImage] = [:]

    let categories: [DefaultAppCategory]
    private let backend: any DefaultAppsBackend
    private let defaults: UserDefaults
    private var generation = 0
    private var loadTask: Task<Void, Never>?
    private var selectTask: Task<Void, Never>?
    private var inputTask: Task<Void, Never>?
    private var iconTask: Task<Void, Never>?
    private var pendingTasks: [UUID: Task<Void, Never>] = [:]

    static let menuIconSize = NSSize(width: 16, height: 16)
    static let inputExamples = [".ts", ".md", ".json", ".yaml", "vscode:", "slack:", "zoommtg:", "public.json"]

    init(
        backend: any DefaultAppsBackend = LaunchServicesDefaultAppsBackend(),
        defaults: UserDefaults = .standard,
        categories: [DefaultAppCategory] = DefaultAppCategory.all
    ) {
        self.backend = backend
        self.defaults = defaults
        self.categories = categories.map { category in
            var seen = Set<String>()
            let targets = category.targets.filter { target in
                guard target.isResolvable else { return false }
                let key = target.isURLScheme ? target.id : (target.primaryType?.identifier ?? target.id)
                return seen.insert(key).inserted
            }
            return DefaultAppCategory(id: category.id, title: category.title, symbol: category.symbol, detail: category.detail, targets: targets)
        }
        .filter { !$0.targets.isEmpty }
        self.customTargets = Self.loadCustomTargets(from: defaults)
    }

    deinit {
        loadTask?.cancel()
        selectTask?.cancel()
        inputTask?.cancel()
        iconTask?.cancel()
        for task in pendingTasks.values { task.cancel() }
    }

    var allTargets: [DefaultAppTarget] {
        categories.flatMap(\.targets) + customTargets + selectedAppTargets
    }

    var isBusy: Bool { !busyTargets.isEmpty }

    func loadIfNeeded() {
        guard !hasLoaded, !isLoading else { return }
        refresh()
    }

    func refresh() {
        loadTask?.cancel()
        generation += 1
        let token = generation
        let targets = allTargets
        let backend = backend
        isLoading = true
        loadTask = Task { [weak self] in
            let result = await DefaultAppsScanner.entries(for: targets, backend: backend)
            guard let self, !Task.isCancelled, token == self.generation else { return }
            self.entries = result
            self.isLoading = false
            self.hasLoaded = true
            self.rebuildKnownApps()
        }
    }

    func entry(for target: DefaultAppTarget) -> DefaultAppEntry? {
        entries[target.id]
    }

    func summary(for category: DefaultAppCategory) -> (app: HandlerApp?, isMixed: Bool) {
        let apps = category.targets.compactMap { entries[$0.id]?.current }
        guard let first = apps.first else { return (nil, false) }
        let mixed = apps.contains { !$0.matches(first) } || apps.count < category.targets.count
        return (first, mixed)
    }

    func choices(for targets: [DefaultAppTarget]) -> [(app: HandlerApp, count: Int)] {
        var counts: [String: (app: HandlerApp, count: Int)] = [:]
        for target in targets {
            for app in entries[target.id]?.candidates ?? [] {
                let key = app.bundleID ?? app.id
                counts[key, default: (app, 0)].count += 1
            }
        }
        return counts.values.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
        }
    }

    func setDefault(_ app: HandlerApp, for targets: [DefaultAppTarget]) {
        apply(app, to: targets, recordHistory: true)
    }

    func undoLast() {
        guard let change = history.popLast() else { return }
        var groups: [String: (app: HandlerApp, targets: [DefaultAppTarget])] = [:]
        for item in change.previous {
            groups[item.app.id, default: (item.app, [])].targets.append(item.target)
        }
        for group in groups.values {
            apply(group.app, to: group.targets, recordHistory: false)
        }
    }

    func chooseApp(
        for targets: [DefaultAppTarget],
        current: HandlerApp?,
        title: String,
        subtitle: String,
        confirmTitle: String = "Use App",
        onChoose: @escaping @MainActor (HandlerApp) -> Void
    ) {
        let suggested = targets.isEmpty ? [] : choices(for: targets).map(\.app)
        DefaultAppsAppChooserWindowController.shared.present(DefaultAppsChooserRequest(
            title: title,
            subtitle: subtitle,
            suggested: suggested,
            current: current,
            confirmTitle: confirmTitle,
            onChoose: onChoose
        ))
    }

    static func browseForApp(prompt: String = "Choose") -> HandlerApp? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.prompt = prompt
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return HandlerApp(url: url)
    }

    func selectApp(_ app: HandlerApp?) {
        selectTask?.cancel()
        selectedApp = app
        guard let app else {
            selectedAppTargets = []
            isLoadingSelectedApp = false
            return
        }
        isLoadingSelectedApp = true
        let backend = backend
        selectTask = Task { [weak self] in
            let targets = await DefaultAppsScanner.loadDeclaredTargets(of: app.url)
            let loaded = await DefaultAppsScanner.entries(for: targets, backend: backend)
            guard let self, !Task.isCancelled, self.selectedApp?.id == app.id else { return }
            self.selectedAppTargets = targets
            self.entries.merge(loaded) { _, new in new }
            self.isLoadingSelectedApp = false
            self.rebuildKnownApps()
        }
    }

    var addableInputCount: Int {
        inputChecks.filter(\.canAdd).count
    }

    var hasInputErrors: Bool {
        inputChecks.contains { $0.level == .error }
    }

    @discardableResult
    func addCustom(_ input: String) -> Bool {
        let result = addTargets(from: input)
        if result.added.isEmpty {
            let detail = result.rejected.first?.detail ?? "Type a file extension like .ts, a link scheme like vscode:, or a type identifier like public.json."
            message = DefaultAppsMessage(text: detail, isError: true)
            return false
        }
        message = nil
        return true
    }

    func addCustomFromInput() {
        let result = addTargets(from: customInput)
        guard !result.added.isEmpty else { return }
        let names = result.added.map(\.title)
        let list = names.count <= 3 ? names.joined(separator: ", ") : "\(names.count) types"
        if result.rejected.isEmpty {
            message = DefaultAppsMessage(text: "Added \(list). Pick an app for each one below.", isError: false)
        } else {
            message = DefaultAppsMessage(text: "Added \(list). Fix the rest in the field above.", isError: false)
        }
        customInput = result.rejected.map(\.token).joined(separator: ", ")
    }

    func applySuggestion(_ check: DefaultAppInputCheck) {
        guard let suggestion = check.suggestion else { return }
        var tokens = DefaultAppsInputValidator.tokens(customInput)
        guard check.id < tokens.count else { return }
        tokens[check.id] = suggestion
        customInput = tokens.joined(separator: ", ")
    }

    func appendExample(_ example: String) {
        var tokens = DefaultAppsInputValidator.tokens(customInput)
        guard !tokens.contains(where: { $0.caseInsensitiveCompare(example) == .orderedSame }) else { return }
        tokens.append(example)
        customInput = tokens.joined(separator: ", ")
    }

    func isExampleAvailable(_ example: String) -> Bool {
        guard let target = DefaultAppTarget.parse(example), target.isResolvable else { return false }
        return !customTargets.contains(target)
    }

    func removeCustom(_ target: DefaultAppTarget) {
        customTargets.removeAll { $0 == target }
        saveCustomTargets()
        inputDidChange()
    }

    func menuIcon(for app: HandlerApp) -> NSImage? {
        menuIcons[app.id]
    }

    private func addTargets(from input: String) -> (added: [DefaultAppTarget], rejected: [DefaultAppInputCheck]) {
        let checks = DefaultAppsInputValidator.checks(for: input, existing: customTargets, categories: categories)
        var added: [DefaultAppTarget] = []
        var rejected: [DefaultAppInputCheck] = []
        for check in checks {
            if let target = check.target, check.canAdd, !customTargets.contains(target), !added.contains(target) {
                added.append(target)
            } else if !(check.target.map { added.contains($0) } ?? false) {
                rejected.append(check)
            }
        }
        guard !added.isEmpty else { return ([], rejected) }
        customTargets.append(contentsOf: added)
        saveCustomTargets()
        reload(added)
        return (added, rejected)
    }

    private func inputDidChange() {
        inputTask?.cancel()
        let checks = DefaultAppsInputValidator.checks(for: customInput, existing: customTargets, categories: categories)
        inputChecks = checks
        let targets = checks.compactMap { $0.canAdd ? $0.target : nil }
        let known = inputHandlers.filter { key, _ in targets.contains { $0.id == key } }
        if known.count != inputHandlers.count { inputHandlers = known }
        let missing = targets.filter { inputHandlers[$0.id] == nil }
        guard !missing.isEmpty else { return }
        let backend = backend
        inputTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
            let loaded = await DefaultAppsScanner.entries(for: missing, backend: backend)
            guard let self, !Task.isCancelled else { return }
            for (key, entry) in loaded {
                self.inputHandlers[key] = DefaultAppInputHandlers(current: entry.current, count: entry.candidates.count)
            }
            self.warmMenuIcons(loaded.values.compactMap(\.current))
        }
    }

    private func warmMenuIcons(_ extra: [HandlerApp] = []) {
        let pending = (extra + knownApps).filter { menuIcons[$0.id] == nil }
        guard !pending.isEmpty else { return }
        iconTask?.cancel()
        iconTask = Task { [weak self] in
            var batch: [String: NSImage] = [:]
            for app in pending {
                if Task.isCancelled { return }
                guard let self, self.menuIcons[app.id] == nil, batch[app.id] == nil else { continue }
                if let icon = AppIconCache.icon(for: app.bundleID, url: app.url)?.copy() as? NSImage {
                    icon.size = Self.menuIconSize
                    batch[app.id] = icon
                }
                if batch.count >= 12 {
                    self.menuIcons.merge(batch) { _, new in new }
                    batch.removeAll()
                }
                await Task.yield()
            }
            guard let self, !batch.isEmpty else { return }
            self.menuIcons.merge(batch) { _, new in new }
        }
    }

    private func apply(_ app: HandlerApp, to targets: [DefaultAppTarget], recordHistory: Bool) {
        let pending = targets.filter { !busyTargets.contains($0.id) }
        guard !pending.isEmpty else { return }
        let previous = pending.compactMap { target -> (target: DefaultAppTarget, app: HandlerApp)? in
            guard let current = entries[target.id]?.current, !current.matches(app) else { return nil }
            return (target, current)
        }
        busyTargets.formUnion(pending.map(\.id))
        message = nil
        let backend = backend
        let taskID = UUID()
        pendingTasks[taskID] = Task { [weak self] in
            var failures: [(DefaultAppTarget, Error)] = []
            for target in pending {
                do {
                    try await backend.setDefault(app.url, for: target)
                } catch {
                    failures.append((target, error))
                }
            }
            let refreshed = await DefaultAppsScanner.entries(for: pending, backend: backend)
            guard let self else { return }
            self.pendingTasks[taskID] = nil
            self.entries.merge(refreshed) { _, new in new }
            self.busyTargets.subtract(pending.map(\.id))
            let failedIDs = Set(failures.map { $0.0.id })
            let applied = previous.filter { !failedIDs.contains($0.target.id) && refreshed[$0.target.id]?.current?.matches(app) == true }
            if recordHistory, !applied.isEmpty {
                self.history.append(DefaultAppChange(app: app, previous: applied))
                if self.history.count > 20 { self.history.removeFirst(self.history.count - 20) }
            }
            self.message = Self.resultMessage(app: app, targets: pending, failures: failures, refreshed: refreshed)
            self.rebuildKnownApps()
        }
    }

    static func resultMessage(
        app: HandlerApp,
        targets: [DefaultAppTarget],
        failures: [(DefaultAppTarget, Error)],
        refreshed: [String: DefaultAppEntry]
    ) -> DefaultAppsMessage {
        if let failure = failures.first {
            let names = failures.map(\.0.title).joined(separator: ", ")
            return DefaultAppsMessage(text: "macOS didn't change \(names): \(failure.1.localizedDescription)", isError: true)
        }
        let unchanged = targets.filter { refreshed[$0.id]?.current?.matches(app) != true }
        if !unchanged.isEmpty {
            let names = unchanged.map(\.title).joined(separator: ", ")
            return DefaultAppsMessage(text: "\(names) still open in another app. macOS may have asked you to confirm the change.", isError: true)
        }
        if targets.count == 1, let target = targets.first {
            return DefaultAppsMessage(text: "\(app.name) now opens \(target.title).", isError: false)
        }
        return DefaultAppsMessage(text: "\(app.name) now opens \(targets.count) types.", isError: false)
    }

    private func reload(_ targets: [DefaultAppTarget]) {
        let backend = backend
        let taskID = UUID()
        pendingTasks[taskID] = Task { [weak self] in
            let loaded = await DefaultAppsScanner.entries(for: targets, backend: backend)
            guard let self else { return }
            self.pendingTasks[taskID] = nil
            self.entries.merge(loaded) { _, new in new }
            self.rebuildKnownApps()
        }
    }

    private func rebuildKnownApps() {
        var seen: [String: HandlerApp] = [:]
        for entry in entries.values {
            for app in entry.candidates + (entry.current.map { [$0] } ?? []) {
                let key = app.bundleID ?? app.id
                if seen[key] == nil { seen[key] = app }
            }
        }
        knownApps = seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        warmMenuIcons()
    }

    private func saveCustomTargets() {
        guard let data = try? JSONEncoder().encode(customTargets) else { return }
        defaults.set(data, forKey: QuitXConstants.UserDefaultsKeys.defaultAppsCustomTargets)
    }

    static func loadCustomTargets(from defaults: UserDefaults) -> [DefaultAppTarget] {
        guard let data = defaults.data(forKey: QuitXConstants.UserDefaultsKeys.defaultAppsCustomTargets),
              let decoded = try? JSONDecoder().decode([DefaultAppTarget].self, from: data) else {
            return []
        }
        var seen = Set<String>()
        return decoded.filter { !$0.isTooBroad && seen.insert($0.id).inserted }
    }
}
