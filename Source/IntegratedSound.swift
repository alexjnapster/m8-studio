import SwiftUI

/// Shared engine, settings and actions: the popover never owns a second session.
struct IntegratedSoundQuickView: View {
    @ObservedObject var sound: SoundModel
    var openStudio: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {
                Label(sound.t("Характер звуку", "Sound character"),systemImage:"waveform.path").font(.headline)
                Spacer()
                Text(sound.busy ? sound.t("Перемикання…", "Switching…") : sound.running ? "EQ ON" : "EQ OFF")
                    .font(.caption2.bold()).foregroundStyle(sound.running ? DeskStyle.brand:.secondary)
            }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:8) {
                ForEach(SoundPreset.all) { preset in
                    Button {
                        sound.choose(preset)
                        if sound.running { sound.apply() }
                    } label: {
                        HStack(spacing:6) {
                            Text(sound.english ? preset.en:preset.uk).lineLimit(1)
                            Spacer(minLength:0)
                            if sound.selectedPreset == preset.id { Image(systemName:"checkmark.circle.fill") }
                        }.font(.system(size:11,weight:.medium)).padding(10)
                        .frame(maxWidth:.infinity,alignment:.leading)
                        .background(DeskStyle.brand.opacity(sound.selectedPreset == preset.id ? 0.15:0.045),in:RoundedRectangle(cornerRadius:10))
                    }.buttonStyle(.plain).disabled(sound.busy)
                    .accessibilityIdentifier("sound.preset." + preset.id)
                }
            }
            if sound.selectedPreset == "custom" {
                Label(sound.t("Власний еквалайзер", "Custom equalizer"),systemImage:"slider.horizontal.3")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !sound.stereoSummary.isEmpty {
                Label(sound.stereoSummary,systemImage:"slider.horizontal.3").font(.caption2).foregroundStyle(.secondary)
            }
            HStack {
                Button(sound.running ? sound.t("Застосувати", "Apply EQ"):sound.t("Увімкнути EQ", "Enable EQ")) { sound.apply() }
                    .buttonStyle(.borderedProminent)
                    .disabled(sound.busy || !sound.eligible || (sound.running && !sound.dirty))
                    .accessibilityIdentifier("sound.enable")
                Button(sound.t("Оригінал", "Bypass")) { sound.stop() }
                    .disabled(!sound.canBypass).keyboardShortcut(".",modifiers:.command)
                    .accessibilityIdentifier("sound.bypass")
                Spacer()
                Button(action:openStudio) { Image(systemName:"slider.vertical.3") }
                    .help(sound.t("Відкрити 8-смуговий EQ", "Open eight-band EQ"))
                    .accessibilityLabel(sound.t("Відкрити еквалайзер", "Open equalizer"))
            }.controlSize(.small)
            if !sound.message.isEmpty {
                Text(sound.message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            } else {
                Text(sound.dirty ? (sound.running ? sound.t("Натисніть «Застосувати», щоб почути зміни", "Press Apply EQ to hear changes") : sound.t("Збережено · увімкніть EQ, щоб почути зміни", "Saved · enable EQ to hear changes")) : sound.t("Стерео PCM · захист піків · автоматичний запас", "Stereo PCM · peak protection · automatic headroom"))
                    .font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            if !sound.eligible {
                Text(sound.t("EQ доступний для динаміків Samsung через HDMI або DisplayPort.", "EQ requires Samsung speakers over HDMI or DisplayPort."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(14).background(DeskStyle.brand.opacity(0.045),in:RoundedRectangle(cornerRadius:16))
    }
}
