import Cocoa
import Carbon
import ApplicationServices

// Independent implementation informed by MIT-licensed MediaKeyTap's documented event format.
enum DeskCommand: UInt32, CaseIterable {
    case volumeUp = 1, volumeDown, mute, brighter, dimmer, restore, openStudio
    var shortcut: String {
        switch self { case .volumeUp: return "⌃⌥⌘↑"; case .volumeDown: return "⌃⌥⌘↓"; case .mute: return "⌃⌥⌘M"; case .brighter: return "⌃⌥⌘→"; case .dimmer: return "⌃⌥⌘←"; case .restore: return "⌃⌥⌘0"; case .openStudio: return "⌃⌥⌘Space" }
    }
}
func mediaCommand(_ data: Int) -> (DeskCommand, Bool)? {
    let key = (data >> 16) & 0xffff
    let phase = (data >> 8) & 0xff
    guard phase == 0x0a || phase == 0x0b else { return nil }
    let command: DeskCommand?
    switch key { case 0: command = .volumeUp; case 1: command = .volumeDown; case 7: command = .mute; case 2: command = .brighter; case 3: command = .dimmer; default: command = nil }
    return command.map { ($0, phase == 0x0a) }
}
// Apple keyboards can deliver dedicated brightness keys as ordinary key events.
// F14/F15 are also used by external Apple keyboards. F1/F2 remain app-owned function keys.
func brightnessCommand(keyCode: Int) -> DeskCommand? {
    switch keyCode { case 144, 113: return .brighter; case 145, 107: return .dimmer; default: return nil }
}
struct MediaKeyOwnership {
    private var keys: Set<Int> = []
    mutating func handle(identity: Int, command: DeskCommand, pressed: Bool, allowed: Bool) -> (consume: Bool, deliver: Bool) {
        if !pressed { return (keys.remove(identity) != nil, false) }
        guard allowed else { return (false, false) }
        let first = keys.insert(identity).inserted
        return (true, command != .mute || first)
    }
    mutating func reset() { keys.removeAll() }
}
@MainActor final class DeskKeyboard: ObservableObject {
    @Published var mediaEnabled = UserDefaults.standard.bool(forKey: "mediaKeys")
    @Published var mediaActive = false
    @Published var shortcutStatus = ""
    @Published private(set) var mediaStatus = "Media keys are disabled"
    @Published private(set) var lastInput = ""
    @Published private(set) var lastMediaInput = ""
    private var activationObserver: NSObjectProtocol?
    private var ownership = MediaKeyOwnership()
    var onCommand: ((DeskCommand, Bool) -> Void)?
    var shouldHandle: ((DeskCommand) -> Bool)?
    private var hotkeys: [EventHotKeyRef] = []
    private var handler: EventHandlerRef?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var permissionTimer: Timer?
    init() {
        registerShortcuts(); refreshPermission(); updatePermissionTimer()
        activationObserver = NotificationCenter.default.addObserver(forName:NSApplication.didBecomeActiveNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.refreshPermission() } }
    }
    private func updatePermissionTimer() {
        permissionTimer?.invalidate(); permissionTimer = nil
        guard mediaEnabled else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in Task { @MainActor in self?.refreshPermission() } }
        timer.tolerance = 5; permissionTimer = timer
    }
    private func deliver(_ command: DeskCommand, fine: Bool) {
        lastInput = command.shortcut
        onCommand?(command, fine)
    }
    func registerShortcuts() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID(); GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == 0x4d385354, let command = DeskCommand(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<DeskKeyboard>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { controller.deliver(command, fine: false) }
            return noErr
        }
        let result = InstallEventHandler(GetEventDispatcherTarget(), callback, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { shortcutStatus = "Could not register keyboard shortcuts."; return }
        let keys: [(DeskCommand, Int)] = [(.volumeUp,kVK_UpArrow),(.volumeDown,kVK_DownArrow),(.mute,kVK_ANSI_M),(.brighter,kVK_RightArrow),(.dimmer,kVK_LeftArrow),(.restore,kVK_ANSI_0),(.openStudio,kVK_Space)]
        for (command, key) in keys {
            var reference: EventHotKeyRef?
            let error = RegisterEventHotKey(UInt32(key), UInt32(controlKey|optionKey|cmdKey), EventHotKeyID(signature: 0x4d385354, id: command.rawValue), GetEventDispatcherTarget(), 0, &reference)
            if error == noErr, let reference { hotkeys.append(reference) }
        }
        shortcutStatus = hotkeys.count == keys.count ? "Global shortcuts ready" : "\(hotkeys.count) of \(keys.count) shortcuts registered; another app may use a shortcut."
    }
    func enableMedia() {
        mediaEnabled = true; UserDefaults.standard.set(true, forKey: "mediaKeys")
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options); refreshPermission(); updatePermissionTimer()
        if !mediaActive { openSettings("com.apple.preference.security?Privacy_Accessibility") }
    }
    func disableMedia() { mediaEnabled = false; UserDefaults.standard.set(false, forKey: "mediaKeys"); stopTap(); mediaStatus = "Media keys are disabled"; updatePermissionTimer() }
    func refreshPermission() {
        guard mediaEnabled else { return }
        if let tap, !CFMachPortIsValid(tap) { stopTap() }
        if let tap { if !CGEvent.tapIsEnabled(tap:tap) { CGEvent.tapEnable(tap:tap,enable:true) }; return }
        let callback: CGEventTapCallBack = { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<DeskKeyboard>.fromOpaque(context).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                MainActor.assumeIsolated { if let tap = controller.tap { controller.ownership.reset(); CGEvent.tapEnable(tap: tap, enable: true) } }
                return Unmanaged.passUnretained(event)
            }
            guard let ns = NSEvent(cgEvent: event) else { return Unmanaged.passUnretained(event) }
            let decoded: (DeskCommand, Bool)?
            let identity: Int
            if type.rawValue == 14, ns.subtype.rawValue == 8 {
                decoded = mediaCommand(ns.data1); identity = (ns.data1 >> 16) & 0xffff
            } else if type == .keyDown || type == .keyUp {
                decoded = brightnessCommand(keyCode: Int(ns.keyCode)).map { ($0, type == .keyDown) }
                identity = 0x10000 + Int(ns.keyCode)
            } else { return Unmanaged.passUnretained(event) }
            guard let (command, pressed) = decoded else { return Unmanaged.passUnretained(event) }
            return MainActor.assumeIsolated {
                if pressed && controller.lastMediaInput != command.shortcut { controller.lastMediaInput = command.shortcut }
                let allowed = ns.modifierFlags.intersection([.command, .control]).isEmpty && controller.shouldHandle?(command) == true
                let decision = controller.ownership.handle(identity: identity, command: command, pressed: pressed, allowed: allowed)
                if decision.deliver { controller.deliver(command, fine: ns.modifierFlags.contains(.option)) }
                return decision.consume ? nil : Unmanaged.passUnretained(event)
            }
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: (CGEventMask(1) << 14) | (CGEventMask(1) << CGEventType.keyDown.rawValue) | (CGEventMask(1) << CGEventType.keyUp.rawValue), callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap, let source = CFMachPortCreateRunLoopSource(nil, tap, 0) { self.source = source; CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes); CGEvent.tapEnable(tap: tap, enable: true); mediaActive = true; mediaStatus = "Media keys are active" }
        else {
            stopTap()
            mediaStatus = AXIsProcessTrusted() ? "macOS refused the media-key connection. Quit and reopen Studio after granting access.":"macOS has not granted this installed build access. Remove the old M8 Studio permission entry and add /Applications/M8 Studio.app again."
        }
    }
    private func stopTap() { if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }; if let tap { CFMachPortInvalidate(tap) }; source = nil; tap = nil; if mediaActive { mediaActive = false }; ownership.reset() }
}
