import SwiftUI
import AppKit

final class SoundDelegate: NSObject, NSApplicationDelegate {
    var model: SoundModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { model?.shutdown(); return .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
}

struct SoundMenu: View {
    @ObservedObject var model: SoundModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.route)
        Text(model.busy ? model.t("Перемикання…", "Switching…") : model.running ? model.t("EQ активний", "EQ active") : model.t("EQ вимкнено", "EQ off"))
        Divider()
        ForEach(SoundPreset.all) { p in Button(model.english ? p.en : p.uk) { model.choose(p); if model.running { model.apply() } }.disabled(model.busy) }
        Divider()
        if model.canBypass {
            Button(model.t("Оригінал / Bypass", "Original / Bypass")) { model.stop() }
                .keyboardShortcut(".", modifiers: .command)
        } else {
            Button(model.t("Увімкнути EQ", "Enable EQ")) { model.apply() }.disabled(model.busy || !model.eligible)
        }
        Button(model.t("Показати еквалайзер", "Show equalizer")) { openWindow(id:"sound"); NSApp.activate(ignoringOtherApps:true) }
        Button(model.t("Вийти", "Quit")) { NSApp.terminate(nil) }
    }
}

@main struct M8SoundApp: App {
    @NSApplicationDelegateAdaptor(SoundDelegate.self) var delegate
    @StateObject private var model = SoundModel()
    var body: some Scene {
        Window("M8 Studio Sound",id:"sound") {
            ScrollView { SoundView(model:model) }.frame(minWidth:600,minHeight:720).onAppear { delegate.model=model }
        }.defaultSize(width:650,height:850)
        .commands { CommandMenu(model.t("Звук", "Sound")) { SoundMenu(model:model) } }
        MenuBarExtra("M8 Studio Sound",systemImage:"waveform.circle") {
            SoundMenu(model:model)
        }
    }
}
