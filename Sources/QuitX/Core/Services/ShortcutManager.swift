import AppKit
import Carbon

@MainActor
final class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()

    @Published var activateMenuEnabled: Bool {
        didSet { UserDefaults.standard.set(activateMenuEnabled, forKey: "sc_activate_enabled"); restartMonitoring() }
    }
    @Published var activateMenuKeys: [String] {
        didSet { UserDefaults.standard.set(activateMenuKeys, forKey: "sc_activate_keys"); restartMonitoring() }
    }

    @Published var quitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(quitAllEnabled, forKey: "sc_quit_enabled"); restartMonitoring() }
    }
    @Published var quitAllKeys: [String] {
        didSet { UserDefaults.standard.set(quitAllKeys, forKey: "sc_quit_keys"); restartMonitoring() }
    }

    @Published var forceQuitAllEnabled: Bool {
        didSet { UserDefaults.standard.set(forceQuitAllEnabled, forKey: "sc_force_enabled"); restartMonitoring() }
    }
    @Published var forceQuitAllKeys: [String] {
        didSet { UserDefaults.standard.set(forceQuitAllKeys, forKey: "sc_force_keys"); restartMonitoring() }
    }

    private var localMonitor: Any?
    private var registeredHotKeys: [EventHotKeyRef] = []
    private var carbonHandlerInstalled = false
    private var eventHandlerRef: EventHandlerRef?

    init() {
        self.activateMenuEnabled = UserDefaults.standard.object(forKey: "sc_activate_enabled") as? Bool ?? true
        self.activateMenuKeys = UserDefaults.standard.stringArray(forKey: "sc_activate_keys") ?? ["^", "⌥", "A"]

        self.quitAllEnabled = UserDefaults.standard.object(forKey: "sc_quit_enabled") as? Bool ?? false
        self.quitAllKeys = UserDefaults.standard.stringArray(forKey: "sc_quit_keys") ?? ["^", "⌥", "Q"]

        self.forceQuitAllEnabled = UserDefaults.standard.object(forKey: "sc_force_enabled") as? Bool ?? false
        self.forceQuitAllKeys = UserDefaults.standard.stringArray(forKey: "sc_force_keys") ?? ["^", "⌥", "⌘", "Q"]

        installCarbonHandlerIfNeeded()
        restartMonitoring()
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

        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }

        guard activateMenuEnabled || quitAllEnabled || forceQuitAllEnabled else { return }

        if activateMenuEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: activateMenuKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(1380993096), id: 1)
            if RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref) == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            }
        }

        if quitAllEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: quitAllKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(1380993096), id: 2)
            if RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref) == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            }
        }

        if forceQuitAllEnabled, let (keyCode, modifiers) = Self.keysToCarbon(keys: forceQuitAllKeys) {
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(1380993096), id: 3)
            if RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetEventDispatcherTarget(), 0, &ref) == noErr, let ref = ref {
                registeredHotKeys.append(ref)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    func handleHotKeyId(_ id: UInt32) {
        switch id {
        case 1:
            guard activateMenuEnabled else { return }
            StatusItemController.shared?.togglePopover()
        case 2:
            guard quitAllEnabled else { return }
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: false) }
        case 3:
            guard forceQuitAllEnabled else { return }
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: true) }
        default:
            break
        }
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent) -> Bool {
        let pressedKeys = Self.eventToKeys(event)
        guard !pressedKeys.isEmpty else { return false }

        if activateMenuEnabled && pressedKeys == activateMenuKeys {
            StatusItemController.shared?.togglePopover()
            return true
        }

        if quitAllEnabled && pressedKeys == quitAllKeys {
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: false) }
            return true
        }

        if forceQuitAllEnabled && pressedKeys == forceQuitAllKeys {
            Task { await AppListViewModel.shared.quitAllFromShortcut(force: true) }
            return true
        }

        return false
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
