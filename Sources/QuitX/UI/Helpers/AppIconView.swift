import SwiftUI
import AppKit

enum AppIconCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 150
        return c
    }()

    nonisolated private static func cacheKey(bundleId: String?, pid: pid_t?, url: URL?) -> String {
        if let bundleId, !bundleId.isEmpty {
            return bundleId
        }
        if let url {
            return url.path
        }
        if let pid {
            return "pid-\(pid)"
        }
        return "fallback"
    }

    nonisolated static func cachedIcon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil) -> NSImage? {
        cache.object(forKey: cacheKey(bundleId: bundleId, pid: pid, url: url) as NSString)
    }

    nonisolated static func icon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil) -> NSImage? {
        let key = cacheKey(bundleId: bundleId, pid: pid, url: url) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        return resolveAndCache(bundleId: bundleId, pid: pid, url: url, key: key)
    }

    nonisolated private static func resolveAndCache(bundleId: String?, pid: pid_t?, url: URL?, key: NSString) -> NSImage {
        if let existing = cache.object(forKey: key) {
            return existing
        }
        let resolved: NSImage
        if bundleId == "com.apple.trash" {
            let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Trash")
            img?.isTemplate = true
            resolved = img ?? NSWorkspace.shared.icon(for: .applicationBundle)
        } else if let url, FileManager.default.fileExists(atPath: url.path) {
            resolved = NSWorkspace.shared.icon(forFile: url.path)
        } else if let pid, let running = NSRunningApplication(processIdentifier: pid), let icon = running.icon {
            resolved = icon
        } else if let bid = bundleId {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path {
                resolved = NSWorkspace.shared.icon(forFile: path)
            } else if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }),
                      let icon = running.icon {
                resolved = icon
            } else {
                resolved = NSWorkspace.shared.icon(for: .applicationBundle)
            }
        } else {
            resolved = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        cache.setObject(resolved, forKey: key)
        return resolved
    }

    nonisolated static func loadIcon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil, completion: @escaping @MainActor (NSImage?) -> Void) {
        if let existing = cachedIcon(for: bundleId, pid: pid, url: url) {
            Task { @MainActor in
                completion(existing)
            }
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = icon(for: bundleId, pid: pid, url: url)
            DispatchQueue.main.async {
                completion(img)
            }
        }
    }
}

@MainActor
final class AppIconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?, pid: pid_t? = nil, url: URL? = nil) {
        if let cached = AppIconCache.cachedIcon(for: bundleId, pid: pid, url: url) {
            self.icon = cached
            return
        }
        AppIconCache.loadIcon(for: bundleId, pid: pid, url: url) { [weak self] loaded in
            self?.icon = loaded
        }
    }
}

struct AppIconView: View {
    let bundleId: String?
    var pid: pid_t? = nil
    var url: URL? = nil
    var size: CGFloat = 18
    var cornerRadius: CGFloat = 3

    @StateObject private var loader = AppIconLoader()

    var body: some View {
        Group {
            if let icon = loader.icon ?? AppIconCache.cachedIcon(for: bundleId, pid: pid, url: url) {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .cornerRadius(cornerRadius)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: size, height: size)
            }
        }
        .onAppear {
            if loader.icon == nil {
                loader.load(bundleId: bundleId, pid: pid, url: url)
            }
        }
        .onChange(of: bundleId) { _, newId in
            loader.load(bundleId: newId, pid: pid, url: url)
        }
        .onChange(of: pid) { _, newPid in
            loader.load(bundleId: bundleId, pid: newPid, url: url)
        }
        .onChange(of: url) { _, newUrl in
            loader.load(bundleId: bundleId, pid: pid, url: newUrl)
        }
    }
}
