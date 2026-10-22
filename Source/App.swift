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
        if let index = CommandLine.arguments.firstIndex(of:"--validate"), CommandLine.arguments.count > index+1 { Task { await runValidation(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return }
        if let index = CommandLine.arguments.firstIndex(of:"--validate-scenes"), CommandLine.arguments.count > index+1 { Task { await validateSceneRecovery(to:CommandLine.arguments[index+1]); NSApp.terminate(nil) }; return }
        if CommandLine.arguments.contains("--diagnose") { print(s.hardware.diagnostics()); fflush(stdout); NSApp.terminate(nil); return }
        s.model.onOpenStudio = { [weak self] in self?.showStudio() }
        s.model.onOSD = { [weak self] icon,title,level in self?.osd.show(icon:icon,title:title,level:level,screen:s.hardware.current?.screen) }
        statusController = DeskStatusController(model:s.model)
        if let index = CommandLine.arguments.firstIndex(of:"--validate-quick"), CommandLine.arguments.count > index+1, let controller = statusController {
            Task { await validateQuickUI(controller,model:s.model,directory:CommandLine.arguments[index+1]) }; return
        }
        let first = !UserDefaults.standard.bool(forKey:"launchedV2")
        if first || CommandLine.arguments.contains("--dashboard") { showStudio(); UserDefaults.standard.set(true,forKey:"launchedV2") }
        if CommandLine.arguments.contains("--quick") { DispatchQueue.main.async { [weak self] in self?.statusController?.showPopover() } }
        if CommandLine.arguments.contains("--pair") || UserDefaults.standard.bool(forKey:"paired.\(s.remote.host)") { s.remote.connect() }
    }
    func showStudio() {
        StudioState.shared.hardware.refresh(); StudioState.shared.model.keyboard.refreshPermission()
        statusController?.closePopover()
        if dashboard == nil { let w = NSWindow(contentRect:CGRect(x:100,y:80,width:1060,height:760),styleMask:[.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing:.buffered,defer:false); w.title = "M8 Studio"; w.titlebarAppearsTransparent = true; w.titleVisibility = .hidden; w.isReleasedWhenClosed = false; w.minSize = NSSize(width:1020,height:750); w.contentView = NSHostingView(rootView:StudioView(model:StudioState.shared.model)); w.center(); dashboard = w }
        dashboard?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true)
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool { showStudio(); return true }
    func applicationWillTerminate(_ notification:Notification) { StudioState.shared.hardware.revertMode(); StudioState.shared.hardware.resetShades(); StudioState.shared.remote.disconnect() }
}
@main struct M8StudioApp:App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body:some Scene { Settings { StudioView(model:StudioState.shared.model) } }
}
