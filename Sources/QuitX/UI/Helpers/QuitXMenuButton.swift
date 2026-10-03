import SwiftUI
import AppKit
import CoreGraphics

private enum MenuButtonImageCache {
    private static var cache: [String: (normal: NSImage, hovered: NSImage)] = [:]
    private static let lock = NSLock()

    static func images(
        assetName: String?,
        selectedAssetName: String?,
        systemSymbolName: String?,
        symbolPointSize: CGFloat,
        symbolWeight: NSFont.Weight,
        size: NSSize
    ) -> (normal: NSImage, hovered: NSImage) {
        let key = "\(assetName ?? "")|\(selectedAssetName ?? "")|\(systemSymbolName ?? "")|\(symbolPointSize)|\(symbolWeight.rawValue)|\(size.width)x\(size.height)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[key] {
            return cached
        }

        var normalSource: NSImage?
        var hoveredSource: NSImage?

        if let selected = selectedAssetName, let loaded = AssetImages.load(selected) {
            hoveredSource = loaded
        }

        if let asset = assetName, let loaded = AssetImages.load(asset) {
            normalSource = loaded
            if hoveredSource == nil {
                hoveredSource = loaded
            }
        } else if let symbol = systemSymbolName,
                  let sym = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: symbolWeight)
            let configured = sym.withSymbolConfiguration(config) ?? sym
            normalSource = configured
            hoveredSource = configured
        }

        let baseNormal = normalSource ?? NSImage(size: size)
        let baseHovered = hoveredSource ?? baseNormal

        // Normalize alpha on hovered image so it glows with full 100% saturation and opacity, matching the quit icon
        let normalizedHovered = normalizeAlpha(baseHovered)

        // Tint directly into non-template images so AppKit does not apply vibrancy / dark-mode dimming
        let normal = tint(image: baseNormal, with: NSColor.secondaryLabelColor, size: size)
        let hovered = tint(image: normalizedHovered, with: QuitXTheme.accentNSColor, size: size)

        let result = (normal, hovered)
        cache[key] = result
        return result
    }

    private static func normalizeAlpha(_ image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = 4 * width
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var maxAlpha: UInt8 = 0
        for i in stride(from: 3, to: rawData.count, by: 4) {
            if rawData[i] > maxAlpha { maxAlpha = rawData[i] }
        }

        if maxAlpha > 0 && maxAlpha < 240 {
            let factor = 255.0 / Double(maxAlpha)
            for i in stride(from: 0, to: rawData.count, by: 4) {
                let a = Double(rawData[i + 3])
                if a > 0 {
                    let newA = min(255, UInt8(round(a * factor)))
                    let r = min(255, UInt8(round(Double(rawData[i]) * factor)))
                    let g = min(255, UInt8(round(Double(rawData[i + 1]) * factor)))
                    let b = min(255, UInt8(round(Double(rawData[i + 2]) * factor)))
                    rawData[i] = r
                    rawData[i + 1] = g
                    rawData[i + 2] = b
                    rawData[i + 3] = newA
                }
            }
        }

        guard let newCgImage = context.makeImage() else { return image }
        return NSImage(cgImage: newCgImage, size: image.size)
    }

    private static func tint(image: NSImage, with color: NSColor, size: NSSize) -> NSImage {
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1.0)
        color.set()
        rect.fill(using: .sourceIn)
        tinted.unlockFocus()
        tinted.isTemplate = false
        return tinted
    }
}

private struct MenuAnchorRepresentable: NSViewRepresentable {
    let onView: (NSView) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        onView(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        onView(nsView)
    }
}

final class MenuButtonState: ObservableObject {
    @Published var isHovered = false
    @Published var isMenuOpen = false
    var anchorView: NSView?
    var imagePair: (normal: NSImage, hovered: NSImage)?
}

struct QuitXMenuButton: View {
    var assetName: String? = nil
    var selectedAssetName: String? = nil
    var systemSymbolName: String? = nil
    var symbolPointSize: CGFloat = 12
    var symbolWeight: NSFont.Weight = .regular
    var size: NSSize = NSSize(width: 14, height: 14)
    var toolTip: String? = "Options"
    var isEnabled: Bool = true
    var menu: () -> NSMenu

    @StateObject private var state = MenuButtonState()

    var body: some View {
        Button {
            state.isMenuOpen = true
            showMenu()
        } label: {
            iconImage
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(toolTip ?? "")
        .onHover { h in
            state.isHovered = h
        }
        .background(MenuAnchorRepresentable { view in
            self.state.anchorView = view
        })
    }

    private var iconImage: some View {
        let isActive = state.isHovered || state.isMenuOpen
        let pair = state.imagePair ?? {
            let images = MenuButtonImageCache.images(
                assetName: assetName,
                selectedAssetName: selectedAssetName,
                systemSymbolName: systemSymbolName,
                symbolPointSize: symbolPointSize,
                symbolWeight: symbolWeight,
                size: size
            )
            state.imagePair = images
            return images
        }()
        return Image(nsImage: isActive ? pair.hovered : pair.normal)
    }

    private func showMenu() {
        guard let anchor = state.anchorView else {
            state.isMenuOpen = false
            return
        }
        let nsMenu = menu()
        nsMenu.popUp(positioning: nil, at: NSPoint(x: anchor.bounds.maxX, y: anchor.bounds.minY), in: anchor)
        state.isMenuOpen = false
        if let window = anchor.window {
            let mouseInWindow = window.mouseLocationOutsideOfEventStream
            let mouseInView = anchor.convert(mouseInWindow, from: nil)
            state.isHovered = anchor.bounds.contains(mouseInView)
        } else {
            state.isHovered = false
        }
    }
}
