import AppKit
import Carbon

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    enum Slot: CaseIterable {
        case activateMenu
        case quitAll
        case forceQuitAll
        case openSettings
        case refreshApps
        case openHelp
        case openChangelog
        case openUninstaller

        var title: String {
            switch self {
            case .activateMenu: return "Open QuitX"
            case .quitAll: return "Quit selected apps"
            case .forceQuitAll: return "Force quit selected apps"
            case .openSettings: return "Open Settings"
            case .refreshApps: return "Refresh app list"
            case .openHelp: return "Open Help"
            case .openChangelog: return "Open What's New"
            case .openUninstaller: return "Open Uninstall Apps"
            }
        }

        var hotKeyId: UInt32 {
            switch self {
            case .activateMenu: return QuitXConstants.HotKeys.activateMenuId
            case .quitAll: return QuitXConstants.HotKeys.quitAllId
            case .forceQuitAll: return QuitXConstants.HotKeys.forceQuitAllId
            case .openSettings: return QuitXConstants.HotKeys.openSettingsId
            case .refreshApps: return QuitXConstants.HotKeys.refreshAppsId
            case .openHelp: return QuitXConstants.HotKeys.openHelpId
            case .openChangelog: return QuitXConstants.HotKeys.openChangelogId
            case .openUninstaller: return QuitXConstants.HotKeys.openUninstallerId
            }
        }
    }

    private var restartWorkItem: DispatchWorkItem?

    func scheduleRestartMonitoring() {
        restartWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.restartMonitoring()
        }
        restartWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
    }

    @Published var activateMenuEnabled: Bool {
        didSet { UserDefaults.standard.set(activateMenuEnabled, forKey: QuitXConstants.UserDefaultsKeys.activateMenuEnabled); scheduleRestartMonitoring() }
    }
    @Published var activateMenuKeys: [String] {
        didSet { UserDefaults.standard.set(activateMenuKeys, forKey: QuitXConstants.UserDefaultsKeys.activateMenuKeys); scheduleRestartMonitoring() }
    }

    @Published var quitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(quitAllEnabled, forKey: QuitXConstants.UserDefaultsKeys.quitAllEnabled); scheduleRestartMonitoring() }
    }
    @Published var quitAllKeys: [String] {
        didSet { UserDefaults.standard.set(quitAllKeys, forKey: QuitXConstants.UserDefaultsKeys.quitAllKeys); scheduleRestartMonitoring() }
    }

    @Published var forceQuitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(forceQuitAllEnabled, forKey: QuitXConstants.UserDefaultsKeys.forceQuitAllEnabled); scheduleRestartMonitoring() }
    }
    @Published var forceQuitAllKeys: [String] {
        didSet { UserDefaults.standard.set(forceQuitAllKeys, forKey: QuitXConstants.UserDefaultsKeys.forceQuitAllKeys); scheduleRestartMonitoring() }
    }

    @Published var openSettingsEnabled: Bool {
        didSet { UserDefaults.standard.set(openSettingsEnabled, forKey: QuitXConstants.UserDefaultsKeys.openSettingsEnabled); scheduleRestartMonitoring() }
    }
    @Published var openSettingsKeys: [String] {
        didSet { UserDefaults.standard.set(openSettingsKeys, forKey: QuitXConstants.UserDefaultsKeys.openSettingsKeys); scheduleRestartMonitoring() }
    }
    @Published var refreshAppsEnabled: Bool {
        didSet { UserDefaults.standard.set(refreshAppsEnabled, forKey: QuitXConstants.UserDefaultsKeys.refreshAppsEnabled); scheduleRestartMonitoring() }
    }
    @Published var refreshAppsKeys: [String] {
        didSet { UserDefaults.standard.set(refreshAppsKeys, forKey: QuitXConstants.UserDefaultsKeys.refreshAppsKeys); scheduleRestartMonitoring() }
    }
    @Published var openHelpEnabled: Bool {
        didSet { UserDefaults.standard.set(openHelpEnabled, forKey: QuitXConstants.UserDefaultsKeys.openHelpEnabled); scheduleRestartMonitoring() }
    }
    @Published var openHelpKeys: [String] {
        didSet { UserDefaults.standard.set(openHelpKeys, forKey: QuitXConstants.UserDefaultsKeys.openHelpKeys); scheduleRestartMonitoring() }
    }
    @Published var openChangelogEnabled: Bool {
        didSet { UserDefaults.standard.set(openChangelogEnabled, forKey: QuitXConstants.UserDefaultsKeys.openChangelogEnabled); scheduleRestartMonitoring() }
    }
    @Published var openChangelogKeys: [String] {
        didSet { UserDefaults.standard.set(openChangelogKeys, forKey: QuitXConstants.UserDefaultsKeys.openChangelogKeys); scheduleRestartMonitoring() }
    }
    @Published var openUninstallerEnabled: Bool {
        didSet { UserDefaults.standard.set(openUninstallerEnabled, forKey: QuitXConstants.UserDefaultsKeys.openUninstallerEnabled); scheduleRestartMonitoring() }
    }
    @Published var openUninstallerKeys: [String] {
        didSet { UserDefaults.standard.set(openUninstallerKeys, forKey: QuitXConstants.UserDefaultsKeys.openUninstallerKeys); scheduleRestartMonitoring() }
    }

    @Published private(set) var shortcutError: String?
    @Published private(set) var registrationError: String?

    private var registeredHotKeys: [EventHotKeyRef] = []
    private var carbonHandlerInstalled = false
    private var eventHandlerRef: EventHandlerRef?

    init() {
        self.activateMenuEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.activateMenuEnabled) as? Bool ?? Self.defaultActivateMenuEnabled
        self.activateMenuKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.activateMenuKeys) ?? Self.defaultActivateMenuKeys

        self.quitAllEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.quitAllEnabled) as? Bool ?? Self.defaultQuitAllEnabled
        self.quitAllKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.quitAllKeys) ?? Self.defaultQuitAllKeys

        self.forceQuitAllEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.forceQuitAllEnabled) as? Bool ?? Self.defaultForceQuitAllEnabled
        self.forceQuitAllKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.forceQuitAllKeys) ?? Self.defaultForceQuitAllKeys
        self.openSettingsEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.openSettingsEnabled) as? Bool ?? false
        self.openSettingsKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.openSettingsKeys) ?? []
        self.refreshAppsEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.refreshAppsEnabled) as? Bool ?? false
        self.refreshAppsKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.refreshAppsKeys) ?? []
        self.openHelpEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.openHelpEnabled) as? Bool ?? false
        self.openHelpKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.openHelpKeys) ?? []
        self.openChangelogEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.openChangelogEnabled) as? Bool ?? false
        self.openChangelogKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.openChangelogKeys) ?? []
        self.openUninstallerEnabled = UserDefaults.standard.object(forKey: QuitXConstants.UserDefaultsKeys.openUninstallerEnabled) as? Bool ?? false
        self.openUninstallerKeys = UserDefaults.standard.stringArray(forKey: QuitXConstants.UserDefaultsKeys.openUninstallerKeys) ?? []

        installCarbonHandlerIfNeeded()
        restartMonitoring()
    }

    static let defaultActivateMenuEnabled = true
    static let defaultActivateMenuKeys: [String] = ["^", "⌥", "A"]
    static let defaultQuitAllEnabled = false
    static let defaultQuitAllKeys: [String] = ["^", "⌥", "Q"]
    static let defaultForceQuitAllEnabled = false
    static let defaultForceQuitAllKeys: [String] = ["^", "⌥", "⌘", "Q"]

    func resetToDefaults() {
        activateMenuEnabled = Self.defaultActivateMenuEnabled
        activateMenuKeys = Self.defaultActivateMenuKeys
        quitAllEnabled = Self.defaultQuitAllEnabled
        quitAllKeys = Self.defaultQuitAllKeys
        forceQuitAllEnabled = Self.defaultForceQuitAllEnabled
        forceQuitAllKeys = Self.defaultForceQuitAllKeys
        openSettingsEnabled = false
        openSettingsKeys = []
        refreshAppsEnabled = false
        refreshAppsKeys = []
        openHelpEnabled = false
        openHelpKeys = []
        openChangelogEnabled = false
        openChangelogKeys = []
        openUninstallerEnabled = false
        openUninstallerKeys = []
        shortcutError = nil
    }

    private func installCarbonHandlerIfNeeded() {
        guard !carbonHandlerInstalled else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if err == noErr {
                    Task { @MainActor in
                        ShortcutManager.shared.handleHotKeyId(hotKeyID.id)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
        if status == noErr {
            carbonHandlerInstalled = true
        }
    }

    func restartMonitoring() {
        for ref in registeredHotKeys {
            UnregisterEventHotKey(ref)
        }
        registeredHotKeys.removeAll()
        registrationError = nil

        guard Slot.allCases.contains(where: isEnabled) else { return }

        var failures: [String] = []

        for slot in Slot.allCases where isEnabled(slot) {
            guard let (keyCode, modifiers) = Self.keysToCarbon(keys: keys(for: slot)) else { continue }
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: QuitXConstants.HotKeys.signature, id: slot.hotKeyId)
            let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            } else {
                failures.append("\(slot.title) (OSStatus \(status))")
            }
        }

        registrationError = failures.isEmpty
            ? nil
            : "Could not register shortcut:\n" + failures.joined(separator: "\n")
    }

    func keys(for slot: Slot) -> [String] {
        switch slot {
        case .activateMenu: return activateMenuKeys
        case .quitAll: return quitAllKeys
        case .forceQuitAll: return forceQuitAllKeys
        case .openSettings: return openSettingsKeys
        case .refreshApps: return refreshAppsKeys
        case .openHelp: return openHelpKeys
        case .openChangelog: return openChangelogKeys
        case .openUninstaller: return openUninstallerKeys
        }
    }

    func isEnabled(_ slot: Slot) -> Bool {
        switch slot {
        case .activateMenu: return activateMenuEnabled
        case .quitAll: return quitAllEnabled
        case .forceQuitAll: return forceQuitAllEnabled
        case .openSettings: return openSettingsEnabled
        case .refreshApps: return refreshAppsEnabled
        case .openHelp: return openHelpEnabled
        case .openChangelog: return openChangelogEnabled
        case .openUninstaller: return openUninstallerEnabled
        }
    }

    func conflicts(keys: [String], excluding slot: Slot) -> Bool {
        guard !keys.isEmpty else { return false }
        let others = Slot.allCases.filter { $0 != slot }
        return others.contains { other in
            isEnabled(other) && self.keys(for: other) == keys
        }
    }

    @discardableResult
    func setKeys(_ newKeys: [String], for slot: Slot) -> Bool {
        guard conflicts(keys: newKeys, excluding: slot) else {
            shortcutError = nil
            switch slot {
            case .activateMenu: activateMenuKeys = newKeys
            case .quitAll: quitAllKeys = newKeys
            case .forceQuitAll: forceQuitAllKeys = newKeys
            case .openSettings: openSettingsKeys = newKeys
            case .refreshApps: refreshAppsKeys = newKeys
            case .openHelp: openHelpKeys = newKeys
            case .openChangelog: openChangelogKeys = newKeys
            case .openUninstaller: openUninstallerKeys = newKeys
            }
            return true
        }
        shortcutError = "This shortcut is already assigned to another action."
        return false
    }

    func handleHotKeyId(_ id: UInt32) {
        switch id {
        case QuitXConstants.HotKeys.activateMenuId:
            guard activateMenuEnabled else { return }
            StatusItemController.shared?.togglePopover()
        case QuitXConstants.HotKeys.quitAllId:
            guard quitAllEnabled else { return }
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: false) }
        case QuitXConstants.HotKeys.forceQuitAllId:
            guard forceQuitAllEnabled else { return }
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: true) }
        case QuitXConstants.HotKeys.openSettingsId:
            guard openSettingsEnabled else { return }
            SettingsWindowController.shared.show()
        case QuitXConstants.HotKeys.refreshAppsId:
            guard refreshAppsEnabled else { return }
            Task { await AppListViewModel.shared.refresh(force: true) }
        case QuitXConstants.HotKeys.openHelpId:
            guard openHelpEnabled else { return }
            HelpWindowController.shared.show()
        case QuitXConstants.HotKeys.openChangelogId:
            guard openChangelogEnabled else { return }
            ChangelogWindowController.shared.show()
        case QuitXConstants.HotKeys.openUninstallerId:
            guard openUninstallerEnabled else { return }
            UninstallWindowController.shared.showPicker()
        default:
            break
        }
    }

    nonisolated static func keysToCarbon(keys: [String]) -> (keyCode: UInt32, modifiers: UInt32)? {
        var modifiers: UInt32 = 0
        var keyChar: String?

        for k in keys {
            switch k {
            case "^": modifiers |= UInt32(controlKey)
            case "⌥": modifiers |= UInt32(optionKey)
            case "⇧": modifiers |= UInt32(shiftKey)
            case "⌘": modifiers |= UInt32(cmdKey)
            default: keyChar = k
            }
        }

        guard let char = keyChar, let keyCode = stringToKeyCode(char) else {
            return nil
        }

        return (keyCode, modifiers)
    }

    private nonisolated static let primaryKeyMap: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space", 50: "`"
    ]

    private nonisolated static let stringAliases: [String: UInt32] = [
        "RETURN": 36, "DELETE": 51, "⌫": 51, "ESCAPE": 53, "⎋": 53
    ]

    private nonisolated static let stringToKeyMap: [String: UInt32] = {
        var map: [String: UInt32] = [:]
        for (code, str) in primaryKeyMap {
            map[str.uppercased()] = UInt32(code)
        }
        for (alias, code) in stringAliases {
            map[alias] = code
        }
        return map
    }()

    nonisolated static func stringToKeyCode(_ str: String) -> UInt32? {
        stringToKeyMap[str.uppercased()]
    }

    nonisolated static func keyCodeToString(_ keyCode: UInt16) -> String? {
        primaryKeyMap[keyCode]
    }

    nonisolated static func eventToKeys(_ event: NSEvent) -> [String] {
        var keys: [String] = []
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { keys.append("^") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }

        if let mapped = keyCodeToString(event.keyCode) {
            keys.append(mapped)
        } else if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
            let scalar = chars.unicodeScalars.first?.value ?? 0
            if scalar >= 32 && scalar < 127 {
                keys.append(chars)
            } else if scalar >= 1 && scalar <= 26 {
                keys.append(String(UnicodeScalar(scalar + 64)!))
            }
        }
        return keys
    }
}
