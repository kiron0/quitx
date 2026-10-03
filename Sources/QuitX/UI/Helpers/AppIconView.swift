import SwiftUI
import AppKit

enum AppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for bundleId: String?) -> NSImage? {
        guard let bid = bundleId else { return nil }
        if let cached = cache.object(forKey: bid as NSString) {
            return cached
        }
        if bid == "com.apple.trash" {
            let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Trash")
            img?.isTemplate = true
            if let img = img { cache.setObject(img, forKey: bid as NSString) }
            return img
        }
        if bid == "com.apple.finder" {
            if let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path {
                let img = NSWorkspace.shared.icon(forFile: path)
                cache.setObject(img, forKey: bid as NSString)
                return img
            }
        }
        return nil
    }

    @MainActor
    static func loadIcon(for bundleId: String?, completion: @escaping @MainActor (NSImage?) -> Void) {
        guard let bid = bundleId else {
            completion(nil)
            return
        }
        if let existing = icon(for: bid) {
            completion(existing)
            return
        }
        guard let path = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid)?.path else {
            completion(nil)
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let img = NSWorkspace.shared.icon(forFile: path)
            cache.setObject(img, forKey: bid as NSString)
            DispatchQueue.main.async {
                completion(img)
            }
        }
    }
}

@MainActor
final class AppIconLoader: ObservableObject {
    @Published var icon: NSImage?

    func load(bundleId: String?) {
        if let immediate = AppIconCache.icon(for: bundleId) {
            self.icon = immediate
            return
        }
        AppIconCache.loadIcon(for: bundleId) { [weak self] loaded in
            self?.icon = loaded
        }
    }
}

struct AppIconView: View {
    let bundleId: String?
    var size: CGFloat = 18
    var cornerRadius: CGFloat = 3

    @StateObject private var loader = AppIconLoader()

    var body: some View {
        Group {
            if let icon = loader.icon ?? AppIconCache.icon(for: bundleId) {
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
                loader.load(bundleId: bundleId)
            }
        }
        .onChange(of: bundleId) { _, newId in
            loader.load(bundleId: newId)
        }
    }
}
