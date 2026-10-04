import SwiftUI
import AppKit

enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil) -> NSImage? {
        let cacheKey = ((bundleId ?? (url?.path ?? (pid.map { "pid-\($0)" } ?? "unknown")))) as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        if bundleId == "com.apple.trash" {
            let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Trash")
            img?.isTemplate = true
            if let img = img { cache.setObject(img, forKey: cacheKey) }
            return img
        }
        if let url = url, FileManager.default.fileExists(atPath: url.path) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            cache.setObject(img, forKey: cacheKey)
            return img
        }
        if let pid = pid, let running = NSRunningApplication(processIdentifier: pid), let icon = running.icon {
            cache.setObject(icon, forKey: cacheKey)
            return icon
        }
        if let bid = bundleId {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path {
                let img = NSWorkspace.shared.icon(forFile: path)
                cache.setObject(img, forKey: cacheKey)
                return img
            }
            if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bid }),
               let icon = running.icon {
                cache.setObject(icon, forKey: cacheKey)
                return icon
            }
        }
        let fallback = NSWorkspace.shared.icon(for: .applicationBundle)
        cache.setObject(fallback, forKey: cacheKey)
        return fallback
    }

    @MainActor
    static func loadIcon(for bundleId: String?, pid: pid_t? = nil, url: URL? = nil, completion: @escaping @MainActor (NSImage?) -> Void) {
        if let existing = icon(for: bundleId, pid: pid, url: url) {
            completion(existing)
            return
        }
        let key = bundleId ?? url?.path ?? "fallback"
        let fileUrl = url ?? (bundleId.flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) })
        guard let path = fileUrl?.path else {
            let fallback = NSWorkspace.shared.icon(for: .applicationBundle)
            completion(fallback)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSWorkspace.shared.icon(forFile: path)
            DispatchQueue.main.async {
                cache.setObject(img, forKey: key as NSString)
                completion(img)
            }
        }
    }
}

@MainActor
final class AppIconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?, pid: pid_t? = nil, url: URL? = nil) {
        if let immediate = AppIconCache.icon(for: bundleId, pid: pid, url: url) {
            self.icon = immediate
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
            if let icon = loader.icon ?? AppIconCache.icon(for: bundleId, pid: pid, url: url) {
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
