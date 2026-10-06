import SwiftUI
import AppKit

enum SettingsTab: String, CaseIterable {
    case general = "General"
    case advanced = "Advanced"
    case exclude = "Exclude"
    case shortcuts = "Shortcuts"
    case about = "About"

    var toolbarItemIdentifier: NSToolbarItem.Identifier {
        NSToolbarItem.Identifier(rawValue)
    }

    var iconName: String {
        switch self {
        case .general:   return "preferences-general"
        case .advanced:  return "preferences-advanced"
        case .exclude:   return "preferences-exclude"
        case .shortcuts: return "preferences-shortcuts"
        case .about:     return "preferences-about"
        }
    }

    var fallbackSymbolName: String {
        switch self {
        case .general:   return "gearshape"
        case .advanced:  return "slider.horizontal.3"
        case .exclude:   return "nosign"
        case .shortcuts: return "command"
        case .about:     return "bolt.fill"
        }
    }

    var toolbarImage: NSImage? {
        if let img = AssetImages.load(iconName) {
            let copy = img.copy() as? NSImage ?? img
            copy.size = NSSize(width: 19, height: 19)
            copy.isTemplate = true
            return copy
        }
        let sym = NSImage(systemSymbolName: fallbackSymbolName, accessibilityDescription: rawValue)
        let copy = sym?.copy() as? NSImage
        copy?.size = NSSize(width: 19, height: 19)
        copy?.isTemplate = true
        return copy ?? sym
    }

    var contentHeight: CGFloat {
        switch self {
        case .general:   return 421
        case .advanced:  return 271
        case .exclude:   return 306
        case .shortcuts: return 221
        case .about:     return 186
        }
    }
}

final class HelpPopoverState: ObservableObject {
    @Published var isShowing = false
    @Published var isHovered = false
}

struct HelpPopoverButton: View {
    let text: String
    @StateObject private var state = HelpPopoverState()

    var body: some View {
        Button {
            state.isShowing.toggle()
        } label: {
            let isActive = state.isShowing || state.isHovered
            Image(systemName: "questionmark.circle")
                .font(.system(size: 13, weight: isActive ? .medium : .regular))
                .foregroundStyle(isActive ? QuitXTheme.accent : Color.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { h in state.isHovered = h }
        .popover(isPresented: $state.isShowing, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.primary)
                .lineSpacing(2.5)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .frame(width: 230)
        }
    }
}

final class SettingsTabViewModel: ObservableObject {
    @Published var activeTab: SettingsTab = .general
}

struct SettingsContainerView: View {
    @ObservedObject var tabModel: SettingsTabViewModel
    @EnvironmentObject private var configStore: ConfigStore

    var body: some View {
        ZStack(alignment: .top) {
            switch tabModel.activeTab {
            case .general:
                GeneralTabCloneView()
                    .environmentObject(configStore)
            case .advanced:
                AdvancedTabCloneView()
                    .environmentObject(configStore)
            case .exclude:
                ExcludeTabView()
                    .environmentObject(configStore)
            case .shortcuts:
                ShortcutsTabCloneView()
            case .about:
                AboutTabCloneView()
            }
        }
        .frame(width: 400, height: tabModel.activeTab.contentHeight, alignment: .top)
        .background(QuitXTheme.windowBackground)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var configStore: ConfigStore
    @StateObject private var tabModel = SettingsTabViewModel()

    var body: some View {
        SettingsContainerView(tabModel: tabModel)
            .environmentObject(configStore)
    }
}
