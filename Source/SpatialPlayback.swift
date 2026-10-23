import SwiftUI
import AppKit
import CoreAudio

// A playback-path assistant, not a codec switch. Core Audio channel count alone
// cannot establish Atmos support or determine what another app is rendering.
struct SpatialPlaybackCard:View {
    @ObservedObject var model:DeskModel
    @ViewState var expanded = false
    var body:some View {
        DeskCard(title:"SPATIAL AUDIO & ATMOS",icon:"waveform.circle") {
            if model.hardware.current?.builtIn == false {
                Toggle(L("Atmos option is present in this monitor’s menu"),isOn:Binding(get:{model.monitorAtmosMenuConfirmed},set:{model.monitorAtmosMenuConfirmed = $0})).toggleStyle(.switch).controlSize(.small)
                if model.monitorAtmosMenuConfirmed { Label(L("Monitor option confirmed by you · on/off state is not read by Studio"),systemImage:"checkmark.seal").font(.caption).foregroundStyle(DeskStyle.brand) }
            }
            if let output = model.hardware.audio.first(where:{$0.id == model.hardware.output}) {
                Text(output.name).font(.headline)
                Text(LF("Current output: %@ channels · %@ Hz",[String(output.channels),String(Int(output.rate))])).font(.caption).monospacedDigit()
                Text(L(output.transport == kAudioDeviceTransportTypeHDMI ? "HDMI route detected. Atmos passthrough still requires a compatible receiver, adapter and player.":output.transport == kAudioDeviceTransportTypeDisplayPort ? "DisplayPort audio route detected. This does not confirm HDMI Atmos passthrough.":"This output’s channel count does not establish Spatial Audio or Atmos support.")).font(.caption).foregroundStyle(.secondary)
            } else { Text(L("No sound output is currently available.")).font(.caption) }
            DisclosureGroup(L("Playback setup"),isExpanded:$expanded) {
              VStack(alignment:.leading,spacing:8) {
                Text(L("On the monitor: Sound → Expert Settings → Dolby Atmos, if offered by this model and input. This is a monitor-side effect; Studio cannot read or switch it through the confirmed volume service.")).font(.caption)
                Text(L("On Mac: Music → Settings → Playback. Use Dolby Atmos with a supported output. Prefer HDMI Passthrough requires Apple silicon, a supported HDMI connection and a Dolby-capable receiver.")).font(.caption)
                Text(L("Apple Spatial Audio with head tracking uses compatible headphones and supported playback apps. It is not a global effect Studio can enable on Samsung speakers.")).font(.caption)
              }.foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true).padding(.top,10)
            }
            HStack {
                if model.hardware.current?.builtIn == false {
                    Button(L("Monitor sound setup")) { model.section = .remote; model.onOpenStudio?(); if model.remote.connected { model.remote.send("KEY_MENU") } }
                }
                Button(L("Open Music")) { NSWorkspace.shared.open(URL(fileURLWithPath:"/System/Applications/Music.app")) }
            }.font(.caption)
            HStack {
                Link(L("Apple playback setup"),destination:URL(string:"https://support.apple.com/guide/music/playback-settings-musdf855a1b/mac")!)
                Link(L("Spatial Audio compatibility"),destination:URL(string:"https://support.apple.com/en-us/109354")!)
            }.font(.caption)
        }
    }
}
