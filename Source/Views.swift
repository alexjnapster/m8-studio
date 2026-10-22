import SwiftUI
import AppKit
import ServiceManagement

typealias ViewState<Value> = SwiftUI.State<Value>
func openSettings(_ pane: String) { if let url = URL(string:"x-apple.systempreferences:\(pane)") { NSWorkspace.shared.open(url) } }
enum DeskStyle {
    static let brand = Color(nsColor:NSColor(name:NSColor.Name("DeskGreen")) { appearance in appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(red:0.53,green:0.91,blue:0.74,alpha:1) : NSColor(red:0.04,green:0.40,blue:0.29,alpha:1) })
    static let canvas = Color(nsColor:NSColor(name:NSColor.Name("DeskCanvas")) { appearance in appearance.bestMatch(from:[.darkAqua,.aqua]) == .darkAqua ? NSColor(red:0.055,green:0.085,blue:0.08,alpha:1) : NSColor(red:0.96,green:0.97,blue:0.95,alpha:1) })
    static let card = Color(nsColor:.controlBackgroundColor)
}
struct DeskCard<Content: View>: View {
    let title: String; let icon: String; @ViewBuilder var content: Content
    var body: some View { VStack(alignment:.leading,spacing:16) { Label(L(title),systemImage:icon).font(.system(size:12,weight:.semibold)).foregroundStyle(.secondary); content }.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(DeskStyle.card,in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(.primary.opacity(0.055),lineWidth:1)) }
}
struct MonitorArt: View {
    var brightness: Double = 1; var small = false
    var body: some View {
        ZStack {
            Ellipse().fill(.black.opacity(0.08)).frame(width:small ? 115:240,height:14).offset(y:small ? 58:102).blur(radius:8)
            VStack(spacing:0) {
                ZStack {
                    RoundedRectangle(cornerRadius:small ? 10:16).fill(Color(red:0.88,green:0.88,blue:0.81)).padding(-5)
                    RoundedRectangle(cornerRadius:small ? 7:12).fill(LinearGradient(colors:[Color(red:0.67,green:0.86,blue:0.75),Color(red:0.21,green:0.49,blue:0.44),Color(red:0.08,green:0.27,blue:0.26)],startPoint:.topLeading,endPoint:.bottomTrailing))
                    GeometryReader { geo in
                        Circle().fill(.white.opacity(0.17)).frame(width:geo.size.width*0.8).offset(x:geo.size.width*0.45,y:-geo.size.height*0.7)
                        RoundedRectangle(cornerRadius:50).fill(.white.opacity(0.16)).frame(width:geo.size.width*0.9,height:geo.size.height*0.7).rotationEffect(.degrees(-30)).offset(x:-geo.size.width*0.4,y:geo.size.height*0.6)
                    }.clipShape(RoundedRectangle(cornerRadius:12))
                    VStack { Spacer(); HStack(spacing:3) { ForEach(0..<5) { _ in RoundedRectangle(cornerRadius:2).fill(.white.opacity(0.7)).frame(width:small ? 6:12,height:small ? 6:12) } }.padding(5).background(.ultraThinMaterial,in:Capsule()).padding(.bottom,7) }
                    RoundedRectangle(cornerRadius:12).fill(.black.opacity(1-brightness))
                }.frame(width:small ? 152:280,height:small ? 87:158)
                Rectangle().fill(Color(red:0.78,green:0.79,blue:0.72)).frame(width:small ? 9:14,height:small ? 17:28)
                Capsule().fill(Color(red:0.82,green:0.82,blue:0.76)).frame(width:small ? 65:110,height:small ? 5:7)
            }
        }.accessibilityHidden(true)
    }
}
struct IdentifyView: View {
    let number: Int; let name: String
    var body: some View { VStack(spacing:8) { Text(LF("%@",[String(describing:number)])).font(.system(size:64,weight:.semibold,design:.rounded)); Text(L(name)).font(.headline) }.foregroundStyle(.white).frame(width:320,height:180).background(Color.black.opacity(0.85),in:RoundedRectangle(cornerRadius:30)) }
}
struct DeskSlider: View {
    let title: String; let icon: String; let value: Double; let range: ClosedRange<Double>; var unit = "%"; var continuous = false; let commit: (Double)->Void
    @ViewState private var pending = 0.0
    @ViewState private var editing = false
    var body: some View {
        VStack(spacing:12) {
            HStack { Label(L(title),systemImage:icon).font(.system(size:14,weight:.medium)); Spacer(); Text(LF("%@%@",[String(describing:Int(pending.rounded())),String(describing:unit)])).font(.system(size:20,weight:.semibold,design:.rounded)).monospacedDigit().contentTransition(.numericText()) }
            Slider(value:$pending,in:range,onEditingChanged:{ active in editing = active; if !active { commit(pending) } }).tint(DeskStyle.brand).accessibilityLabel(L(title)).accessibilityValue(LF("%@ percent",[String(describing:Int(pending))]))
                .onChange(of:pending) { _,value in if continuous && editing { commit(value) } }
        }.onAppear { pending = value }.onChange(of:value) { _,value in if !editing && abs(value-pending) > 0.5 { pending = value } }
    }
}
struct StudioView: View {
    @ObservedObject var model: DeskModel
    @ViewState private var newSceneName = L("My setup")
    @ViewState private var pendingProfile: DisplayProfile?
    @ViewState private var selectedPattern: PatternKind = .chroma
    @ViewState private var showActivity = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var h: Hardware { model.hardware }; var r: SamsungRemote { model.remote }
    var body: some View {
        HStack(spacing:0) {
            sidebar
            VStack(spacing:0) {
                header
                if h.rollbackSeconds > 0 { rollback }
                ScrollView {
                    VStack(alignment:.leading,spacing:20) {
                        switch model.section {
                        case .overview: overview
                        case .display: displayPage
                        case .color: colorPage
                        case .sound: soundPage
                        case .remote: remotePage
                        case .scenes: scenesPage
                        case .labs: labsPage
                        case .settings: settingsPage
                        }
                    }.padding(28).frame(maxWidth:.infinity,alignment:.leading)
                }
                footer
            }
        }.id(model.language).frame(minWidth:1000,minHeight:720).background(DeskStyle.canvas).tint(DeskStyle.brand)
            .environment(\.locale,Locale(identifier:model.language))
            .preferredColorScheme(model.appearance == "Light" ? .light : model.appearance == "Dark" ? .dark : nil)
            .animation(reduceMotion ? nil : .easeInOut(duration:0.16),value:model.section)
            .sheet(item:$pendingProfile) { profile in profilePreview(profile) }
            .sheet(item:$model.pendingScene) { scene in scenePreview(scene) }
    }
    var sidebar: some View {
        VStack(alignment:.leading,spacing:25) {
            HStack(spacing:10) { Image(systemName:"display").font(.system(size:24,weight:.light)).foregroundStyle(DeskStyle.brand); VStack(alignment:.leading,spacing:1) { Text(L("M8 Studio")).font(.system(size:17,weight:.semibold,design:.rounded)); Text(L("A happier desk.")).font(.system(size:10)).foregroundStyle(.secondary) } }.padding(.top,9)
            VStack(spacing:5) { ForEach(DeskSection.allCases) { section in
                Button { model.section = section } label: { HStack(spacing:11) { Image(systemName:section.icon).frame(width:20); Text(L(section.rawValue)).lineLimit(1).minimumScaleFactor(0.85).font(.system(size:13,weight:model.section == section ? .semibold:.regular)); Spacer(); if section == .labs { Text(L(model.builtinBrightness() != nil && h.current?.builtIn == false ? "3":"2")).font(.system(size:9,weight:.bold)).padding(.horizontal,5).padding(.vertical,2).background(.primary.opacity(0.06),in:Capsule()) } }.foregroundStyle(model.section == section ? DeskStyle.brand:Color.primary.opacity(0.7)).padding(.horizontal,12).padding(.vertical,11).background(model.section == section ? DeskStyle.brand.opacity(0.1):.clear,in:RoundedRectangle(cornerRadius:12)) }.buttonStyle(.plain).accessibilityAddTraits(model.section == section ? .isSelected:[])
            } }
            Spacer()
            Button { model.identify() } label: { Label(L("Find my screens"),systemImage:"viewfinder").font(.system(size:11)) }.buttonStyle(.plain).foregroundStyle(.secondary)
            HStack(spacing:7) { Circle().fill(r.connected ? DeskStyle.brand:Color.orange).frame(width:6,height:6); Text(L(r.connected ? "Monitor connected":"Remote offline")).font(.system(size:10,weight:.medium)) }.padding(10).frame(maxWidth:.infinity,alignment:.leading).background(.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:10))
        }.padding(18).frame(width:224).background(DeskStyle.card.opacity(0.6)).overlay(alignment:.trailing) { Rectangle().fill(.primary.opacity(0.05)).frame(width:1) }
    }
    var header: some View {
        HStack {
            VStack(alignment:.leading,spacing:3) { Text(L(model.section.rawValue)).font(.system(size:24,weight:.semibold,design:.rounded)); Text(L(pageSubtitle)).font(.system(size:11)).foregroundStyle(.secondary) }
            Spacer()
            Picker(L("Selected display"),selection:Binding(get:{h.selected},set:{model.selectDisplay($0)})) { ForEach(h.displays) { display in Text(L(display.id == h.selected ? model.displayName:display.name)).tag(display.id) } }.labelsHidden().frame(maxWidth:185)
            Button { model.refresh() } label: { Image(systemName:"arrow.clockwise") }.buttonStyle(.borderless).help(L("Refresh this desk"))
        }.padding(.horizontal,28).padding(.vertical,21).background(DeskStyle.card.opacity(0.5))
    }
    var pageSubtitle: String { switch model.section { case .overview:return "Everything you reach for, right here."; case .display:return "Make room for the way you work."; case .color:return "Good color begins with the right profile."; case .sound:return "Your speakers. Your keys. Your volume."; case .remote:return "The little remote that is always nearby."; case .scenes:return "A different mood, one thoughtful click."; case .labs:return "Small experiments. Easy to undo."; case .settings:return "Make Studio feel like yours." } }
    var footer: some View { HStack(spacing:8) { Image(systemName:model.toast.isEmpty ? "circle.dotted":"checkmark.circle.fill").foregroundStyle(DeskStyle.brand); Text(L(model.toast.isEmpty ? "\(model.displayName) · \(h.current?.mode.map(modeLabel) ?? "Connected display")":model.toast)).font(.system(size:10)).lineLimit(2); Spacer(); Button { guide() } label: { Image(systemName:"questionmark.circle") }.buttonStyle(.plain).help(L("Open the full guide")) }.padding(.horizontal,28).frame(height:40).background(DeskStyle.card.opacity(0.55)) }
    var rollback: some View { HStack(spacing:12) { Image(systemName:"timer").foregroundStyle(DeskStyle.brand); Text(LF("Keep this view? Restoring in %@s",[String(describing:h.rollbackSeconds)])).font(.callout).monospacedDigit(); Spacer(); Button(L("Revert")) { h.revertMode(); model.announce("Previous display mode restored") }; Button(L("Keep")) { h.keepMode(); model.announce("Display mode kept") }.buttonStyle(.borderedProminent) }.padding(14).background(DeskStyle.brand.opacity(0.12)) }
    var overview: some View {
        Group {
            HStack(spacing:18) {
                VStack(alignment:.leading,spacing:12) {
                    Text(L("HELLO, CLARITY.")).font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2).foregroundStyle(DeskStyle.brand)
                    Text(L("Your desk,\nin a good place.")).font(.system(size:32,weight:.semibold,design:.rounded)).lineSpacing(-2)
                    Text(LF("%@ · %@",[String(describing:model.displayName),String(describing:L(model.panelDescription))])).font(.system(size:11)).foregroundStyle(.secondary)
                    HStack(spacing:7) { miniPill("HiDPI",active:(h.current?.mode?.pixelWidth ?? 0) > (h.current?.mode?.width ?? 0)); miniPill("Stereo",active:model.samsungIsOutput); miniPill("Profile ready",active:model.colors.currentURL != nil) }
                }
                Spacer(minLength:0); MonitorArt(brightness:h.dim).frame(width:286,height:205)
            }.padding(24).background(LinearGradient(colors:[DeskStyle.brand.opacity(0.10),DeskStyle.brand.opacity(0.02)],startPoint:.topLeading,endPoint:.bottomTrailing),in:RoundedRectangle(cornerRadius:26))
            HStack(alignment:.top,spacing:16) { brightnessCard; volumeCard }
            sceneStrip
            if model.showOnboarding { DeskCard(title:"MAKE YOURSELF AT HOME",icon:"hand.wave") {
                HStack(alignment:.top,spacing:18) { onboarding("1","Pick your view","Display has three comfortable scaling choices."); onboarding("2","Use your keys","Enable Mac media keys in Settings."); onboarding("3","Save a scene","Keep a favorite setup for later.") }
                HStack { Button(L("Explore keyboard controls")) { model.section = .settings }; Spacer(); Button(L("Got it")) { model.dismissWelcome() }.buttonStyle(.borderless) }
            } }
        }
    }
    func miniPill(_ text: String, active: Bool) -> some View { Text(L(text)).font(.system(size:9,weight:.medium)).padding(.horizontal,8).padding(.vertical,5).foregroundStyle(active ? DeskStyle.brand:.secondary).background(active ? DeskStyle.brand.opacity(0.09):Color.primary.opacity(0.04),in:Capsule()) }
    func onboarding(_ n: String,_ title: String,_ detail: String) -> some View { VStack(alignment:.leading,spacing:7) { Text(L(n)).font(.system(size:13,weight:.semibold)).foregroundStyle(DeskStyle.brand); Text(L(title)).font(.system(size:12,weight:.semibold)); Text(L(detail)).font(.system(size:10)).foregroundStyle(.secondary) }.frame(maxWidth:.infinity,alignment:.leading) }
    var brightnessCard: some View {
        DeskCard(title:"FEEL-GOOD BRIGHTNESS",icon:"sun.max") {
            DeskSlider(title:"Brightness",icon:"sun.max.fill",value:h.dim*100,range:20...100,continuous:true) { model.setBrightness($0/100) }
            HStack(spacing:7) { ForEach([25,50,75,100],id:\.self) { value in Button(LF("%@%",[String(describing:value)])) { model.setBrightness(Double(value)/100) }.buttonStyle(.bordered).controlSize(.small) } }
            Text(L("Smooth software dimming. For color work, use 100%.")).font(.system(size:10)).foregroundStyle(.secondary)
            Toggle(L("Link all screens"),isOn:$model.linked).font(.system(size:11)).toggleStyle(.switch).controlSize(.mini)
        }
    }
    var volumeCard: some View {
        DeskCard(title:"A LITTLE MORE SOUND",icon:"speaker.wave.2") {
            if let volume = r.volume, r.mediaAvailable, model.samsungIsOutput {
                DeskSlider(title:r.muted ? "Muted":"Monitor volume",icon:r.muted ? "speaker.slash.fill":"speaker.wave.2.fill",value:volume,range:0...100) { model.setVolume($0) }
                HStack { Button { model.changeVolume(-5) } label: { Image(systemName:"minus") }; Button(L(r.muted ? "Unmute":"Mute")) { model.handle(.mute) }; Button { model.changeVolume(5) } label: { Image(systemName:"plus") }; Spacer(); Text(L("Live readback")).font(.system(size:9)).foregroundStyle(.secondary) }.controlSize(.small)
                Text(L(model.keyboard.mediaActive ? "Your Mac’s volume keys are connected.":"Shortcut: ⌃⌥⌘ ↑ / ↓ · M to mute")).font(.system(size:10)).foregroundStyle(.secondary)
            } else {
                Text(L(model.samsungIsOutput ? "Connect your monitor":"Choose your Samsung speakers")).font(.headline)
                Text(L("The volume control appears when Samsung is selected and connected.")).font(.system(size:11)).foregroundStyle(.secondary)
                if model.samsungIsOutput || h.audio.contains(where: { $0.name.uppercased().contains("SAMSUNG") }) {
                    Button(L(model.samsungIsOutput ? "Connect remote":"Select Samsung output")) { if model.samsungIsOutput { model.section = .remote } else if let output = h.audio.first(where:{$0.name.uppercased().contains("SAMSUNG")}) { h.setOutput(output.id) } }
                } else { Text(L("Samsung audio appears when the monitor is connected to this Mac.")).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    var sceneStrip: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack { Label(L("YOUR SHORTCUT TO A GOOD DAY"),systemImage:"sparkles").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary); Spacer(); Button(L("All scenes")) { model.section = .scenes }.font(.system(size:10)).buttonStyle(.plain).foregroundStyle(DeskStyle.brand) }
            HStack(spacing:10) { ForEach(model.scenes.filter { $0.favorite && $0.displayUUID == h.current?.uuid }.prefix(4)) { scene in sceneButton(scene) } }
        }
    }
    func sceneButton(_ scene: DeskScene) -> some View { Button { model.pendingScene = scene } label: { HStack(spacing:9) { Image(systemName:scene.icon).foregroundStyle(DeskStyle.brand); Text(scene.localizedName).font(.system(size:12,weight:.medium)); Spacer(minLength:0); if model.sceneIsActive(scene) { Image(systemName:"checkmark.circle.fill").foregroundStyle(DeskStyle.brand) } }.padding(15).frame(maxWidth:.infinity).background(model.sceneIsActive(scene) ? DeskStyle.brand.opacity(0.12):DeskStyle.card,in:RoundedRectangle(cornerRadius:15)) }.buttonStyle(.plain).help(LF("Preview %@ before applying",[String(describing:scene.localizedName)])) }
    var displayPage: some View {
        Group {
            DeskCard(title:"CHOOSE YOUR CANVAS",icon:"rectangle.3.group") {
                HStack(spacing:12) { viewChoice("Larger text","Comfortably crisp",width:1920,hiDPI:true,icon:"textformat.size.larger"); viewChoice("Balanced","Room to breathe",width:2560,hiDPI:true,icon:"rectangle.split.2x2"); viewChoice(model.isM8 ? "Native 4K" : "More space",model.isM8 ? "Every panel pixel" : "Display-reported mode",width:model.isM8 ? 3840 : (model.activeModes.filter { $0.pixelWidth == $0.width }.map(\.width).max() ?? 0),hiDPI:false,icon:"square.dashed") }
                Text(L(model.isM8 ? "HiDPI renders more pixels for sharper text. The rendering buffer and the physical panel are separate. Your M8 panel remains 3840 × 2160 at up to 60 Hz." : "Choose from the modes reported by this display. HiDPI improves text rendering; available refresh rates depend on the display and connection.")).font(.caption).foregroundStyle(.secondary)
                Menu(L(model.isM8 ? "More 60 Hz modes" : "All display modes")) { ForEach(model.activeModes,id:\.ioDisplayModeID) { mode in Button(L(modeLabel(mode))) { model.applyMode(mode) } } }.disabled(h.rollbackSeconds > 0)
            }
            DeskCard(title:"YOUR SCREENS",icon:"rectangle.on.rectangle") {
                HStack(spacing:15) { ForEach(Array(h.displays.enumerated()),id:\.element.id) { i,display in Button { model.selectDisplay(display.id) } label: { VStack(spacing:10) { Image(systemName:display.builtIn ? "laptopcomputer":"display").font(.system(size:36,weight:.light)); Text(LF("%@ · %@",[String(describing:i+1),String(describing:display.id == h.selected ? model.displayName:display.name)])).font(.caption); if CGMainDisplayID() == display.id { Text(L("Main screen")).font(.caption2).foregroundStyle(.secondary) } }.foregroundStyle(display.id == h.selected ? DeskStyle.brand:.secondary).frame(maxWidth:.infinity).padding(20).background(display.id == h.selected ? DeskStyle.brand.opacity(0.08):Color.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:15)) }.buttonStyle(.plain) } }
                HStack { Button(L("Identify screens")) { model.identify() }; Button(L("Make main screen")) { h.setMain(); model.announce(h.notice) }; Spacer(); Button(L("Arrange in macOS")) { openSettings("com.apple.Displays-Settings.extension") } }
            }
            brightnessCard
            if h.current?.builtIn == false && (!model.isM8 || !h.ddc.isEmpty) {
                DeskCard(title:"HARDWARE CONTROLS",icon:"slider.horizontal.3") {
                    if h.probing { ProgressView(L("Checking hardware controls…")) }
                    else { Button(L("Detect hardware controls")) { h.probe() } }
                    ForEach(["luminance","contrast","volume"],id:\.self) { key in
                        if let value = h.ddc[key], let maximum = h.ddcMax[key] {
                            DeskSlider(title:key == "luminance" ? "Backlight" : key == "contrast" ? "Contrast" : "Hardware volume",icon:key == "volume" ? "speaker.wave.2":"sun.max",value:value,range:0...maximum) { h.setDDC(key,$0) }.disabled(h.changingDDC.contains(key))
                        }
                    }
                    if !h.notice.isEmpty { Text(L(h.notice)).font(.caption).foregroundStyle(.secondary) }
                    Text(L("Only controls confirmed by the display appear here. Software dimming is separate from backlight brightness.")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    func viewChoice(_ title:String,_ detail:String,width:Int,hiDPI:Bool,icon:String)->some View {
        Group { if let mode = model.mode(width,hiDPI:hiDPI) {
            Button { model.applyMode(mode) } label: { VStack(alignment:.leading,spacing:10) { Image(systemName:icon).font(.system(size:24,weight:.light)); Text(L(title)).font(.system(size:13,weight:.semibold)); Text(L(detail)).font(.system(size:10)).foregroundStyle(.secondary); Text(LF("%@ wide · %@",[String(describing:width),String(describing:hiDPI ? "HiDPI":"1×")])).font(.system(size:9,design:.monospaced)).foregroundStyle(DeskStyle.brand) }.frame(maxWidth:.infinity,alignment:.leading).padding(18).background(h.current?.mode?.ioDisplayModeID == mode.ioDisplayModeID ? DeskStyle.brand.opacity(0.12):Color.primary.opacity(0.03),in:RoundedRectangle(cornerRadius:17)) }.buttonStyle(.plain).disabled(h.rollbackSeconds > 0)
        } }
    }
    var colorPage: some View {
        Group {
            HStack(spacing:18) { VStack(alignment:.leading,spacing:9) { Text(L("Color you can trust.")).font(.system(size:27,weight:.semibold,design:.rounded)); Text(LF("Current profile: %@",[String(describing:model.colors.currentName)])).font(.callout).foregroundStyle(.secondary); Text(L("Preserve the profile that describes this display. A measured ICC profile can refine it; a wider gamut label cannot create new panel colors.")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Circle().fill(AngularGradient(colors:[.red,.yellow,.green,.cyan,.blue,.purple,.red],center:.center)).frame(width:105,height:105).overlay(Circle().fill(DeskStyle.canvas).padding(20)) }.padding(23).background(DeskStyle.brand.opacity(0.07),in:RoundedRectangle(cornerRadius:23))
            DeskCard(title:"PROFILE LIBRARY",icon:"paintpalette") {
                ForEach(model.colors.profiles) { profile in
                    HStack(spacing:14) { Image(systemName:profile.id == "srgb" ? "globe":"display").font(.title3).foregroundStyle(DeskStyle.brand).frame(width:32); VStack(alignment:.leading,spacing:4) { Text(L(profile.name)).font(.system(size:13,weight:.medium)); Text(L(profile.detail)).font(.system(size:10)).foregroundStyle(.secondary) }; Spacer(); if model.colors.currentURL?.standardizedFileURL == profile.url.standardizedFileURL { Image(systemName:"checkmark.circle.fill").foregroundStyle(DeskStyle.brand) } else { Button(L("Preview")) { pendingProfile = profile }.controlSize(.small) } }
                    if profile.id != model.colors.profiles.last?.id { Divider().opacity(0.5) }
                }
                HStack { Button(L("Import measured ICC…")) { model.colors.importProfile() }; if model.colors.canUndo { Button(L("Undo profile change")) { model.colors.undo() } }; Spacer(); Button(L("ColorSync Utility")) { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Utilities/ColorSync Utility.app")) } }
                if !model.colors.status.isEmpty { Text(L(model.colors.status)).font(.caption).foregroundStyle(.secondary) }
            }
            pictureTests
            DeskCard(title:"A BETTER START FOR COLOR WORK",icon:"checkmark.seal") {
                Text(L("Warm up the panel, use consistent room light, turn software dimming to 100%, and avoid automatic picture enhancement while measuring. A colorimeter can establish white point, luminance, gamma and Delta E for your individual panel.")).font(.caption).foregroundStyle(.secondary)
                HStack { Button(L("Set brightness to 100%")) { model.setBrightness(1) }; Button(L("Read M80B color & HDR findings")) { guide() } }
            }
        }
    }
    var pictureTests: some View {
        DeskCard(title:"LOOK A LITTLE CLOSER",icon:"viewfinder") {
            HStack { Picker(L("Test pattern"),selection:$selectedPattern) { ForEach(PatternKind.allCases) { Text(L($0.rawValue)).tag($0) } }.labelsHidden(); Button(L("Open pattern")) { PatternController.shared.show(selectedPattern,screen:h.current?.screen) }.buttonStyle(.borderedProminent) }
            Text(L("Check text, clipping, gradients, pixels and geometry. Press Escape to leave a pattern. These visual checks do not measure calibration.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    var soundPage: some View {
        Group {
            HStack(alignment:.top,spacing:16) { volumeCard; DeskCard(title:"SOUND GOES HERE",icon:"arrow.triangle.branch") { Picker(L("Sound output"),selection:Binding(get:{h.output},set:{h.setOutput($0);model.announce(h.notice)})) { ForEach(h.audio) { Text(L($0.name)).tag($0.id) } }.labelsHidden(); if let device = h.audio.first(where:{$0.id == h.output}) { Text(LF("%@-channel · %@ kHz",[String(describing:device.channels),String(describing:Int(device.rate/1000))])).font(.system(size:21,weight:.medium,design:.rounded)); Text(L("Live format reported by Core Audio.")).font(.system(size:10)).foregroundStyle(.secondary) }; Button(L("Audio MIDI Setup")) { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Utilities/Audio MIDI Setup.app")) } } }
            DeskCard(title:"YOUR KEYBOARD IS A REMOTE",icon:"keyboard") {
                HStack { VStack(alignment:.leading,spacing:6) { Text(L(model.keyboard.mediaActive ? "Mac volume keys are ready":"Connect your Mac volume keys")).font(.headline); Text(L("Volume, mute and external-screen brightness. Other audio outputs keep their normal Mac behavior.")).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(L(model.keyboard.mediaActive ? "Enabled":"Enable media keys")) { model.keyboard.enableMedia() }.buttonStyle(.borderedProminent) }
                HStack { shortcut("Volume",value:"⌃⌥⌘ ↑ / ↓"); shortcut("Mute",value:"⌃⌥⌘ M"); shortcut("Brightness",value:"⌃⌥⌘ ← / →") }
                Text(L("The Control–Option–Command shortcuts work without Accessibility access. Mac media-key interception requires macOS approval.")).font(.caption2).foregroundStyle(.secondary)
            }
            DeskCard(title:"CHECK YOUR SPEAKERS",icon:"ear") {
                HStack { Button(L("Left speaker")) { TonePlayer.shared.play(channel:0); model.announce("Playing a short, low-level left-channel tone") }; Button(L("Right speaker")) { TonePlayer.shared.play(channel:1); model.announce("Playing a short, low-level right-channel tone") }; Spacer(); Image(systemName:"waveform").foregroundStyle(DeskStyle.brand) }
                Text(L("For everyday listening, compare Standard and Adaptive Sound+ in the monitor’s Sound settings. Keep listening level comfortable; extra sample rate or aggressive bass boost is not proof of better sound.")).font(.caption).foregroundStyle(.secondary)
                Button(L("Open Samsung settings")) { model.section = .remote; if r.connected { r.send("KEY_MENU") } }
            }
        }
    }
    func shortcut(_ title:String,value:String)->some View { VStack(alignment:.leading,spacing:6) { Text(L(title)).font(.caption2).foregroundStyle(.secondary); Text(L(value)).font(.system(size:12,weight:.medium,design:.monospaced)) }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(.primary.opacity(0.025),in:RoundedRectangle(cornerRadius:12)) }
    var remotePage: some View {
        Group {
            DeskCard(title:"SAMSUNG CONNECTION",icon:"wifi") {
                HStack { Circle().fill(r.connected ? DeskStyle.brand:Color.orange).frame(width:8,height:8); Text(L(r.connected ? "Your monitor is connected":"Let’s connect your monitor")).font(.headline); Spacer(); if r.connected { Button(L("Disconnect")) { r.disconnect() } } }
                Text(L(r.status)).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                if !r.connected { HStack { TextField(L("Monitor IP address"),text:Binding(get:{r.host},set:{r.host=$0})).textFieldStyle(.roundedBorder).disabled(r.busy).onSubmit { r.connect() }; Button(L("Find")) { r.discover() }.disabled(r.busy); Button(L(r.busy ? "Cancel":"Connect")) { if r.busy { r.disconnect() } else { r.connect() } }.buttonStyle(.borderedProminent) }; if r.candidates.count > 1 { Picker(L("Found monitors"),selection:Binding(get:{r.host},set:{r.host=$0})) { ForEach(r.candidates,id:\.self) { Text(L($0)).tag($0) } } }; Text(L("On first connection, choose Allow on the monitor’s M8 Studio request.")).font(.caption2).foregroundStyle(.secondary) }
            }
            HStack(alignment:.top,spacing:20) {
                DeskCard(title:"THE LITTLE REMOTE",icon:"appletvremote.gen4") {
                    HStack { remoteKey("Home","house","KEY_HOME"); remoteKey("Settings","gearshape","KEY_MENU"); remoteKey("Source","rectangle.on.rectangle","KEY_SOURCE") }
                    VStack(spacing:7) { remoteKey("Up","chevron.up","KEY_UP").frame(width:90); HStack(spacing:7) { remoteKey("Left","chevron.left","KEY_LEFT"); remoteKey("Select","circle.inset.filled","KEY_ENTER"); remoteKey("Right","chevron.right","KEY_RIGHT") }; remoteKey("Down","chevron.down","KEY_DOWN").frame(width:90) }.padding(.vertical,5)
                    HStack { remoteKey("Back","arrow.uturn.backward","KEY_RETURN"); remoteKey("Play","play.fill","KEY_PLAY"); remoteKey("Pause","pause.fill","KEY_PAUSE") }
                }
                VStack(spacing:16) { DeskCard(title:"A FEW FAVORITE PLACES",icon:"sparkles") { Text(L("Picture settings")).font(.headline); Text(L("Settings → Picture → Expert Settings")).font(.caption).foregroundStyle(.secondary); Divider(); Text(L("Speaker settings")).font(.headline); Text(L("Settings → Sound → Expert Settings")).font(.caption).foregroundStyle(.secondary); Divider(); Text(L("Smart apps")).font(.headline); Text(L("Home opens Samsung’s own app launcher.")).font(.caption).foregroundStyle(.secondary) }; Button(L("Connection help")) { guide() }.buttonStyle(.plain).font(.caption).foregroundStyle(DeskStyle.brand) }.frame(width:190)
            }
        }
    }
    func remoteKey(_ title:String,_ image:String,_ key:String)->some View { Button { r.send(key) } label: { VStack(spacing:6) { Image(systemName:image).font(.system(size:17)); Text(L(title)).font(.system(size:9)) }.frame(maxWidth:.infinity).frame(height:48) }.buttonStyle(.bordered).disabled(!r.connected).accessibilityLabel(L(title)) }
    var scenesPage: some View {
        Group {
            DeskCard(title:"SAVE A GOOD MOMENT",icon:"plus.circle") { HStack { TextField(L("Scene name"),text:$newSceneName).textFieldStyle(.roundedBorder).onSubmit { model.saveScene(newSceneName) }; Button(L("Save current setup")) { model.saveScene(newSceneName) }.buttonStyle(.borderedProminent) }; Text(L("Saves this display’s workspace, visible brightness and available speaker volume. Applying a scene starts with a preview.")).font(.caption).foregroundStyle(.secondary) }
            HStack { TextField(L("Search scenes"),text:$model.search).textFieldStyle(.roundedBorder); Button(L("Import…")) { model.importScenes() }; Button(L("Export…")) { model.exportScenes() }; if model.canRestoreDeleted { Button(L("Undo removal")) { model.restoreDeleted() } } }
            ForEach(model.visibleScenes) { scene in
                HStack(spacing:15) { Image(systemName:scene.icon).font(.system(size:25,weight:.light)).foregroundStyle(DeskStyle.brand).frame(width:36); VStack(alignment:.leading,spacing:5) { Text(scene.localizedName).font(.headline); Text(LF("%@ · %@% brightness",[String(describing:scene.mode?.label ?? L("Current view")),String(describing:Int(scene.brightness*100))])).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { model.favorite(scene) } label: { Image(systemName:scene.favorite ? "star.fill":"star") }.buttonStyle(.plain).foregroundStyle(scene.favorite ? DeskStyle.brand:.secondary).help(L("Favorite scene")); Button(L("Preview")) { model.pendingScene = scene }; Menu { Button(L("Duplicate")) { model.duplicate(scene) }; Button(L("Remove")) { model.delete(scene) } } label: { Image(systemName:"ellipsis") }.menuStyle(.borderlessButton).frame(width:20) }.padding(20).background(DeskStyle.card,in:RoundedRectangle(cornerRadius:20))
            }
            if model.canUndoScene { Button(L("Undo last scene")) { model.undoScene() } }
        }
    }
    var labsPage: some View {
        Group {
            Text(L("Try something a little different.")).font(.system(size:28,weight:.semibold,design:.rounded))
            Text(L("Labs change software behavior, not the monitor’s physical capabilities. Every experiment is optional. Restore all screens stops them.")).font(.callout).foregroundStyle(.secondary)
            if let level = model.builtinBrightness(), h.current?.builtIn == false {
                DeskCard(title:"01 · FOLLOW YOUR MAC",icon:"sun.max.circle") { Toggle(L("Follow MacBook brightness"),isOn:Binding(get:{model.followMac},set:{model.toggleFollow($0)})).toggleStyle(.switch); Text(L("Mirrors the MacBook’s brightness value into the selected external display’s software dimming, with a visible minimum of 20%. This is a value match, not measured luminance matching.")).font(.caption).foregroundStyle(.secondary); Text(LF("MacBook brightness now: %@%",[String(describing:Int(level*100))])).font(.caption2).monospacedDigit().foregroundStyle(DeskStyle.brand) }
            }
            DeskCard(title:"02 · A SOFTER EVENING",icon:"moon.stars") {
                Toggle(L("Schedule evening dimming"),isOn:$model.scheduleEnabled).toggleStyle(.switch).onChange(of:model.scheduleEnabled) { _,_ in model.saveSchedule() }
                HStack { schedulePicker("From",value:$model.scheduleStart); schedulePicker("Until",value:$model.scheduleEnd) }
                DeskSlider(title:"Evening brightness",icon:"moon",value:model.scheduleLevel*100,range:20...100) { model.scheduleLevel = $0/100; model.saveSchedule() }
                Text(L("Uses your Mac’s local clock, including overnight periods. Manual brightness changes pause automation for 30 minutes; the previous level returns outside the schedule.")).font(.caption).foregroundStyle(.secondary)
            }
            DeskCard(title:"03 · THE MENU-BAR DIAL",icon:"computermouse") { Text(L("Hold Option and scroll over the M8 Studio menu-bar icon to adjust brightness in small steps.")).font(.callout); Text(L("The gesture is handled only on Studio’s own icon. No mouse tracking permission is needed.")).font(.caption).foregroundStyle(.secondary) }
            Button(L("Restore all screens & stop experiments")) { model.restore() }.buttonStyle(.borderedProminent)
            if let until = model.autoPausedUntil, until > Date() { Text(LF("Automation paused until %@.",[String(describing:studioTime(until))])).font(.caption).foregroundStyle(.secondary) }
        }
    }
    func schedulePicker(_ title:String,value:Binding<Int>)->some View { Picker(L(title),selection:value) { ForEach(0..<48) { half in let minutes = half*30; Text(L(String(format:"%02d:%02d",minutes/60,minutes%60))).tag(minutes) } }.onChange(of:value.wrappedValue) { _,_ in model.saveSchedule() } }
    var settingsPage: some View {
        Group {
            DeskCard(title:"MAKE IT YOURS",icon:"paintbrush") { Picker(L("Language"),selection:$model.language) { Text("Українська").tag("uk"); Text("English").tag("en") }.pickerStyle(.segmented); Picker(L("Appearance"),selection:$model.appearance) { ForEach(["System","Light","Dark"],id:\.self) { Text(L($0)) } }.pickerStyle(.segmented).onChange(of:model.appearance) { _,_ in model.persistAppearance() }; HStack { TextField(L("Display nickname"),text:$model.rename).textFieldStyle(.roundedBorder).onSubmit { model.renameDisplay() }; Button(L("Save name")) { model.renameDisplay() } }.onAppear { model.renamedFromDevice() }; Toggle(L("Open at login"),isOn:Binding(get:{model.loginEnabled},set:{ _ in model.toggleLogin() })).toggleStyle(.switch) }
            DeskCard(title:"KEYBOARD CONTROLS",icon:"keyboard") { HStack { Text(L(model.keyboard.shortcutStatus)).font(.callout); Spacer(); if model.keyboard.mediaActive { Button(L("Disable media keys")) { model.keyboard.disableMedia() } } else { Button(L("Enable Mac media keys")) { model.keyboard.enableMedia() }.buttonStyle(.borderedProminent) } }; Text(L(model.keyboard.mediaStatus)).font(.caption).foregroundStyle(.secondary); if !model.keyboard.lastInput.isEmpty { Text(L("Last shortcut received") + ": " + model.keyboard.lastInput).font(.caption) }; Text(L("If F1–F12 are standard function keys, hold Fn or Globe for media controls.")).font(.caption).foregroundStyle(.secondary); ForEach(DeskCommand.allCases,id:\.rawValue) { command in HStack { Text(L(commandTitle(command))).font(.caption); Spacer(); Text(L(command.shortcut)).font(.system(size:12,design:.monospaced)).foregroundStyle(.secondary) } }; Text(L("Accessibility access is used only to handle media keys. Studio does not record typed text, screen content or microphone audio.")).font(.caption2).foregroundStyle(.secondary) }
            DeskCard(title:"TAKE CARE OF YOUR DESK",icon:"heart") { HStack { Button(L("Save diagnostics…")) { exportDiagnostics() }; Button(L("User guide")) { guide() }; Button(L("Show activity")) { showActivity.toggle() } }; if showActivity { ForEach(model.activity.prefix(12)) { item in HStack { Text(L(studioTime(item.date))).font(.caption2).foregroundStyle(.secondary); Text(L(item.text)).font(.caption) } } }; Button(L("Forget Samsung pairing")) { r.forget(); model.announce(r.status) }.buttonStyle(.plain).font(.caption).foregroundStyle(.secondary) }
            Text(L("M8 Studio · Samsung display tools for your Mac. Local controls, local preferences, no analytics.")).font(.caption2).foregroundStyle(.secondary)
        }
    }
    func commandTitle(_ command:DeskCommand)->String { switch command { case .volumeUp:return "Volume up"; case .volumeDown:return "Volume down"; case .mute:return "Mute / unmute"; case .brighter:return "Brighter"; case .dimmer:return "Dimmer"; case .restore:return "Restore screens"; case .openStudio:return "Open Studio" } }
    func scenePreview(_ scene:DeskScene)->some View { VStack(alignment:.leading,spacing:18) { Image(systemName:scene.icon).font(.largeTitle).foregroundStyle(DeskStyle.brand); Text(scene.localizedName).font(.system(size:27,weight:.semibold,design:.rounded)); Text(LF("%@\nBrightness %@%%@",[String(describing:scene.mode?.label ?? L("Keep current view")),String(describing:Int(scene.brightness*100)),String(describing:scene.volume.map { "\n"+LF("Monitor volume %@%",[String(Int($0))]) } ?? "\n"+L("Keep current volume"))])).font(.callout).lineSpacing(8); Text(L("Display mode changes have 15-second recovery. Your color profile is preserved.")).font(.caption).foregroundStyle(.secondary); if let issue = model.sceneIssue(scene) { Text(L(issue)).font(.caption).foregroundStyle(.orange) }; HStack { Button(L("Cancel")) { model.pendingScene = nil }; Spacer(); Button(L("Apply scene")) { model.applyScene(scene) }.buttonStyle(.borderedProminent).disabled(model.sceneIssue(scene) != nil) } }.padding(30).frame(width:420) }
    func profilePreview(_ profile:DisplayProfile)->some View { VStack(alignment:.leading,spacing:18) { Image(systemName:"paintpalette").font(.largeTitle).foregroundStyle(DeskStyle.brand); Text(L(profile.name)).font(.title2).fontWeight(.semibold); Text(L(profile.detail)).font(.callout); Text(L("This changes how macOS converts color for the selected screen. Match the profile to the panel’s actual picture settings. A generic profile cannot establish measured accuracy; you can undo the change.")).font(.caption).foregroundStyle(.secondary); HStack { Button(L("Cancel")) { pendingProfile = nil }; Spacer(); Button(L("Apply profile")) { _ = model.colors.apply(profile); model.announce(model.colors.status); pendingProfile = nil }.buttonStyle(.borderedProminent) } }.padding(30).frame(width:440) }
    func guide() { if let url = Bundle.main.url(forResource:"User Guide",withExtension:"html",subdirectory:model.language+".lproj") ?? Bundle.main.url(forResource:"User Guide",withExtension:"html") { NSWorkspace.shared.open(url) } }
    func exportDiagnostics() { let panel = NSSavePanel(); panel.nameFieldStringValue = "M8 Studio Diagnostics.txt"; if panel.runModal() == .OK, let url = panel.url { do { try (h.diagnostics()+"\nRemote: \(r.status)\nMedia keys: \(model.keyboard.mediaActive)\n").write(to:url,atomically:true,encoding:.utf8); model.announce("Diagnostics saved") } catch { model.announce("Could not save diagnostics") } } }
}
