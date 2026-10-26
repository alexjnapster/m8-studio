import SwiftUI
import AppKit

// A live app-owned desktop card. This is not a WidgetKit extension: it shares
// the existing model and needs neither a second service nor timeline polling.
@MainActor private final class DesktopCardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor final class DesktopCardController: NSObject, NSWindowDelegate {
    let model: DeskModel
    private var panel: NSPanel?
    private var presenting = false
    private var pinned = UserDefaults.standard.bool(forKey:"desktopCard.pinned")
    init(model: DeskModel) { self.model = model }
    func toggle() {
        if panel?.isVisible == true && (pinned || presenting) { hide() }
        else { show(foreground:true) }
    }
    func show(foreground:Bool = false) {
        if panel == nil {
            let window = DesktopCardPanel(contentRect:CGRect(x:100,y:120,width:330,height:430),styleMask:[.titled,.closable,.utilityWindow,.fullSizeContentView,.nonactivatingPanel],backing:.buffered,defer:false)
            window.title = L("Desktop controls"); window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false; window.isMovableByWindowBackground = true
            window.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            window.setFrameAutosaveName("M8StudioDesktopCard")
            _ = window.setFrameUsingName("M8StudioDesktopCard")
            if !NSScreen.screens.contains(where:{ $0.visibleFrame.intersection(window.frame).width >= 80 && $0.visibleFrame.intersection(window.frame).height >= 80 }) {
                window.center()
            }
            window.delegate = self
            window.contentView = NSHostingView(rootView:DesktopControlCard(model:model,onHide:{ [weak self] in self?.hide() },onPin:{ [weak self] value in self?.setPinned(value) },pinned:pinned))
            panel = window
        }
        panel?.title = L("Desktop controls")
        presenting = foreground
        updateLevel()
        if foreground { NSApp.activate(); panel?.makeKeyAndOrderFront(nil) }
        else { panel?.orderFrontRegardless() }
        UserDefaults.standard.set(true,forKey:"desktopCard.visible")
    }
    func hide() { presenting = false; panel?.orderOut(nil); updateLevel(); UserDefaults.standard.set(false,forKey:"desktopCard.visible") }
    func windowShouldClose(_ sender:NSWindow)->Bool { hide(); return false }
    func windowDidResignKey(_ notification:Notification) { presenting = false; updateLevel() }
    private func setPinned(_ value:Bool) { presenting = false; pinned = value; UserDefaults.standard.set(value,forKey:"desktopCard.pinned"); updateLevel() }
    private func updateLevel() { panel?.level = (pinned || presenting) ? .floating:NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+1) }
    func validate(to directory:String) async {
        let folder = URL(fileURLWithPath:directory,isDirectory:true)
        try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let oldLanguage = model.language; let oldAppearance = model.appearance
        let oldVisible = UserDefaults.standard.object(forKey:"desktopCard.visible")
        let oldPinned = UserDefaults.standard.object(forKey:"desktopCard.pinned")
        defer {
            hide(); model.language = oldLanguage; model.appearance = oldAppearance
            for (key,value) in [("desktopCard.visible",oldVisible),("desktopCard.pinned",oldPinned)] {
                if let value { UserDefaults.standard.set(value,forKey:key) } else { UserDefaults.standard.removeObject(forKey:key) }
            }
        }
        var lines = ["Desktop card native layout and window lifecycle. No audio playback or display mutation requested."]
        for (language,appearance) in [("uk","Light"),("uk","Dark"),("en","Light"),("en","Dark")] {
            model.language = language; model.appearance = appearance; show()
            try? await Task.sleep(for:.milliseconds(250))
            guard let view = panel?.contentView else { lines.append("FAIL missing desktop hosting view"); continue }
            view.layoutSubtreeIfNeeded()
            let size = view.fittingSize
            lines.append("\(size.width >= 329 && size.width <= 331 && size.height > 200 && size.height < 650 ? "PASS":"FAIL") \(language) \(appearance) desktop layout \(Int(size.width))×\(Int(size.height))")
            view.setFrameSize(size)
            if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                if let png = bitmap.representation(using:.png,properties:[:]) { try? png.write(to:folder.appendingPathComponent("Desktop-\(language)-\(appearance).png")) }
            }
        }
        setPinned(true); lines.append(panel?.level == .floating ? "PASS pin above windows":"FAIL pin above windows")
        setPinned(false); lines.append(panel?.level.rawValue == Int(CGWindowLevelForKey(.desktopIconWindow))+1 ? "PASS desktop level":"FAIL desktop level")
        show(foreground:true)
        lines.append(panel?.level == .floating && !pinned ? "PASS explicit opening is visible without changing pin preference":"FAIL foreground presentation")
        windowDidResignKey(Notification(name:NSWindow.didResignKeyNotification))
        lines.append(panel?.level.rawValue == Int(CGWindowLevelForKey(.desktopIconWindow))+1 ? "PASS unpinned card returns to desktop after focus leaves":"FAIL presentation recovery")
        hide(); lines.append(panel?.isVisible == false ? "PASS hide":"FAIL hide")
        show(); lines.append(panel?.isVisible == true ? "PASS reopen":"FAIL reopen")
        try? lines.joined(separator:"\n").write(to:folder.appendingPathComponent("Desktop-UI.txt"),atomically:true,encoding:.utf8)
        print(lines.joined(separator:"\n")); fflush(stdout)
    }
}

struct DesktopControlCard: View {
    @ObservedObject var model: DeskModel
    @ObservedObject private var hardware: Hardware
    @ObservedObject private var remote: SamsungRemote
    let onHide: ()->Void
    let onPin: (Bool)->Void
    @ViewState var pinned: Bool
    init(model:DeskModel,onHide:@escaping ()->Void,onPin:@escaping (Bool)->Void,pinned:Bool) {
        self.model = model; hardware = model.hardware; remote = model.remote
        self.onHide = onHide; self.onPin = onPin; _pinned = ViewState(initialValue:pinned)
    }
    var body: some View {
        VStack(alignment:.leading,spacing:15) {
            HStack {
                Label("M8 Studio",systemImage:"display").font(.system(size:13,weight:.semibold,design:.rounded))
                Spacer()
                Button { pinned.toggle(); onPin(pinned) } label: { Image(systemName:pinned ? "pin.fill":"pin") }.help(L("Keep above windows")).accessibilityLabel(L("Keep above windows")).accessibilityValue(pinned ? L("Enabled"):L("Disabled"))
                Button(action:onHide) { Image(systemName:"xmark") }.help(L("Hide desktop controls")).accessibilityLabel(L("Hide desktop controls"))
            }.buttonStyle(.plain).foregroundStyle(.secondary)
            Text(hardware.current == nil ? L("No display connected"):model.displayName).font(.system(size:21,weight:.semibold,design:.rounded)).lineLimit(2).fixedSize(horizontal:false,vertical:true)
            if let mode = hardware.current?.mode { Text(modeLabel(mode)).font(.caption).foregroundStyle(.secondary) }
            if hardware.current != nil {
                DeskSlider(title:"Brightness",icon:"sun.max.fill",value:hardware.dim*100,range:20...100,continuous:true) { model.setBrightness($0/100) }
                Text(L("Software dimming · 100% for color work")).font(.caption2).foregroundStyle(.secondary)
            }
            if remote.mediaAvailable, model.samsungIsOutput, let volume = remote.volume {
                Divider()
                DeskSlider(title:remote.muted ? "Muted":"Volume",icon:"speaker.wave.2.fill",value:volume,range:0...100) { model.setVolume($0) }
                Button(L(remote.muted ? "Unmute":"Mute")) { model.handle(.mute) }
            }
            if hardware.rollbackSeconds > 0 {
                HStack { Text(LF("Revert in %@s",[String(hardware.rollbackSeconds)])).font(.caption).monospacedDigit(); Spacer(); Button(L("Keep")) { hardware.keepMode() }; Button(L("Revert")) { hardware.revertMode() } }.controlSize(.small)
            }
            Divider()
            HStack {
                Button(L("Scenes")) { model.section = .scenes; model.onOpenStudio?() }.help(L("Preview a scene in Studio"))
                Spacer()
                Button(L("Open Studio")) { model.onOpenStudio?() }.buttonStyle(.borderedProminent)
            }.controlSize(.small)
        }.padding(.top,30).padding([.horizontal,.bottom],20).frame(width:330)
            .background(DeskStyle.canvas).tint(DeskStyle.brand)
            .environment(\.locale,Locale(identifier:model.language))
            .preferredColorScheme(model.appearance == "Light" ? .light:model.appearance == "Dark" ? .dark:nil)
    }
}

struct SoundTuningCard: View {
    @ObservedObject var model:DeskModel
    var body:some View {
        DeskCard(title:"SOUND STUDIO",icon:"waveform.path") {
            SoundView(model:model.sound, embedded:true, accent:DeskStyle.brand)
        }
    }
}
