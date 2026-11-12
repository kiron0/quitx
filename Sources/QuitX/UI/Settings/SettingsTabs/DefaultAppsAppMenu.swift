import AppKit
import SwiftUI

enum DefaultAppsMenuEntry {
    case app(HandlerApp, title: String, isCurrent: Bool, action: @MainActor () -> Void)
    case action(title: String, symbol: String?, action: @MainActor () -> Void)
    case note(String)
    case separator
}

final class DefaultAppsMenuAction: NSObject {
    let handler: @MainActor () -> Void

    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
    }

    @objc func run(_ sender: Any?) {
        MainActor.assumeIsolated { handler() }
    }
}

@MainActor
enum DefaultAppsMenuBuilder {
    static func icon(for app: HandlerApp, model: DefaultAppsModel) -> NSImage? {
        if let cached = model.menuIcon(for: app) { return cached }
        guard let icon = AppIconCache.icon(for: app.bundleID, url: app.url)?.copy() as? NSImage else { return nil }
        icon.size = DefaultAppsModel.menuIconSize
        return icon
    }

    static func makeMenu(_ entries: [DefaultAppsMenuEntry], icon: (HandlerApp) -> NSImage?) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for entry in entries {
            switch entry {
            case .separator:
                if let last = menu.items.last, !last.isSeparatorItem { menu.addItem(.separator()) }
            case .note(let text):
                let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            case .app(let app, let title, let isCurrent, let action):
                let item = actionItem(title: title, action: action)
                if let image = icon(app) {
                    item.attributedTitle = titleWithIcon(title, icon: image)
                }
                item.state = isCurrent ? .on : .off
                item.toolTip = app.url.path
                menu.addItem(item)
            case .action(let title, _, let action):
                menu.addItem(actionItem(title: title, action: action))
            }
        }
        if let last = menu.items.last, last.isSeparatorItem { menu.removeItem(last) }
        return menu
    }

    static func titleWithIcon(_ title: String, icon: NSImage) -> NSAttributedString {
        let font = NSFont.menuFont(ofSize: 0)
        let size = DefaultAppsModel.menuIconSize
        let attachment = NSTextAttachment()
        attachment.image = icon
        attachment.bounds = NSRect(
            x: 0,
            y: (font.capHeight - size.height) / 2,
            width: size.width,
            height: size.height
        )
        let result = NSMutableAttributedString(attachment: attachment)
        result.append(NSAttributedString(string: "  \(title)", attributes: [.font: font]))
        return result
    }

    static func present(_ menu: NSMenu, from view: NSView) {
        menu.minimumWidth = view.bounds.width
        let point = view.isFlipped ? NSPoint(x: 0, y: view.bounds.height + 4) : NSPoint(x: 0, y: -4)
        menu.popUp(positioning: nil, at: point, in: view)
    }

    private static func actionItem(title: String, action: @escaping @MainActor () -> Void) -> NSMenuItem {
        let handler = DefaultAppsMenuAction(action)
        let item = NSMenuItem(title: title, action: #selector(DefaultAppsMenuAction.run(_:)), keyEquivalent: "")
        item.target = handler
        item.representedObject = handler
        item.isEnabled = true
        return item
    }
}

final class DefaultAppsMenuAnchor: ObservableObject {
    weak var view: NSView?
}

private struct DefaultAppsMenuAnchorView: NSViewRepresentable {
    let anchor: DefaultAppsMenuAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        anchor.view = nsView
    }
}

struct DefaultAppsMenuButton<Label: View>: View {
    @ObservedObject var model: DefaultAppsModel
    let entries: () -> [DefaultAppsMenuEntry]
    @ViewBuilder let label: () -> Label

    @StateObject private var anchor = DefaultAppsMenuAnchor()

    var body: some View {
        Button {
            guard let view = anchor.view else { return }
            let menu = DefaultAppsMenuBuilder.makeMenu(entries()) { app in
                DefaultAppsMenuBuilder.icon(for: app, model: model)
            }
            DefaultAppsMenuBuilder.present(menu, from: view)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .background(DefaultAppsMenuAnchorView(anchor: anchor))
    }
}
