import Cocoa
import SwiftUI
import Combine
import ServiceManagement
import CoreAudio
import Darwin

struct ModeChoice: Codable, Equatable {
    var width: Int; var height: Int; var pixels: Int; var hz: Int
    init(_ mode: CGDisplayMode) { width = mode.width; height = mode.height; pixels = mode.pixelWidth; hz = Int(mode.refreshRate.rounded()) }
    func matches(_ mode: CGDisplayMode) -> Bool { self == ModeChoice(mode) }
    var valid: Bool { (320...16384).contains(width) && (200...16384).contains(height) && (width...32768).contains(pixels) && (24...240).contains(hz) }
    var label: String { LF("%@ × %@%@ · %@ Hz",[String(width),String(height),pixels > width ? " HiDPI":"",String(hz)]) }
}
struct DeskScene: Identifiable, Codable, Equatable {
    var builtInName: String? = nil
    var localizedName: String { builtInName.map(L) ?? name }
    var id: UUID = UUID(); var name: String; var icon: String; var displayUUID: String; var mode: ModeChoice?; var brightness: Double; var volume: Double?; var favorite = true
    var valid: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 48 && icon.count <= 64 && UUID(uuidString:displayUUID) != nil && (mode?.valid ?? true) && brightness.isFinite && (0.2...1).contains(brightness) && (volume == nil || (volume!.isFinite && (0...100).contains(volume!))) }
}
struct SceneFile: Codable { var version = 1; var scenes: [DeskScene] }
enum DeskSection: String, CaseIterable, Identifiable {
    case overview = "My desk", display = "Display", color = "Color", sound = "Sound", remote = "Remote", scenes = "Scenes", labs = "Labs", settings = "Settings"
    var id: String { rawValue }
    var icon: String { switch self { case .overview: return "square.grid.2x2"; case .display: return "display"; case .color: return "circle.lefthalf.filled"; case .sound: return "speaker.wave.2"; case .remote: return "appletvremote.gen4"; case .scenes: return "square.stack.3d.up"; case .labs: return "flask"; case .settings: return "gearshape" } }
}
struct ActivityItem: Identifiable { let id = UUID(); let date = Date(); let text: String }
func scheduledPeriod(_ date: Date, start: Int, end: Int, calendar: Calendar = .current) -> Bool {
    let c = calendar.dateComponents([.hour,.minute], from: date); let minute = (c.hour ?? 0)*60 + (c.minute ?? 0)
    if start == end { return false }; return start < end ? minute >= start && minute < end : minute >= start || minute < end
}
@MainActor final class DeskModel: ObservableObject {
    let hardware: Hardware; let remote: SamsungRemote
    let colors = ColorProfiles(); let keyboard = DeskKeyboard()
    @Published var language = AppLanguage.current { didSet { AppLanguage.current = language } }
    @Published var section: DeskSection = .overview
    @Published var scenes: [DeskScene] = []
    @Published var activity: [ActivityItem] = []
    @Published var toast = ""
    @Published var linked = false
    @Published var activeScene: UUID?
    @Published var pendingScene: DeskScene?
    @Published var search = ""
    @Published var showOnboarding = !UserDefaults.standard.bool(forKey: "welcomeDismissed")
    @Published var followMac = false { didSet { configurePolling() } }
    @Published var scheduleEnabled = UserDefaults.standard.bool(forKey: "scheduleEnabled") { didSet { configurePolling() } }
    @Published var scheduleStart = UserDefaults.standard.object(forKey: "scheduleStart") == nil ? 22*60 : UserDefaults.standard.integer(forKey: "scheduleStart")
    @Published var scheduleEnd = UserDefaults.standard.object(forKey: "scheduleEnd") == nil ? 7*60 : UserDefaults.standard.integer(forKey: "scheduleEnd")
    @Published var scheduleLevel = UserDefaults.standard.double(forKey: "scheduleLevel") == 0 ? 0.55 : UserDefaults.standard.double(forKey: "scheduleLevel")
    @Published var autoPausedUntil: Date? { didSet { schedulePauseExpiry() } }
    @Published var loginEnabled = SMAppService.mainApp.status == .enabled
    @Published var rename = ""
    @Published var appearance = UserDefaults.standard.string(forKey: "appearance") ?? "System"
    @Published var compactLabels = UserDefaults.standard.bool(forKey: "compactLabels")
    var onOpenStudio: (() -> Void)?
    var onOSD: ((String, String, Double?) -> Void)?
    private var subscriptions = Set<AnyCancellable>()
    private var toastTask: Task<Void,Never>?
    private var scheduleTimer: Timer?
    private var pauseExpiryTask: Task<Void,Never>?
    private var followingBaseline: Double?
    private var followUUID = ""
    private var scheduleUUID = UserDefaults.standard.string(forKey:"scheduleUUID") ?? ""
    private var scheduledBaseline: Double?
    private var deletedScene: (Int, DeskScene)?
    private var previousSceneState: DeskScene?
    private var volumeTarget: Double?
    private var volumeWorker: Task<Void,Never>?
    private var lastRefresh = Date.distantPast
    private var identifying: [NSWindow] = []
    private var brightnessLibrary: UnsafeMutableRawPointer?
    typealias ReadBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private var readBrightness: ReadBrightness?
    init(hardware: Hardware, remote: SamsungRemote) {
        self.hardware = hardware; self.remote = remote
        for publisher in [hardware.objectWillChange.eraseToAnyPublisher(), remote.objectWillChange.eraseToAnyPublisher(), colors.objectWillChange.eraseToAnyPublisher(), keyboard.objectWillChange.eraseToAnyPublisher()] { publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions) }
        if let data = UserDefaults.standard.data(forKey: "deskScenes"), let stored = try? JSONDecoder().decode([DeskScene].self, from: data) { scenes = stored.filter(\.valid) }
        colors.refresh(hardware.selected)
        hardware.$selected.dropFirst().removeDuplicates().sink { [weak self] id in self?.colors.refresh(id) }.store(in: &subscriptions)
        keyboard.onCommand = { [weak self] command, fine in self?.handle(command, fine: fine) }
        keyboard.shouldHandle = { [weak self] command in
            guard let self else { return false }
            switch command { case .volumeUp,.volumeDown,.mute: return self.samsungIsOutput && self.remote.mediaAvailable
            case .brighter,.dimmer: return !self.followMac && self.hardware.current?.builtIn == false
            default: return false }
        }
        brightnessLibrary = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
        if let brightnessLibrary, let symbol = dlsym(brightnessLibrary, "DisplayServicesGetBrightness") { readBrightness = unsafeBitCast(symbol, to: ReadBrightness.self) }
        remote.isAudioActive = { [weak self] in self?.samsungIsOutput ?? false }
        configurePolling()
        if scenes.isEmpty { seedScenes() }
        if !UserDefaults.standard.bool(forKey:"localizedSceneMigration") {
            let originals = ["Everyday":"sun.max","Unwind":"moon.stars","Color work":"paintpalette"]
            for index in scenes.indices where originals[scenes[index].name] == scenes[index].icon { scenes[index].builtInName = scenes[index].name }
            persistScenes(); UserDefaults.standard.set(true,forKey:"localizedSceneMigration")
        }
    }
    var displayName: String { guard let d = hardware.current else { return "Your display" }; return UserDefaults.standard.string(forKey: "name.\(d.uuid)") ?? (isM8 ? "Samsung M8" : d.name) }
    var samsungIsOutput: Bool {
        let active = property(AudioObjectID(kAudioObjectSystemObject),kAudioHardwarePropertyDefaultOutputDevice,fallback:AudioDeviceID(0))
        return hardware.audio.first(where:{$0.id == active})?.name.uppercased().contains("SAMSUNG") == true
    }
    var isM8: Bool { hardware.current.map { CGDisplayVendorNumber($0.id) == 19501 && CGDisplayModelNumber($0.id) == 29287 } ?? false }
    var panelDescription:String { isM8 ? "4K panel · 60 Hz" : hardware.current?.builtIn == true ? "Built-in Retina display" : "Connected display" }
    var activeModes: [CGDisplayMode] {
        guard let display = hardware.current else { return [] }
        let aspect = display.mode.map { Double($0.width)/Double($0.height) } ?? 16/9
        return display.modes.filter { abs(Double($0.width)/Double($0.height)-aspect) < 0.02 && (!isM8 || ($0.refreshRate >= 59 && $0.refreshRate <= 61)) }
    }
    func mode(_ width: Int, hiDPI: Bool = true) -> CGDisplayMode? { activeModes.filter { $0.width == width && (hiDPI ? $0.pixelWidth > $0.width : $0.pixelWidth == $0.width) }.min { abs($0.refreshRate-(hardware.current?.mode?.refreshRate ?? 60)) < abs($1.refreshRate-(hardware.current?.mode?.refreshRate ?? 60)) } }
    func selectDisplay(_ id: CGDirectDisplayID) { hardware.select(id); colors.refresh(id); activeScene = nil; renamedFromDevice(); announce("Selected \(displayName)") }
    func renamedFromDevice() { rename = displayName }
    func renameDisplay() { guard let uuid = hardware.current?.uuid else { return }; let name = String(rename.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48)); UserDefaults.standard.set(name.isEmpty ? nil : name, forKey: "name.\(uuid)"); objectWillChange.send(); announce("Display name saved") }
    func setBrightness(_ value: Double, manual: Bool = true) {
        guard value.isFinite else { return }; if manual { autoPausedUntil = Date().addingTimeInterval(30*60); activeScene = nil }
        if linked { hardware.shadeAll(value) } else { hardware.shade(value) }
    }
    func handle(_ command: DeskCommand, fine: Bool = false) {
        switch command {
        case .volumeUp: changeVolume(fine ? 1 : 5)
        case .volumeDown: changeVolume(fine ? -1 : -5)
        case .mute: guard samsungIsOutput, remote.mediaAvailable else { announce("Choose Samsung as your sound output first"); return }; remote.toggleMute(); onOSD?("speaker.slash", "Mute", nil)
        case .brighter,.dimmer:
            let delta = (fine ? 0.01 : 0.05) * (command == .brighter ? 1 : -1)
            setBrightness(hardware.dim + delta); onOSD?("sun.max.fill", "Brightness", hardware.dim)
        case .restore: restore()
        case .openStudio: onOpenStudio?()
        }
    }
    func changeVolume(_ delta: Double) {
        guard samsungIsOutput, remote.mediaAvailable, let actual = remote.volume else { announce("Connect the monitor and select Samsung sound output"); return }
        volumeTarget = min(100, max(0, (volumeTarget ?? actual) + delta))
        onOSD?("speaker.wave.2.fill", "Volume", volumeTarget.map { $0/100 })
        startVolumeWorker()
    }
    private func startVolumeWorker() {
        guard volumeWorker == nil else { return }
        volumeWorker = Task {
            while let target = volumeTarget, remote.mediaAvailable, samsungIsOutput {
                while remote.changingVolume { try? await Task.sleep(for: .milliseconds(40)); if Task.isCancelled { break } }
                guard remote.mediaAvailable, samsungIsOutput else { break }
                if volumeTarget != target { continue }
                remote.setVolume(target)
                while remote.changingVolume { try? await Task.sleep(for: .milliseconds(40)); if Task.isCancelled { break } }
                if volumeTarget == target { volumeTarget = nil }
            }
            volumeTarget = nil; volumeWorker = nil
        }
    }
    func setVolume(_ value: Double) {
        guard value.isFinite, (0...100).contains(value), samsungIsOutput, remote.mediaAvailable else { return }
        volumeTarget = value.rounded()
        onOSD?("speaker.wave.2.fill","Volume",volumeTarget.map { $0/100 })
        startVolumeWorker()
    }
    var volumePending:Bool { volumeWorker != nil }

    func restore() { followMac = false; followingBaseline = nil; scheduledBaseline = nil; scheduleEnabled = false; UserDefaults.standard.set(false, forKey: "scheduleEnabled"); hardware.resetShades(); autoPausedUntil = nil; activeScene = nil; announce("All screens restored · experiments paused", icon: "sun.max.fill") }
    func announce(_ text: String, icon: String = "checkmark.circle.fill") {
        toastTask?.cancel(); toast = text; activity.insert(ActivityItem(text:text), at: 0); if activity.count > 40 { activity.removeLast(activity.count-40) }
        toastTask = Task { try? await Task.sleep(for: .seconds(4)); if !Task.isCancelled { toast = "" } }
    }
    func refresh() { hardware.refresh(); colors.refresh(hardware.selected); announce("Desk refreshed") }
    func applyMode(_ mode: CGDisplayMode) { hardware.applyMode(mode); activeScene = nil; announce("Previewing \(modeLabel(mode))") }
    func capture(name: String = "My scene") -> DeskScene { DeskScene(name:name,icon:"slider.horizontal.3",displayUUID:hardware.current?.uuid ?? "",mode:hardware.current?.mode.map(ModeChoice.init),brightness:hardware.dim,volume:samsungIsOutput ? remote.volume : nil) }
    func persistAppearance() { UserDefaults.standard.set(appearance,forKey:"appearance"); UserDefaults.standard.set(compactLabels,forKey:"compactLabels") }
    var visibleScenes:[DeskScene] {
        let query = search.trimmingCharacters(in:.whitespacesAndNewlines)
        return scenes.filter { scene in
            scene.displayUUID == hardware.current?.uuid && (query.isEmpty || scene.localizedName.localizedCaseInsensitiveContains(query) || scene.name.localizedCaseInsensitiveContains(query))
        }
    }
    func seedScenes() {
        guard let d = hardware.current else { return }
        let everyday = mode(2560).map(ModeChoice.init) ?? d.mode.map(ModeChoice.init)
        let clarity = mode(1920).map(ModeChoice.init) ?? d.mode.map(ModeChoice.init)
        scenes = [DeskScene(builtInName:"Everyday",name:"Everyday",icon:"sun.max",displayUUID:d.uuid,mode:everyday,brightness:1,volume:nil),DeskScene(builtInName:"Unwind",name:"Unwind",icon:"moon.stars",displayUUID:d.uuid,mode:everyday,brightness:0.55,volume:10),DeskScene(builtInName:"Color work",name:"Color work",icon:"paintpalette",displayUUID:d.uuid,mode:clarity,brightness:1,volume:nil)]
        persistScenes()
    }
    func persistScenes() { if let data = try? JSONEncoder().encode(scenes) { UserDefaults.standard.set(data, forKey:"deskScenes") } }
    func saveScene(_ name: String) { let scene = capture(name:String(name.prefix(48))); guard scene.valid else { announce("Give the scene a name"); return }; scenes.append(scene); persistScenes(); announce("Scene saved") }
    func sceneIsActive(_ scene:DeskScene)->Bool {
        guard activeScene == scene.id, scene.displayUUID == hardware.current?.uuid, hardware.rollbackSeconds == 0, abs(hardware.dim-scene.brightness)<0.001 else { return false }
        if let mode = scene.mode, mode != hardware.current?.mode.map(ModeChoice.init) { return false }
        if let volume = scene.volume {
            guard samsungIsOutput, remote.mediaAvailable, let actual = remote.volume, abs(actual-volume.rounded())<0.001 else { return false }
        }
        return true
    }
    func sceneIssue(_ scene:DeskScene)->String? {
        guard scene.valid, scene.displayUUID == hardware.current?.uuid else { return "Select the display this scene belongs to" }
        guard hardware.rollbackSeconds == 0 else { return "Keep or revert the current display preview first" }
        if let desired = scene.mode, desired != hardware.current?.mode.map(ModeChoice.init), !activeModes.contains(where:{desired.matches($0)}) { return "This scene’s saved display mode is unavailable. No settings were changed." }
        return nil
    }
    func applyScene(_ scene: DeskScene) {
        if let issue = sceneIssue(scene) { announce(issue); return }
        let previous = capture(name:"Previous setup")
        if let desired = scene.mode, desired != hardware.current?.mode.map(ModeChoice.init), let mode = activeModes.first(where:{desired.matches($0)}) {
            hardware.applyMode(mode)
            guard hardware.rollbackSeconds > 0 else { announce(hardware.notice); return }
        }
        previousSceneState = previous
        followMac = false; autoPausedUntil = Date().addingTimeInterval(30*60)
        // A scene belongs to one display even when manual brightness is linked.
        hardware.shade(scene.brightness)
        if let volume = scene.volume, samsungIsOutput, remote.mediaAvailable { setVolume(volume) }
        activeScene = scene.id; pendingScene = nil; announce("\(scene.localizedName) is ready")
    }
    func undoScene() {
        guard let previous = previousSceneState else { return }
        guard previous.displayUUID == hardware.current?.uuid else { announce("Select the original scene’s display before undoing"); return }
        if let desired = previous.mode, desired != hardware.current?.mode.map(ModeChoice.init), !activeModes.contains(where:{desired.matches($0)}) { announce("This scene’s saved display mode is unavailable. No settings were changed."); return }
        hardware.revertMode()
        if let desired = previous.mode, desired != hardware.current?.mode.map(ModeChoice.init) {
            guard let mode = activeModes.first(where:{desired.matches($0)}) else { announce("This scene’s saved display mode is unavailable. No settings were changed."); return }
            hardware.applyMode(mode)
            guard hardware.rollbackSeconds > 0 else { announce(hardware.notice); return }
        }
        hardware.shade(previous.brightness)
        autoPausedUntil = Date().addingTimeInterval(30*60)
        if let volume = previous.volume, samsungIsOutput, remote.mediaAvailable { setVolume(volume) }
        previousSceneState = nil; activeScene = nil; announce("Previous scene settings restored")
    }
    var canUndoScene: Bool { previousSceneState != nil }
    func favorite(_ scene: DeskScene) { if let i = scenes.firstIndex(where: { $0.id == scene.id }) { scenes[i].favorite.toggle(); persistScenes() } }
    func delete(_ scene: DeskScene) { if let i = scenes.firstIndex(where: { $0.id == scene.id }) { deletedScene = (i,scenes.remove(at:i)); persistScenes(); announce("Scene removed · Undo is available") } }
    var canRestoreDeleted: Bool { deletedScene != nil }
    func restoreDeleted() { if let (i,scene) = deletedScene { scenes.insert(scene,at:min(i,scenes.count)); deletedScene = nil; persistScenes(); announce("Scene restored") } }
    func duplicate(_ scene: DeskScene) { var copy = scene; copy.id = UUID(); copy.builtInName = nil; copy.name = String((scene.localizedName + L(" copy")).prefix(48)); scenes.append(copy); persistScenes(); announce("Scene duplicated") }
    func exportScenes() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "M8 Studio Scenes.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; try encoder.encode(SceneFile(scenes:scenes)).write(to:url,options:.atomic); announce("Scenes exported") } catch { announce("Export failed: \(error.localizedDescription)") }
    }
    func importScenes() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { let attrs = try FileManager.default.attributesOfItem(atPath:url.path); guard ((attrs[.size] as? NSNumber)?.intValue ?? Int.max) <= 1_000_000 else { announce("Scene file is too large"); return }; let file = try JSONDecoder().decode(SceneFile.self,from:Data(contentsOf:url)); guard file.version == 1, file.scenes.count <= 100, file.scenes.allSatisfy(\.valid) else { announce("Choose a valid M8 Studio scene file"); return }; for var scene in file.scenes { scene.id = UUID(); scenes.append(scene) }; persistScenes(); announce("Imported \(file.scenes.count) scenes") } catch { announce("Could not import scenes") }
    }
    func builtinBrightness() -> Double? { guard let readBrightness, let id = hardware.displays.first(where: \.builtIn)?.id else { return nil }; var value:Float = 0; return readBrightness(id,&value) == 0 && value.isFinite ? Double(value) : nil }
    func toggleFollow(_ enabled: Bool) { followMac = enabled; followUUID = hardware.current?.uuid ?? ""; followingBaseline = nil; autoPausedUntil = nil; if !enabled { announce("Mac brightness follow stopped") } }
    func saveSchedule() { scheduleUUID = hardware.current?.uuid ?? ""; UserDefaults.standard.set(scheduleUUID,forKey:"scheduleUUID"); UserDefaults.standard.set(scheduleEnabled,forKey:"scheduleEnabled"); UserDefaults.standard.set(scheduleStart,forKey:"scheduleStart"); UserDefaults.standard.set(scheduleEnd,forKey:"scheduleEnd"); UserDefaults.standard.set(scheduleLevel,forKey:"scheduleLevel"); autoPausedUntil = nil }
    private func schedulePauseExpiry() {
        pauseExpiryTask?.cancel(); pauseExpiryTask = nil
        guard let deadline = autoPausedUntil else { return }
        pauseExpiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self, self.autoPausedUntil == deadline else { return }
            self.autoPausedUntil = nil; self.tick()
        }
    }
    private func configurePolling() {
        scheduleTimer?.invalidate()
        let interval = deskPollingInterval(following: followMac, scheduled: scheduleEnabled)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
        timer.tolerance = interval == 1 ? 0.2 : min(5, interval/5)
        scheduleTimer = timer
    }
    private func tick() {
        if Date().timeIntervalSince(lastRefresh) >= 30 { hardware.refresh(); lastRefresh = Date() }
        if let pause = autoPausedUntil { if pause > Date() { return }; autoPausedUntil = nil }
        if followMac, let value = builtinBrightness(), let display = hardware.displays.first(where:{$0.uuid == followUUID && !$0.builtIn}) {
            if followingBaseline == nil { followingBaseline = hardware.brightness(for:display.id) }
            if abs(hardware.brightness(for:display.id)-max(0.2,value)) > 0.01 { hardware.shade(max(0.2,value),on:display.id) }; return
        }
        if scheduleEnabled, let display = hardware.displays.first(where:{$0.uuid == scheduleUUID}) {
            if scheduledPeriod(Date(),start:scheduleStart,end:scheduleEnd) {
                if scheduledBaseline == nil { scheduledBaseline = hardware.brightness(for:display.id) }
                if abs(hardware.brightness(for:display.id)-scheduleLevel) > 0.01 { hardware.shade(scheduleLevel,on:display.id) }
            } else if let previous = scheduledBaseline { hardware.shade(previous,on:display.id); scheduledBaseline = nil }
        }
    }
    func identify() {
        for w in identifying { w.close() }; identifying = []
        for (i,d) in hardware.displays.enumerated() { guard let screen = d.screen else { continue }; let w = NSWindow(contentRect: CGRect(x:screen.frame.midX-160,y:screen.frame.midY-90,width:320,height:180),styleMask:.borderless,backing:.buffered,defer:false); w.backgroundColor = .clear; w.isOpaque = false; w.ignoresMouseEvents = true; w.level = .screenSaver; w.isReleasedWhenClosed = false; w.contentView = NSHostingView(rootView: IdentifyView(number:i+1,name:d.name)); w.orderFrontRegardless(); identifying.append(w) }
        Task { try? await Task.sleep(for:.seconds(3)); for w in identifying { w.close() }; identifying = [] }
    }
    func toggleLogin() { Task { do { if SMAppService.mainApp.status == .enabled { try await SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }; loginEnabled = SMAppService.mainApp.status == .enabled; announce(loginEnabled ? "Open at login enabled" : "Open at login disabled") } catch { announce("Login setting needs attention in System Settings") } } }
    func dismissWelcome() { showOnboarding = false; UserDefaults.standard.set(true,forKey:"welcomeDismissed") }
}
