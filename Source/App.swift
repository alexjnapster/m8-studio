import SwiftUI
import AppKit

@MainActor final class StudioState {
    static let shared = StudioState()
    let hardware: Hardware
    let remote: SamsungRemote
    let model: DeskModel
    private init() { hardware = Hardware(); remote = SamsungRemote(); model = DeskModel(hardware:hardware,remote:remote) }
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    var dashboard:NSWindow?
    var statusController:DeskStatusController?
    var desktopController:DesktopCardController?
    private var pendingRoute: StudioRoute?
    private var routeTask: Task<Void, Never>?
    let osd = DeskOSD()
    func applicationDidFinishLaunching(_ notification:Notification) {
        UserDefaults.standard.register(defaults:["AppleLanguages":[AppLanguage.current,AppLanguage.current == "uk" ? "en":"uk"]])
        NSApp.setActivationPolicy(.accessory)
        if !CommandLine.arguments.contains(where: { $0.hasPrefix("--validate") || $0 == "--diagnose" }),
           let identifier = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: []); exit(0)
        }
        let s = StudioState.shared
        #if M8_UI_PREVIEW
        // A distinct bundle/preferences domain; no startup connection or input tap.
        precondition(["local.M8Studio.Preview","local.M8Studio.CanvasTest","local.M8Studio.HardwareTest"].contains(Bundle.main.bundleIdentifier ?? ""))
        s.model.onOpenStudio = { [weak self] in self?.showStudio() }
        desktopController = DesktopCardController(model:s.model)
        s.model.onToggleDesktopCard = { [weak self] in self?.desktopController?.toggle() }
        if let index = CommandLine.arguments.firstIndex(of:"--validate-desktop"), CommandLine.arguments.count > index+1, let controller = desktopController {
            Task { await controller.validate(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return
        }
        statusController = DeskStatusController(model:s.model)
        statusController?.item.length = 44
        statusController?.item.button?.image = nil
        statusController?.item.button?.title = "M8P"
        statusController?.item.button?.setAccessibilityLabel("M8 Studio Preview Controls")
        s.model.section = .setup
        showStudio()
        dashboard?.title = Bundle.main.bundleIdentifier == "local.M8Studio.HardwareTest" ? "M8 Studio — Hardware Test":"M8 Studio — Interaction Preview"
        openPendingRoute()
        return
        #endif
        if let index = CommandLine.arguments.firstIndex(of:"--validate-setup"), CommandLine.arguments.count > index+1 {
            Task { await validateSetup(model:s.model,to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return
        }
        if let index = CommandLine.arguments.firstIndex(of:"--validate"), CommandLine.arguments.count > index+1 { Task { await runValidation(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return }
        if let index = CommandLine.arguments.firstIndex(of:"--validate-scenes"), CommandLine.arguments.count > index+1 { Task { await validateSceneRecovery(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return }
        if CommandLine.arguments.contains("--diagnose") { print(s.hardware.diagnostics()); fflush(stdout); NSApp.terminate(nil); return }
        if let index = CommandLine.arguments.firstIndex(of:"--validate-quality"), CommandLine.arguments.count > index+1 {
            Task { await validateQuality(model:s.model,to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return
        }
        s.model.onOpenStudio = { [weak self] in self?.showStudio() }
        s.model.onOSD = { [weak self] icon,title,level in self?.osd.show(icon:icon,title:title,level:level,screen:s.hardware.current?.screen) }
        desktopController = DesktopCardController(model:s.model)
        s.model.onToggleDesktopCard = { [weak self] in self?.desktopController?.toggle() }
        if let index = CommandLine.arguments.firstIndex(of:"--validate-desktop"), CommandLine.arguments.count > index+1, let controller = desktopController {
            Task { await controller.validate(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return
        }
        statusController = DeskStatusController(model:s.model)
        if let index = CommandLine.arguments.firstIndex(of:"--validate-quick"), CommandLine.arguments.count > index+1, let controller = statusController {
            Task { await validateQuickUI(controller,model:s.model,directory:CommandLine.arguments[index+1]) }; return
        }
        if UserDefaults.standard.bool(forKey:"desktopCard.visible") { desktopController?.show() }
        let first = !UserDefaults.standard.bool(forKey:"launchedV2")
        if first { s.model.section = .setup }
        if CommandLine.arguments.contains("--setup") { s.model.section = .setup }
        if first || CommandLine.arguments.contains("--dashboard") || CommandLine.arguments.contains("--setup") { showStudio(); UserDefaults.standard.set(true,forKey:"launchedV2") }
        if CommandLine.arguments.contains("--quick") { DispatchQueue.main.async { [weak self] in self?.statusController?.showPopover() } }
        if CommandLine.arguments.contains("--pair") { s.remote.connect() }
        else if UserDefaults.standard.bool(forKey:"monitorMediaOnly") { s.remote.connect(remoteControl:false) }
        else if UserDefaults.standard.bool(forKey:"paired.\(s.remote.host)") { s.remote.connect() }
        openPendingRoute()
    }
    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.count == 1, let route = StudioRoute(url: urls[0]) else { return }
        pendingRoute = route
        if statusController != nil { openPendingRoute() }
    }
    private func openPendingRoute() {
        guard let route = pendingRoute else { return }; pendingRoute = nil
        routeTask?.cancel()
        routeTask = Task { [weak self] in
            guard let self else { return }
            if route == .quick {
                // Cold launch may deliver the URL before the status item attaches.
                for _ in 0..<20 {
                    guard !Task.isCancelled else { return }
                    if self.statusController?.item.button?.window != nil {
                        self.statusController?.showPopover(); return
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
            guard !Task.isCancelled else { return }
            self.openStudioRoute(route)
        }
    }
    private func openStudioRoute(_ route: StudioRoute) {
        let section: DeskSection
        switch route {
        case .display: section = .display
        case .color: section = .color
        case .sound: section = .sound
        case .scenes: section = .scenes
        case .settings: section = .settings
        case .setup: section = .setup
        case .quick: section = .overview // bounded cold-start fallback
        }
        StudioState.shared.model.section = section; showStudio()
    }
    @objc private func previewQuickControls() { statusController?.showPopover() }
    func showStudio() {
        StudioState.shared.hardware.refresh(); StudioState.shared.model.keyboard.refreshPermission()
        statusController?.closePopover()
        if dashboard == nil { let w = NSWindow(contentRect:CGRect(x:100,y:80,width:1060,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false); w.title = "M8 Studio"; w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isReleasedWhenClosed = false; w.minSize = NSSize(width:1020,height:750); w.contentView = NSHostingView(rootView:StudioView(model:StudioState.shared.model)); w.center(); dashboard = w }
        dashboard?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { showStudio(); return true }
    func applicationWillTerminate(_ notification:Notification) { StudioState.shared.model.virtualCanvas.shutdown(); StudioState.shared.model.sound.shutdown(); StudioState.shared.hardware.revertMode(); StudioState.shared.hardware.resetShades(); StudioState.shared.remote.disconnect() }
}
@main struct M8StudioApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body:some Scene {
        Settings { StudioView(model:StudioState.shared.model) }
            .commands { StudioCommands(model:StudioState.shared.model,showQuick:{delegate.statusController?.showPopover()}) }
    }
}

struct StudioCommands:Commands {
    @ObservedObject var model:DeskModel
    var showQuick:()->Void
    var body:some Commands {
        CommandMenu("Studio") {
            Button(L("Quick controls"),action:showQuick).keyboardShortcut("k",modifiers:[.command,.option])
            Button(L("Open Studio")) { model.onOpenStudio?() }
            Divider()
            Button(L("Return to physical display")) { model.virtualCanvas.stop() }
                .disabled(!model.virtualCanvas.engaged)
            Button(L("Bypass EQ")) { model.sound.stop() }.disabled(!model.sound.canBypass)
        }
    }
}
