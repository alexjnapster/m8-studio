import SwiftUI
import AppKit
import CoreAudio

enum SetupStage: Int, CaseIterable, Identifiable {
    case display, picture, sound, keys, finish
    var id: Int { rawValue }
    var title: String {
        switch self { case .display: return "Your display"; case .picture: return "Picture & text"; case .sound: return "Your sound"; case .keys: return "Your keyboard"; case .finish: return "Your overview" }
    }
    var icon: String {
        switch self { case .display: return "display"; case .picture: return "textformat.size"; case .sound: return "speaker.wave.2"; case .keys: return "keyboard"; case .finish: return "sparkles" }
    }
}

extension DeskModel {
    @discardableResult func finishGuidedSetup() -> Bool {
        guard hardware.rollbackSeconds == 0 else { announce("Keep or revert the current display preview first"); return false }
        UserDefaults.standard.set(true,forKey:"guidedSetup.v1.completed")
        dismissWelcome(); section = .overview
        announce("Setup saved. You can reopen Setup whenever you need it.")
        return true
    }
}

struct GuidedSetup: View {
    @ObservedObject var model: DeskModel
    var h: Hardware { model.hardware }
    private var stage: SetupStage { model.setupStage }
    private let soundURL = URL(fileURLWithPath:"/Applications/M8 Studio Sound.app")
    private var soundInstalled: Bool { FileManager.default.fileExists(atPath:soundURL.path) }
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack {
                VStack(alignment:.leading,spacing:7) {
                    Text(L("A GOOD START")).font(.caption.bold()).tracking(2).foregroundStyle(DeskStyle.brand)
                    Text(L(stage.title)).font(.system(size:30,weight:.semibold,design:.rounded))
                    Text(L("A few clear choices. Keep what already works.")).font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(L("Language"),selection:$model.language) { Text("Українська").tag("uk"); Text("English").tag("en") }.labelsHidden().frame(width:150)
            }
            HStack(spacing:8) {
                ForEach(SetupStage.allCases) { step in
                    Button { model.setupStage = step } label: {
                        VStack(spacing:7) {
                            Image(systemName:step.icon).font(.title3)
                            Text(L(step.title)).font(.caption).multilineTextAlignment(.center)
                        }.frame(maxWidth:.infinity,minHeight:58).padding(8)
                        .foregroundStyle(step == stage ? DeskStyle.brand:.secondary)
                        .background(step == stage ? DeskStyle.brand.opacity(0.12):Color.primary.opacity(0.035),in:RoundedRectangle(cornerRadius:13))
                    }.buttonStyle(.plain).accessibilityLabel(LF("Step %@: %@",[String(step.rawValue+1),L(step.title)]))
                    .accessibilityAddTraits(step == stage ? .isSelected:[])
                }
            }
            Group {
                switch stage {
                case .display: displayStep
                case .picture: pictureStep
                case .sound: soundStep
                case .keys: keysStep
                case .finish: finishStep
                }
            }
            Divider()
            HStack {
                Button(L("Later")) { model.section = .overview }
                Spacer()
                if stage.rawValue > 0 { Button(L("Back")) { model.setupStage = SetupStage(rawValue:stage.rawValue-1)! } }
                if stage == .finish {
                    Button(L("Finish for now")) { model.finishGuidedSetup() }.buttonStyle(.borderedProminent).disabled(h.rollbackSeconds > 0)
                } else {
                    Button(L("Continue")) { model.setupStage = SetupStage(rawValue:stage.rawValue+1)! }.buttonStyle(.borderedProminent)
                }
            }
            Text(L("Only buttons you choose change settings. Skipping a step is fine; Setup stays in the sidebar.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var displayStep: some View {
        DeskCard(title:"START WITH THE RIGHT SCREEN",icon:"display") {
            if h.displays.isEmpty {
                Text(L("Connect your display, then refresh to find it.")).font(.callout)
            } else {
                Picker(L("Selected display"),selection:Binding(get:{h.selected},set:{model.selectDisplay($0)})) { ForEach(h.displays) { display in Text(display.name).tag(display.id) } }
                if let display = h.current {
                    Text(display.name).font(.headline)
                    Text(display.mode.map(modeLabel) ?? L("Mode unavailable")).font(.callout).monospacedDigit()
                    Text(L(display.builtIn ? "This is your Mac’s built-in screen. Connect or select an external display to set it up.":"This display is selected. Picture changes apply only to it.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack { Button(L("Refresh displays")) { model.refresh() }; Button(L("Find my screens")) { model.identify() }.disabled(h.displays.isEmpty) }
        }
    }
    private var pictureStep: some View {
        VStack(alignment:.leading,spacing:16) {
            DeskCard(title:"COMFORTABLE TEXT, HONEST COLOR",icon:"textformat.size") {
                Text(L("Choose a readable workspace. A HiDPI mode can improve text rendering; its render buffer may be larger than the physical panel.")).font(.callout)
                if let mode = h.current?.mode { row("Current view",modeLabel(mode)); row("Rendering",mode.pixelWidth > mode.width ? L("HiDPI"):L("1× rendering")) }
                row("Current profile",model.colors.currentName)
                Text(L("Keep this display’s original profile unless you have a measured ICC for this exact panel. Setup never applies another monitor’s calibration.")).font(.caption).foregroundStyle(.secondary)
                if model.isM8, let display = h.current, CGDisplayModelNumber(display.id) == 0x7267 {
                    Text(L("M80B USB-C: use the monitor’s High Resolution USB-C preference for 4K60. External HDR is unavailable on this path.")).font(.caption).foregroundStyle(.secondary)
                }
                Button(L("Open picture controls")) { model.section = .display }
            }
            ScalingInspector(model:model)
            if h.rollbackSeconds > 0 {
                Text(L("A picture preview is pending. Keep or revert it using the recovery bar before finishing Setup.")).font(.caption).foregroundStyle(.orange)
            }
        }
    }
    private var soundStep: some View {
        DeskCard(title:"PUT SOUND WHERE YOU WANT IT",icon:"speaker.wave.2") {
            Picker(L("Sound output"),selection:Binding(get:{h.output},set:{h.setOutput($0);model.announce(h.notice)})) { ForEach(h.audio) { Text($0.name).tag($0.id) } }
            Text(L(model.samsungIsOutput ? "Monitor audio selected":"Other audio output")).font(.headline)
            if let output = h.audio.first(where:{$0.id == h.output}) { Text(LF("%@-channel · %@ kHz",[String(output.channels),String(Int(output.rate/1000))])).font(.caption).monospacedDigit() }
            Text(L("Choosing an output changes where your Mac plays sound. Mac speakers and headphones keep their normal volume controls.")).font(.caption).foregroundStyle(.secondary)
            if model.samsungIsOutput {
                Text(L(model.remote.mediaAvailable ? "Monitor volume service is ready.":"Connect the monitor’s volume service to use its volume keys.")).font(.callout)
                if !model.remote.mediaAvailable {
                    HStack {
                        Button(L("Connect volume controls")) { model.remote.connect(remoteControl:false) }.disabled(model.remote.busy || !localHost(model.remote.host))
                        Button(L("Connection help")) { model.section = .remote }
                    }
                }
            }
            Divider()
            Text(L("For fuller sound, try Bass + or Warmth in the separate sound module. Compare with bypass at the same perceived loudness.")).font(.callout)
            if soundInstalled {
                Button(L("Open sound presets & EQ")) { NSWorkspace.shared.open(soundURL) }
            } else {
                Link(L("Get the sound module"),destination:URL(string:"https://github.com/alexjnapster/m8-studio/releases/tag/sound-v0.1.0-beta.1")!)
            }
            Text(L("EQ processes stereo PCM. It does not enable Atmos or replace measured speaker calibration.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var keysStep: some View {
        DeskCard(title:"FAMILIAR KEYS, CLEAR FEEDBACK",icon:"keyboard") {
            Text(L(model.keyboard.mediaStatus)).font(.headline)
            Text(L(model.keyboardRouteHint)).font(.callout)
            if !model.keyboard.mediaActive {
                Button(L("Enable Mac media keys")) { model.keyboard.enableMedia() }.buttonStyle(.borderedProminent)
            }
            DisclosureGroup(L("If keys do not respond")) {
                Text(L("macOS permission is requested only when you enable media keys. If a rebuilt app is denied despite an enabled entry, remove the stale entry and add the exact installed app again in Privacy & Security.")).font(.caption).foregroundStyle(.secondary).padding(.top,8)
            }
            Text(L("Try Volume Down then Volume Up with your monitor selected for sound. Try mute twice. If F-keys are standard function keys, hold Fn or Globe.")).font(.callout)
            Text(L("Media keys are optional. You can use the menu and global shortcuts too.")).font(.caption).foregroundStyle(.secondary)
            if !model.keyboard.lastMediaInput.isEmpty { row("Last media key seen",model.keyboard.lastMediaInput) }
            if !model.keyboard.shortcutStatus.isEmpty { Text(L(model.keyboard.shortcutStatus)).font(.caption).foregroundStyle(.secondary) }
            Text(L("Fallback shortcuts: Control–Option–Command + ↑ / ↓ for volume, M for mute.")).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var finishStep: some View {
        DeskCard(title:"YOUR SETUP AT A GLANCE",icon:"sparkles") {
            row("Selected display",h.current?.name ?? L("No display"))
            row("Current view",h.current?.mode.map(modeLabel) ?? L("Mode unavailable"))
            row("Current profile",model.colors.currentName)
            row("Sound output",h.audio.first(where:{$0.id == h.output})?.name ?? L("No sound output"))
            row("Media keys",L(model.keyboard.mediaActive ? "Media keys are active":"Media keys are disabled"))
            row("Sound module",L(soundInstalled ? "Installed":"Not installed"))
            Divider()
            Text(L("Keep a favorite setup as a scene, or keep exploring. Finishing does not apply a picture mode, profile, preset or audio route.")).font(.callout)
            HStack {
                Button(L("Scenes")) { model.section = .scenes }
                Button(L("Desktop controls")) { model.onToggleDesktopCard?() }
            }
            if h.rollbackSeconds > 0 { Text(L("Keep or revert the current display preview first")).font(.caption).foregroundStyle(.orange) }
        }
    }
    private func row(_ title:String,_ value:String)->some View {
        HStack(alignment:.firstTextBaseline,spacing:18) { Text(L(title)).foregroundStyle(.secondary); Spacer(minLength:12); Text(value).multilineTextAlignment(.trailing).textSelection(.enabled) }.font(.callout)
    }
}
