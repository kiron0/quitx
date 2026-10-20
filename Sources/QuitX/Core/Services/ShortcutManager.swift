import AppKit
import Carbon

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    enum Slot {
        case activateMenu
        case quitAll
        case forceQuitAll
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

    @Published private(set) var shortcutError: String?
    @Published private(set) var registrationError: String?

    private var localMonitor: Any?
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

        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }

        guard activateMenuEnabled || quitAllEnabled || forceQuitAllEnabled else { return }

        var failures: [String] = []

        if activateMenuEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: activateMenuKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: QuitXConstants.HotKeys.signature, id: QuitXConstants.HotKeys.activateMenuId)
            let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            } else {
                failures.append("Activate menu (OSStatus \(status))")
            }
        }

        if quitAllEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: quitAllKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: QuitXConstants.HotKeys.signature, id: QuitXConstants.HotKeys.quitAllId)
            let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            } else {
                failures.append("Quit all (OSStatus \(status))")
            }
        }

        if forceQuitAllEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: forceQuitAllKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: QuitXConstants.HotKeys.signature, id: QuitXConstants.HotKeys.forceQuitAllId)
            let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            } else {
                failures.append("Force quit all (OSStatus \(status))")
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
        }
    }

    func isEnabled(_ slot: Slot) -> Bool {
        switch slot {
        case .activateMenu: return activateMenuEnabled
        case .quitAll: return quitAllEnabled
        case .forceQuitAll: return forceQuitAllEnabled
        }
    }

    func conflicts(keys: [String], excluding slot: Slot) -> Bool {
        guard !keys.isEmpty else { return false }
        let others: [Slot] = [.activateMenu, .quitAll, .forceQuitAll].filter { $0 != slot }
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
