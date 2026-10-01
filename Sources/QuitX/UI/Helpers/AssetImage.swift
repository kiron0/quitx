import SwiftUI
import AppKit

enum AssetImages {
    static func load(_ name: String) -> NSImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let localPath = "Support/Icons/\(name).png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            return img
        }
        return nil
    }

    static var appIcon: NSImage? {
        if let img = load("icon_128x128") ?? load("icon_256x256") ?? load("icon_512x512") {
            return img
        }
        if let bundleImage = Bundle.main.image(forResource: "AppIcon") {
            return bundleImage
        }
        let localPath = "Support/Icons/icon_128x128.png"
        if FileManager.default.fileExists(atPath: localPath),
           let img = NSImage(contentsOfFile: localPath) {
            return img
        }
        return NSApp.applicationIconImage
    }
}

struct QuitXAppIconView: View {
    var size: CGFloat = 70
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let image = AssetImages.appIcon {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(QuitXTheme.accent)
                    .frame(width: size, height: size)
            }
        }
    }
}
