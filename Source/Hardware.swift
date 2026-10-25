import Cocoa
import SwiftUI
import CoreAudio
import ServiceManagement

struct DisplayInfo: Identifiable {
    let id: CGDirectDisplayID
    let name: String
    let uuid: String
    let mode: CGDisplayMode?
    let screen: NSScreen?
    var builtIn: Bool { CGDisplayIsBuiltin(id) != 0 }
    var summary: String {
        guard let m = mode else { return "Mode unavailable" }
        return "\(m.pixelWidth) × \(m.pixelHeight)  ·  \(Int(m.refreshRate.rounded())) Hz"
    }
    var modes: [CGDisplayMode] {
        let all = CGDisplayCopyAllDisplayModes(id, [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary) as? [CGDisplayMode] ?? []
        var seen = Set<String>()
        return all.filter { $0.width >= 640 && $0.height >= 480 && seen.insert("\($0.width)x\($0.height):\($0.pixelWidth)x\($0.pixelHeight):\(Int(($0.refreshRate*1000).rounded()))").inserted }.sorted { $0.width == $1.width ? $0.refreshRate > $1.refreshRate : $0.width > $1.width }
    }
}
func modeLabel(_ m: CGDisplayMode) -> String {
    LF("%@ × %@%@ · %@ Hz",[String(m.width),String(m.height),m.pixelWidth > m.width ? " HiDPI":"",refreshLabel(m.refreshRate)])
}
struct AudioInfo: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let channels: Int
    let rate: Double
    let uid: String
    let manufacturer: String
    let transport: UInt32
    var isSamsungDisplay: Bool { !uid.isEmpty && samsungDisplayAudio(name:name,manufacturer:manufacturer,transport:transport) }
}
func audioString(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String {
    var address = AudioObjectPropertyAddress(mSelector:selector,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
    var value: Unmanaged<CFString>?
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id,&address,0,nil,&size,&value) == noErr else { return "" }
    return value?.takeRetainedValue() as String? ?? ""
}
func property<T>(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal, fallback: T) -> T {
    var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    var value = fallback
    var size = UInt32(MemoryLayout<T>.size)
    _ = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0) }
    return value
}
func audioDevices() -> [AudioInfo] {
    var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr else { return [] }
    var ids = [AudioDeviceID](repeating: 0, count: Int(size)/4)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids) == noErr else { return [] }
    return ids.compactMap { id in
        var cfg = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamConfiguration, mScope: kAudioDevicePropertyScopeOutput, mElement: 0)
        var n: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &cfg, 0, nil, &n) == noErr, n > 0 else { return nil }
        let p = UnsafeMutableRawPointer.allocate(byteCount: Int(n), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { p.deallocate() }
        guard AudioObjectGetPropertyData(id, &cfg, 0, nil, &n, p) == noErr else { return nil }
        let count = UnsafeMutableAudioBufferListPointer(p.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + Int($1.mNumberChannels) }
        guard count > 0 else { return nil }
        return AudioInfo(id:id,name:audioString(id,kAudioObjectPropertyName),channels:count,rate:property(id,kAudioDevicePropertyNominalSampleRate,fallback:Double(0)),uid:audioString(id,kAudioDevicePropertyDeviceUID),manufacturer:audioString(id,kAudioObjectPropertyManufacturer),transport:property(id,kAudioDevicePropertyTransportType,fallback:UInt32(0)))
    }
}
func runTool(_ path: String, _ args: [String], timeout: Double = 5) -> (Int32, String) {
    let p = Process(); p.executableURL = URL(fileURLWithPath: path); p.arguments = args
    let pipe = Pipe(); p.standardOutput = pipe; p.standardError = pipe
    do { try p.run() } catch { return (-1, error.localizedDescription) }
    let deadline = Date().addingTimeInterval(timeout)
    while p.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.025) }
    if p.isRunning { p.terminate(); return (-1, "Operation timed out") }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return (p.terminationStatus, String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
}

private struct DisplaySnapshot: Equatable {
    let id:CGDirectDisplayID; let name:String; let uuid:String; let mode:Int32?
    let frame:CGRect; let scale:CGFloat; let main:Bool
    init(_ display:DisplayInfo) {
        id = display.id; name = display.name; uuid = display.uuid; mode = display.mode?.ioDisplayModeID
        frame = display.screen?.frame ?? CGDisplayBounds(display.id)
        scale = display.screen?.backingScaleFactor ?? 1; main = CGMainDisplayID() == display.id
    }
}
@MainActor final class Hardware: ObservableObject {
    private var displayStorage:[DisplayInfo] = []
    private var displaySnapshots:[DisplaySnapshot] = []
    var displays:[DisplayInfo] { displayStorage }
    @Published private(set) var connectedUUIDs = Set<String>()
    @Published var selected: CGDirectDisplayID = 0
    @Published var audio: [AudioInfo] = []
    @Published var output: AudioDeviceID = 0
    @Published var ddc: [String: Double] = [:]
    @Published var ddcMax: [String: Double] = [:]
    @Published var probing = false
    @Published var notice = ""
    @Published var dim: Double = 1
    @Published var rollbackSeconds = 0
    private var oldMode: (CGDirectDisplayID, CGDisplayMode)?
    private var modeMarker: URL?
    private var timer: Timer?
    private var shades: [CGDirectDisplayID: NSWindow] = [:]
    private var shadeTargets: [CGDirectDisplayID: Double] = [:]
    private var audioListener: AudioObjectPropertyListenerBlock?
    private var pendingRefresh: Task<Void,Never>?
    @Published var changingDDC: Set<String> = []
    private var observers: [NSObjectProtocol] = []
    var current: DisplayInfo? { displays.first { $0.id == selected } }
    init() {
        refresh(); installAudioListeners()
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refresh() } })
    }
    private func installAudioListeners() {
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                self.pendingRefresh?.cancel()
                self.pendingRefresh = Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(100))
                    guard !Task.isCancelled else { return }; self?.refresh()
                }
            }
        }
        audioListener = listener
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main, listener)
        }
    }
    func refresh() {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32); var count: UInt32 = 0
        guard CGGetOnlineDisplayList(32, &ids, &count) == .success else { return }
        let freshDisplays = ids.prefix(Int(count)).map { id in
            let screen = NSScreen.screens.first { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id }
            let uuid = CGDisplayCreateUUIDFromDisplayID(id).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? String(id)
            return DisplayInfo(id: id, name: screen?.localizedName ?? "Display \(id)", uuid: uuid, mode: CGDisplayCopyDisplayMode(id), screen: screen)
        }
        let hadExternal = displayStorage.contains { !$0.builtIn }
        let snapshots = freshDisplays.map(DisplaySnapshot.init)
        if snapshots != displaySnapshots { objectWillChange.send(); displaySnapshots = snapshots }
        // Keep NSScreen references fresh even when observable values are unchanged.
        displayStorage = freshDisplays
        let freshUUIDs = Set(freshDisplays.map(\.uuid))
        if freshUUIDs != connectedUUIDs { connectedUUIDs = freshUUIDs }
        if !hadExternal, current?.builtIn != false, let attached = displays.first(where: { !$0.builtIn }) { selected = attached.id; ddc = [:]; ddcMax = [:] }
        if !displays.contains(where: { $0.id == selected }) { selected = displays.first(where: { !$0.builtIn })?.id ?? displays.first?.id ?? 0; ddc = [:] }
        for id in Array(shades.keys) where !displays.contains(where: { $0.id == id }) { shades.removeValue(forKey: id)?.close(); shadeTargets.removeValue(forKey:id) }
        for display in displays { if let frame = display.screen?.frame { shades[display.id]?.setFrame(frame, display: true) } }
        let freshAudio = audioDevices()
        if freshAudio != audio { audio = freshAudio }
        let freshOutput = property(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, fallback: AudioDeviceID(0))
        if freshOutput != output { output = freshOutput }
        let freshBrightness = shadeTargets[selected] ?? 1
        if dim != freshBrightness { dim = freshBrightness }
    }
    func select(_ id: CGDirectDisplayID) { selected = id; ddc = [:]; ddcMax = [:]; dim = shadeTargets[id] ?? 1; probe() }
    func probe() {
        guard let display = current, !display.builtIn, !probing else { return }
        probing = true; ddc = [:]; ddcMax = [:]
        let id = display.id
        let helper = Bundle.main.path(forResource: "m1ddc", ofType: nil) ?? ""
        Task {
            let results = await Task.detached { () -> [String: (Double, Double)] in
                var values: [String: (Double, Double)] = [:]
                for key in ["luminance", "contrast", "volume", "red", "green", "blue"] {
                    let (code, out) = runTool(helper, ["display", "id=\(id)", "get", key])
                    if code == 0, let value = Double(out) {
                        let (mc, mo) = runTool(helper, ["display", "id=\(id)", "max", key])
                        if mc == 0, let max = Double(mo), max > 0, value >= 0, value <= max { values[key] = (value, max) }
                    }
                }
                return values
            }.value
            if selected == id {
                ddc = results.mapValues { $0.0 }; ddcMax = results.mapValues { $0.1 }
                notice = results.isEmpty ? "The display did not answer DDC/CI. Use the Samsung remote for hardware settings." : "Hardware controls detected. Changes are verified after writing."
            }
            probing = false
            if selected != id { probe() }
        }
    }
    func setDDC(_ key: String, _ value: Double) {
        guard let d = current, !changingDDC.contains(key), ddc[key] != nil, let max = ddcMax[key], value.isFinite, value >= 0, value <= max else { return }
        changingDDC.insert(key)
        let helper = Bundle.main.path(forResource: "m1ddc", ofType: nil) ?? ""
        Task {
            let result = await Task.detached { () -> (Int32, String) in
                let w = runTool(helper, ["display", "id=\(d.id)", "set", key, String(Int(value))])
                guard w.0 == 0 else { return w }
                return runTool(helper, ["display", "id=\(d.id)", "get", key])
            }.value
            changingDDC.remove(key)
            guard selected == d.id else { return }
            if result.0 == 0, let actual = Double(result.1), actual.isFinite, actual >= 0, actual <= max { ddc[key] = actual; notice = "\(key.capitalized): hardware reports \(Int(actual))." }
            else { notice = "Could not verify \(key). Recheck the connection." }
        }
    }
    func shade(_ value:Double) { shade(value,on:selected) }
    func shade(_ value:Double,on id:CGDirectDisplayID) {
        guard value.isFinite, let screen = displays.first(where:{$0.id == id})?.screen else { return }
        let v = min(1,max(0.2,value)); shadeTargets[id] = v
        if selected == id { dim = v }
        if shades[id] == nil {
            let window = NSWindow(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false)
            window.backgroundColor = .black; window.isOpaque = false; window.ignoresMouseEvents = true
            window.level = NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.screenSaverWindow))-1)
            window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.stationary,.ignoresCycle]
            window.isReleasedWhenClosed = false; shades[id] = window
        }
        guard let window = shades[id] else { return }
        if v == 1 { window.alphaValue = 0; window.orderOut(nil); return }
        window.orderFrontRegardless()
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { window.alphaValue = 1-v }
        else { NSAnimationContext.runAnimationGroup { context in context.duration = 0.18; window.animator().alphaValue = 1-v } }
    }
    func brightness(for id: CGDirectDisplayID) -> Double { shadeTargets[id] ?? 1 }
    func shadeAll(_ value:Double) { for display in displays { shade(value,on:display.id) } }
    func resetShades() { for w in shades.values { w.close() }; shades = [:]; shadeTargets = [:]; dim = 1 }
    func applyMode(_ mode: CGDisplayMode) {
        guard oldMode == nil, let d = current, let old = d.mode else { return }
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent("M8Studio-mode-" + UUID().uuidString)
        guard let guardPath = Bundle.main.path(forResource: "ModeGuard", ofType: nil) else { notice = "Mode recovery helper is missing. Reinstall the app."; return }
        do {
            try Data(d.uuid.utf8).write(to: marker, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: marker.path)
            let guardProcess = Process(); guardProcess.executableURL = URL(fileURLWithPath: guardPath)
            guardProcess.arguments = [String(d.id), d.uuid, String(old.ioDisplayModeID), marker.path, "20"]
            try guardProcess.run(); modeMarker = marker
        } catch { try? FileManager.default.removeItem(at: marker); notice = "Could not start independent mode recovery. No change was made."; return }
        let error = CGDisplaySetDisplayMode(d.id, mode, nil)
        guard error == .success else { clearModeGuard(); notice = "macOS rejected this display mode (\(error.rawValue))."; return }
        oldMode = (d.id, old); rollbackSeconds = 15; refresh()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in
            guard let self else { return }; self.rollbackSeconds -= 1
            if self.rollbackSeconds <= 0 { self.revertMode() }
        } }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    private func clearModeGuard() { if let marker = modeMarker { try? FileManager.default.removeItem(at: marker) }; modeMarker = nil }
    func keepMode() { clearModeGuard(); timer?.invalidate(); timer = nil; oldMode = nil; rollbackSeconds = 0; notice = "Display mode kept." }
    func revertMode() {
        timer?.invalidate(); timer = nil
        if let (id, mode) = oldMode { let e = CGDisplaySetDisplayMode(id, mode, nil); notice = e == .success ? "Previous mode restored." : "Restore failed. Open Displays settings." }
        clearModeGuard(); oldMode = nil; rollbackSeconds = 0; refresh()
    }
    func setOutput(_ id: AudioDeviceID) {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: 0)
        var v = id
        let error = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, UInt32(MemoryLayout.size(ofValue: v)), &v)
        refresh(); notice = error == noErr ? "Audio output updated." : "macOS rejected the audio route (\(error))."
    }
    func setMain() {
        guard selected != 0 else { return }; var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success, let config else { return }
        let target = CGDisplayBounds(selected).origin
        for d in displays {
            let origin = CGDisplayBounds(d.id).origin
            let e = CGConfigureDisplayOrigin(config, d.id, Int32(origin.x-target.x), Int32(origin.y-target.y))
            if e != .success { CGCancelDisplayConfiguration(config); notice = "Could not arrange displays."; return }
        }
        let result = CGCompleteDisplayConfiguration(config, .forSession)
        notice = result == .success ? "Main display updated for this session." : "Main display change failed."; refresh()
    }
    func diagnostics() -> String {
        var lines = ["M8 Studio shareable diagnostics", "Date: \(ISO8601DateFormatter().string(from:Date()))", "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)", "Device names, profile names/paths and persistent identities are omitted."]
        for (index,d) in displays.enumerated() {
            lines.append("Display \(index+1) [\(d.builtIn ? "built-in":"external")]: vendor \(CGDisplayVendorNumber(d.id)), model \(CGDisplayModelNumber(d.id)); \(d.summary); UI \(d.mode.map(modeLabel) ?? "unknown"); EDR headroom \(d.screen?.maximumPotentialExtendedDynamicRangeColorComponentValue ?? 1)")
        }
        for (index,a) in audio.enumerated() { lines.append("Audio output \(index+1): \(a.channels) channels, \(Int(a.rate)) Hz; transport \(a.transport); Samsung display route \(a.isSamsungDisplay)\(a.id == output ? " [selected]":"")") }
        lines.append("DDC confirmed controls: \(ddc.keys.sorted().joined(separator:", "))")
        return lines.joined(separator:"\n")
    }
}
