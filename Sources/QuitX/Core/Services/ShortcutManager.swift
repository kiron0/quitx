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

    nonisolated static func stringToKeyCode(_ str: String) -> UInt32? {
        switch str.uppercased() {
        case "A": return 0
        case "S": return 1
        case "D": return 2
        case "F": return 3
        case "H": return 4
        case "G": return 5
        case "Z": return 6
        case "X": return 7
        case "C": return 8
        case "V": return 9
        case "B": return 11
        case "Q": return 12
        case "W": return 13
        case "E": return 14
        case "R": return 15
        case "Y": return 16
        case "T": return 17
        case "1": return 18
        case "2": return 19
        case "3": return 20
        case "4": return 21
        case "6": return 22
        case "5": return 23
        case "=": return 24
        case "9": return 25
        case "7": return 26
        case "-": return 27
        case "8": return 28
        case "0": return 29
        case "]": return 30
        case "O": return 31
        case "U": return 32
        case "[": return 33
        case "I": return 34
        case "P": return 35
        case "↩", "RETURN": return 36
        case "L": return 37
        case "J": return 38
        case "'": return 39
        case "K": return 40
        case ";": return 41
        case "\\": return 42
        case ",": return 43
        case "/": return 44
        case "N": return 45
        case "M": return 46
        case ".": return 47
        case "TAB": return 48
        case "SPACE": return 49
        case "`": return 50
        case "DELETE", "⌫": return 51
        case "ESCAPE", "⎋": return 53
        default: return nil
        }
    }

    nonisolated static func keyCodeToString(_ keyCode: UInt16) -> String? {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "↩"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        default: return nil
        }
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
