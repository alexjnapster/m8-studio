import SwiftUI
import Cocoa

struct QuickStudioView: View {
    @ObservedObject var model: DeskModel
    var h: Hardware { model.hardware }; var r: SamsungRemote { model.remote }
    var body: some View {
        VStack(alignment:.leading,spacing:17) {
            HStack { Image(systemName:"display").foregroundStyle(DeskStyle.brand); Text(L("M8 Studio")).font(.system(size:15,weight:.semibold,design:.rounded)); Spacer(); Button { model.onOpenStudio?() } label: { Image(systemName:"arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help(L("Open the full Studio")) }
            HStack { VStack(alignment:.leading,spacing:7) { Text(L(model.displayName)).font(.system(size:21,weight:.semibold,design:.rounded)); Text(L(h.current?.mode.map(modeLabel) ?? "Your connected display")).font(.system(size:10)).foregroundStyle(.secondary); HStack(spacing:5) { Circle().fill(r.connected ? DeskStyle.brand:Color.orange).frame(width:5,height:5); Text(L(r.connected ? "Remote connected":"Local brightness ready")).font(.system(size:9)).foregroundStyle(.secondary) } }; Spacer(); MonitorArt(brightness:h.dim,small:true).frame(width:156,height:115) }
            Divider().opacity(0.6)
            DeskSlider(title:"Brightness",icon:"sun.max.fill",value:h.dim*100,range:20...100,continuous:true) { model.setBrightness($0/100) }
            HStack(spacing:7) { ForEach([25,50,75,100],id:\.self) { value in Button(LF("%@%",[String(describing:value)])) { model.setBrightness(Double(value)/100) }.font(.system(size:10)).frame(maxWidth:.infinity) } }.buttonStyle(.bordered).controlSize(.small)
            Text(L("Software dimming · 100% for color work")).font(.system(size:9)).foregroundStyle(.secondary)
            if let volume = r.volume, r.mediaAvailable, model.samsungIsOutput {
                Divider().opacity(0.6)
                DeskSlider(title:r.muted ? "Muted":"Volume",icon:r.muted ? "speaker.slash.fill":"speaker.wave.2.fill",value:volume,range:0...100) { model.setVolume($0) }
                HStack { Button { model.changeVolume(-5) } label: { Image(systemName:"minus") }; Button(L(r.muted ? "Unmute":"Mute")) { model.handle(.mute) }; Button { model.changeVolume(5) } label: { Image(systemName:"plus") }; Spacer(); Text(L(model.keyboard.mediaActive ? "Mac keys connected":"⌃⌥⌘ ↑ / ↓")).font(.system(size:9)).foregroundStyle(.secondary) }.controlSize(.small)
            }
            HStack(spacing:8) { ForEach(model.scenes.filter { $0.favorite && $0.displayUUID == h.current?.uuid }.prefix(3)) { scene in Button { model.pendingScene = scene; model.onOpenStudio?() } label: { VStack(spacing:6) { Image(systemName:scene.icon).foregroundStyle(DeskStyle.brand); Text(scene.localizedName).font(.system(size:9)).lineLimit(1) }.frame(maxWidth:.infinity).padding(.vertical,10).background(DeskStyle.brand.opacity(0.06),in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain) } }
            if h.rollbackSeconds > 0 { HStack { Text(LF("Revert in %@s",[String(describing:h.rollbackSeconds)])).font(.caption).monospacedDigit(); Spacer(); Button(L("Keep")) { h.keepMode() }; Button(L("Revert")) { h.revertMode() } } }
            HStack { Button(L("Open Studio")) { model.onOpenStudio?() }.buttonStyle(.borderedProminent); Spacer(); Button { model.restore() } label: { Image(systemName:"arrow.counterclockwise") }.buttonStyle(.plain).help(L("Restore all screens")); Menu { Button(L("Identify screens")) { model.identify() }; Button(L(model.loginEnabled ? "Disable Open at login":"Enable Open at login")) { model.toggleLogin() }; Button(L("Settings")) { model.section = .settings; model.onOpenStudio?() }; Divider(); Button(L("Quit M8 Studio")) { NSApp.terminate(nil) } } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:22) }
        }.id(model.language).padding(22).frame(width:380).background(DeskStyle.canvas).tint(DeskStyle.brand).environment(\.locale,Locale(identifier:model.language)).preferredColorScheme(model.appearance == "Light" ? .light:model.appearance == "Dark" ? .dark:nil)
    }
}
@MainActor final class DeskStatusController: NSObject {
    let model: DeskModel
    let item = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let popover = NSPopover()
    private var scrollObserver: Any?
    init(model:DeskModel) {
        self.model = model; super.init()
        if let button = item.button { button.image = NSImage(systemSymbolName:"display",accessibilityDescription:"M8 Studio"); button.toolTip = L("M8 Studio · click for controls · right-click for quick actions"); button.target = self; button.action = #selector(clicked); button.sendAction(on:[.leftMouseUp,.rightMouseUp]) }
        popover.behavior = .transient; popover.contentViewController = NSHostingController(rootView:QuickStudioView(model:model))
        scrollObserver = NSEvent.addLocalMonitorForEvents(matching:.scrollWheel) { [weak self] event in
            guard let self, let button = self.item.button, event.window === button.window, event.modifierFlags.contains(.option), button.bounds.contains(button.convert(event.locationInWindow,from:nil)) else { return event }
            if abs(event.scrollingDeltaY) > 0 { self.model.handle(event.scrollingDeltaY > 0 ? .brighter:.dimmer,fine:true) }
            return nil
        }
    }
    @objc func clicked() {
        model.hardware.refresh(); model.keyboard.refreshPermission()
        guard let button = item.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp { popover.performClose(nil); NSMenu.popUpContextMenu(quickMenu(),with:event,for:button); return }
        if popover.isShown { popover.performClose(nil) } else { popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY); popover.contentViewController?.view.window?.makeKey() }
    }
    func showPopover() { model.hardware.refresh(); model.keyboard.refreshPermission(); guard let button = item.button else { return }; popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY); popover.contentViewController?.view.window?.makeKey() }
    func closePopover() { popover.performClose(nil) }
    private func entry(_ title:String,action:Selector,tag:Int = 0)->NSMenuItem { let entry = NSMenuItem(title:L(title),action:action,keyEquivalent:""); entry.target = self; entry.tag = tag; return entry }
    func quickMenu()->NSMenu {
        let menu = NSMenu(); menu.addItem(entry("Open Studio",action:#selector(openStudio)))
        menu.addItem(.separator())
        let brightness = NSMenuItem(title:L("Brightness"),action:nil,keyEquivalent:""); let levels = NSMenu()
        for value in [25,50,75,100] { let option = entry("\(value)%",action:#selector(brightnessAction(_:)),tag:value); option.state = Int((model.hardware.dim*100).rounded()) == value ? .on:.off; levels.addItem(option) }; brightness.submenu = levels; menu.addItem(brightness)
        if model.remote.mediaAvailable, model.samsungIsOutput {
            let volume = NSMenuItem(title:L("Speaker volume"),action:nil,keyEquivalent:""); let choices = NSMenu()
            for value in [0,5,10,15,20,30,50] { choices.addItem(entry("\(value)%",action:#selector(volumeAction(_:)),tag:value)) }; volume.submenu = choices; menu.addItem(volume); menu.addItem(entry(model.remote.muted ? "Unmute":"Mute",action:#selector(mute)))
        }
        let favorites = model.scenes.filter { $0.favorite && $0.displayUUID == model.hardware.current?.uuid }
        if !favorites.isEmpty { menu.addItem(.separator()); for (index,scene) in model.scenes.enumerated() where scene.favorite && scene.displayUUID == model.hardware.current?.uuid { menu.addItem(entry(LF("Preview %@…",[scene.localizedName]),action:#selector(sceneAction(_:)),tag:index)) } }
        menu.addItem(.separator()); menu.addItem(entry("Identify screens",action:#selector(identify))); menu.addItem(entry("Restore all screens",action:#selector(restore))); menu.addItem(.separator()); menu.addItem(entry("Quit M8 Studio",action:#selector(quit))); return menu
    }
    @objc private func openStudio() { model.onOpenStudio?() }
    @objc private func brightnessAction(_ sender:NSMenuItem) { model.setBrightness(Double(sender.tag)/100) }
    @objc private func volumeAction(_ sender:NSMenuItem) { model.setVolume(Double(sender.tag)) }
    @objc private func sceneAction(_ sender:NSMenuItem) { guard model.scenes.indices.contains(sender.tag) else { return }; model.pendingScene = model.scenes[sender.tag]; model.onOpenStudio?() }
    @objc private func mute() { model.handle(.mute) }
    @objc private func identify() { model.identify() }
    @objc private func restore() { model.restore() }
    @objc private func quit() { NSApp.terminate(nil) }
}
@MainActor final class DeskOSD {
    private var window: NSWindow?
    private var task:Task<Void,Never>?
    func show(icon:String,title:String,level:Double?,screen:NSScreen?) {
        guard let screen else { return }; task?.cancel()
        if window == nil { let w = NSWindow(contentRect:.zero,styleMask:.borderless,backing:.buffered,defer:false); w.backgroundColor = .clear; w.isOpaque = false; w.ignoresMouseEvents = true; w.level = .screenSaver; w.isReleasedWhenClosed = false; w.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary,.ignoresCycle]; window = w }
        window?.setFrame(CGRect(x:screen.visibleFrame.midX-130,y:screen.visibleFrame.minY+90,width:260,height:100),display:true)
        window?.contentView = NSHostingView(rootView:VStack(spacing:10) { HStack { Image(systemName:icon); Text(L(title)).font(.headline); Spacer(); if let level { Text(LF("%@%",[String(describing:Int(level*100))])).monospacedDigit() } }; if let level { ProgressView(value:level).tint(DeskStyle.brand) } }.padding(22).frame(width:260,height:100).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:25)))
        window?.orderFrontRegardless(); task = Task { try? await Task.sleep(for:.seconds(1.5)); if !Task.isCancelled { window?.orderOut(nil) } }
    }
}
