import SwiftUI
import Cocoa
import CoreAudio

struct QuickStudioView: View {
    @ObservedObject var model: DeskModel
    @ViewState private var page = 0
    var h: Hardware { model.hardware }; var r: SamsungRemote { model.remote }
    init(model: DeskModel, initialPage: Int = 0) { self.model = model; _page = ViewState(initialValue: initialPage) }
    var favorites: [DeskScene] { model.scenes.filter { $0.favorite && $0.displayUUID == h.current?.uuid } }
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            header
            displaySummary
            Picker(L("Quick view"),selection:$page) { Text(L("Controls")).tag(0); Text(L("Scenes")).tag(1) }.pickerStyle(.segmented).labelsHidden()
            if page == 0 { controls } else { sceneList }
            if h.rollbackSeconds > 0 { recovery }
            footer
        }
        .padding(20).frame(width:380).background(DeskStyle.canvas).tint(DeskStyle.brand)
        .environment(\.locale,Locale(identifier:model.language))
        .preferredColorScheme(model.appearance == "Light" ? .light:model.appearance == "Dark" ? .dark:nil)
    }
    var header: some View {
        HStack(spacing:8) {
            Image(systemName:"display").foregroundStyle(DeskStyle.brand)
            Text("M8 Studio").font(.system(size:14,weight:.semibold,design:.rounded))
            Spacer()
            Button { open(.settings) } label: { Image(systemName:"gearshape").frame(width:24,height:24) }.buttonStyle(.plain).help(L("Settings")).accessibilityLabel(L("Settings"))
            Button { model.onOpenStudio?() } label: { Image(systemName:"arrow.up.left.and.arrow.down.right").frame(width:24,height:24) }.buttonStyle(.plain).help(L("Open the full Studio")).accessibilityLabel(L("Open the full Studio"))
        }.foregroundStyle(.secondary)
    }
    var displaySummary: some View {
        HStack(spacing:12) {
            VStack(alignment:.leading,spacing:7) {
                if h.displays.count > 1 {
                    Menu {
                        ForEach(h.displays) { display in
                            Button { model.selectDisplay(display.id) } label: {
                                Label(display.id == h.selected ? model.displayName:display.name,systemImage:display.id == h.selected ? "checkmark":"display")
                            }
                        }
                    } label: {
                        HStack(spacing:6) { Text(model.displayName).font(.system(size:19,weight:.semibold,design:.rounded)).lineLimit(2).fixedSize(horizontal:false,vertical:true); Image(systemName:"chevron.up.chevron.down").font(.system(size:9,weight:.semibold)) }
                    }.menuStyle(.borderlessButton).fixedSize(horizontal:false,vertical:true).accessibilityLabel(L("Selected display"))
                } else { Text(model.displayName).font(.system(size:19,weight:.semibold,design:.rounded)).lineLimit(2).fixedSize(horizontal:false,vertical:true) }
                Text(h.current?.mode.map(modeLabel) ?? L("Your connected display")).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                HStack(spacing:5) {
                    Circle().fill(r.mediaAvailable && model.samsungIsOutput ? DeskStyle.brand:Color.secondary.opacity(0.5)).frame(width:5,height:5)
                    Text(L(r.mediaAvailable && model.samsungIsOutput ? "Volume connected":r.connected ? "Remote connected":"Local brightness ready")).font(.system(size:9)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength:0)
            MonitorArt(brightness:h.dim,small:true).scaleEffect(0.68).frame(width:110,height:80).accessibilityHidden(true)
        }.padding(14).background(DeskStyle.brand.opacity(0.065),in:RoundedRectangle(cornerRadius:18))
    }
    var controls: some View {
        VStack(alignment:.leading,spacing:13) {
            DeskSlider(title:"Brightness",icon:"sun.max.fill",value:h.dim*100,range:20...100,continuous:true) { model.setBrightness($0/100) }
            HStack(spacing:7) {
                ForEach([25,50,75,100],id:\.self) { value in
                    Button { model.setBrightness(Double(value)/100) } label: {
                        Text(LF("%@%",[String(value)])).font(.system(size:11,weight:.medium)).frame(maxWidth:.infinity).padding(.vertical,7)
                            .background(Int((h.dim*100).rounded()) == value ? DeskStyle.brand.opacity(0.14):Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:8))
                    }.buttonStyle(.plain).accessibilityLabel(L("Brightness") + " " + String(value) + "%")
                }
            }
            Text(L("Software dimming · 100% for color work")).font(.system(size:9)).foregroundStyle(.secondary)
            Divider().opacity(0.5)
            audioOutput
            if let volume = r.volume, r.mediaAvailable, model.samsungIsOutput {
                DeskSlider(title:r.muted ? "Muted":"Volume",icon:r.muted ? "speaker.slash.fill":"speaker.wave.2.fill",value:volume,range:0...100) { model.setVolume($0) }
                HStack {
                    Button { model.changeVolume(-5) } label: { Image(systemName:"minus") }.accessibilityLabel(L("Volume down"))
                    Button(L(r.muted ? "Unmute":"Mute")) { model.handle(.mute) }
                    Button { model.changeVolume(5) } label: { Image(systemName:"plus") }.accessibilityLabel(L("Volume up"))
                    Spacer(); Text(L("Live readback")).font(.system(size:9)).foregroundStyle(.secondary)
                }.controlSize(.small)
            }
            if model.samsungIsOutput && !r.mediaAvailable {
                Button(L("Connect volume")) { r.connect(remoteControl:false) }.controlSize(.small).disabled(r.busy)
            }
            if model.samsungAudioCandidates.count > 1 && model.boundAudioUID == nil {
                Button(L("Link monitor speakers")) { open(.sound) }.font(.system(size:10)).buttonStyle(.plain).foregroundStyle(DeskStyle.brand)
            }
            if h.displays.contains(where: { !$0.builtIn }) {
                Button { open(.settings) } label: {
                    HStack(spacing:7) {
                        Image(systemName:model.keyboard.mediaActive ? "checkmark.circle":"keyboard")
                        Text(L(model.keyboard.mediaActive ? "Mac keys connected":"Set up Mac keys")); Spacer(); Image(systemName:"chevron.right").font(.system(size:9))
                    }.font(.system(size:10)).foregroundStyle(model.keyboard.mediaActive ? DeskStyle.brand:Color.secondary)
                }.buttonStyle(.plain).padding(.vertical,2)
            }
        }
    }
    var audioOutput: some View {
        HStack(spacing:8) {
            Image(systemName:"speaker.wave.2").foregroundStyle(.secondary).frame(width:16)
            Text(L("Sound output")).font(.system(size:11))
            Spacer(minLength:8)
            if h.audio.count > 1 {
                Menu {
                    ForEach(h.audio) { output in
                        Button { h.setOutput(output.id) } label: { Label(output.name,systemImage:output.id == h.output ? "checkmark":"speaker.wave.2") }
                    }
                } label: { Text(h.audio.first(where:{$0.id == h.output})?.name ?? L("Choose output")).font(.system(size:10)).lineLimit(1) }
                .menuStyle(.borderlessButton).fixedSize(horizontal:false,vertical:true).accessibilityLabel(L("Sound output"))
            } else {
                Text(h.audio.first(where:{$0.id == h.output})?.name ?? L("No output connected")).font(.system(size:10)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
    var sceneList: some View {
        VStack(alignment:.leading,spacing:8) {
            if favorites.isEmpty {
                VStack(spacing:10) {
                    Image(systemName:"square.stack.3d.up").font(.system(size:27,weight:.light)).foregroundStyle(DeskStyle.brand)
                    Text(L("Your desk, saved.")).font(.system(size:15,weight:.semibold,design:.rounded))
                    Text(L("Keep brightness, scaling and sound in a favorite scene for this display.")).font(.system(size:11)).foregroundStyle(.secondary).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
                    Button(L("Create a scene")) { open(.scenes) }.buttonStyle(.borderedProminent).controlSize(.small)
                }.frame(maxWidth:.infinity).padding(.vertical,18)
            } else {
                ForEach(favorites.prefix(4)) { scene in
                    Button { model.pendingScene = scene; open(.scenes) } label: {
                        HStack(spacing:10) {
                            Image(systemName:scene.icon).font(.system(size:16)).foregroundStyle(DeskStyle.brand).frame(width:25)
                            VStack(alignment:.leading,spacing:4) {
                                Text(scene.localizedName).font(.system(size:12,weight:.medium)).lineLimit(1)
                                Text(LF("%@% brightness",[String(Int(scene.brightness*100))])).font(.system(size:9)).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName:model.sceneIsActive(scene) ? "checkmark.circle.fill":"chevron.right").foregroundStyle(model.sceneIsActive(scene) ? DeskStyle.brand:Color.secondary).font(.system(size:11))
                        }.padding(12).background(DeskStyle.brand.opacity(model.sceneIsActive(scene) ? 0.11:0.045),in:RoundedRectangle(cornerRadius:12))
                    }.buttonStyle(.plain).help(LF("Preview %@ before applying",[scene.localizedName]))
                }
                Button(L("Manage scenes")) { open(.scenes) }.font(.system(size:10)).buttonStyle(.plain).foregroundStyle(DeskStyle.brand).padding(.top,4)
            }
        }
    }
    var recovery: some View {
        HStack { Text(LF("Revert in %@s",[String(h.rollbackSeconds)])).font(.caption).monospacedDigit(); Spacer(); Button(L("Keep")) { h.keepMode() }; Button(L("Revert")) { h.revertMode() } }.controlSize(.small).padding(10).background(Color.orange.opacity(0.1),in:RoundedRectangle(cornerRadius:10))
    }
    var footer: some View {
        HStack {
            Button(L("Open Studio")) { model.onOpenStudio?() }.buttonStyle(.borderedProminent).controlSize(.small)
            Spacer()
            Button { model.restore() } label: { Image(systemName:"arrow.counterclockwise").frame(width:26,height:26) }.buttonStyle(.plain).help(L("Restore all screens")).accessibilityLabel(L("Restore all screens"))
            Menu {
                Button(L("Desktop controls")) { model.onToggleDesktopCard?() }
                Button(L("Identify screens")) { model.identify() }
                Button(L(model.loginEnabled ? "Disable Open at login":"Enable Open at login")) { model.toggleLogin() }
                Button(L("Settings")) { open(.settings) }
                Divider(); Button(L("Quit M8 Studio")) { NSApp.terminate(nil) }
            } label: { Image(systemName:"ellipsis").frame(width:22,height:26) }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width:22).accessibilityLabel(L("More actions"))
        }.padding(.top,2)
    }
    func open(_ section: DeskSection) { model.section = section; model.onOpenStudio?() }
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
    func showPopover() { NSApp.activate(); model.hardware.refresh(); model.keyboard.refreshPermission(); guard let button = item.button else { return }; popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY); popover.contentViewController?.view.window?.makeKey() }
    func closePopover() { popover.performClose(nil) }
    private func entry(_ title:String,action:Selector,tag:Int = 0)->NSMenuItem { let entry = NSMenuItem(title:L(title),action:action,keyEquivalent:""); entry.target = self; entry.tag = tag; return entry }
    func quickMenu()->NSMenu {
        let menu = NSMenu(); menu.addItem(entry("Open Studio",action:#selector(openStudio))); menu.addItem(entry("Desktop controls",action:#selector(desktopCard)))
        menu.addItem(.separator())
        if model.hardware.displays.count > 1 {
            let screens = NSMenuItem(title:L("Selected display"),action:nil,keyEquivalent:""); let options = NSMenu()
            for display in model.hardware.displays { let option = entry(display.id == model.hardware.selected ? model.displayName:display.name,action:#selector(screenAction(_:)),tag:Int(display.id)); option.state = display.id == model.hardware.selected ? .on:.off; options.addItem(option) }; screens.submenu = options; menu.addItem(screens)
        }
        if model.hardware.audio.count > 1 {
            let audio = NSMenuItem(title:L("Sound output"),action:nil,keyEquivalent:""); let options = NSMenu()
            for output in model.hardware.audio { let option = entry(output.name,action:#selector(outputAction(_:)),tag:Int(output.id)); option.state = output.id == model.hardware.output ? .on:.off; options.addItem(option) }; audio.submenu = options; menu.addItem(audio)
        }
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
    @objc private func screenAction(_ sender:NSMenuItem) { model.selectDisplay(CGDirectDisplayID(sender.tag)) }
    @objc private func outputAction(_ sender:NSMenuItem) { model.hardware.setOutput(AudioDeviceID(sender.tag)) }
    @objc private func desktopCard() { model.onToggleDesktopCard?() }
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
