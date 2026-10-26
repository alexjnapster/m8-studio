import SwiftUI
import AppKit

extension DeskModel {
    var savedCanvas:SavedCanvas? { hardware.current.flatMap { canvasRecovery.saved($0.uuid) } }
    var savedCanvasMode:CGDisplayMode? {
        guard let saved = savedCanvas else { return nil }
        return favoriteEligibleModes.first { saved.mode.matches(FavoriteDisplayMode($0)) }
    }
    var savedCanvasProfile:DisplayProfile? {
        guard let path = savedCanvas?.profilePath else { return nil }
        return colors.profiles.first { $0.url.standardizedFileURL.path == URL(fileURLWithPath:path).standardizedFileURL.path }
    }
    func rememberCanvas() {
        guard !virtualCanvas.engaged, hardware.rollbackSeconds == 0, let display = hardware.current, let mode = display.mode else { return }
        if canvasRecovery.save(SavedCanvas(mode:FavoriteDisplayMode(mode),profilePath:colors.currentURL?.path,
                                          profileName:colors.currentName),for:display.uuid) {
            announce("Canvas saved. Reconnect recovery will ask before changing anything.")
        }
    }
    func previewSavedCanvas() { if let mode = savedCanvasMode { applyMode(mode) } }
    func restoreSavedCanvasProfile() {
        guard !virtualCanvas.engaged, hardware.rollbackSeconds == 0, let profile = savedCanvasProfile else { return }
        _ = colors.apply(profile); announce(colors.status)
    }
    func physicalScreen(_ display:DisplayInfo) -> TextSizeMatch.Screen? {
        guard let mode = display.mode else { return nil }
        let size = CGDisplayScreenSize(display.id)
        let rotation = CGDisplayRotation(display.id).truncatingRemainder(dividingBy:180)
        let swapped = abs(rotation-90) < 1
        return TextSizeMatch.Screen(widthMM:swapped ? size.height:size.width,
                                    heightMM:swapped ? size.width:size.height,mode:FavoriteDisplayMode(mode))
    }
    var textSizeReference:DisplayInfo? {
        hardware.displays.first { $0.id != hardware.selected && $0.builtIn && CGDisplayIsInMirrorSet($0.id) == 0 } ??
        hardware.displays.first { $0.id != hardware.selected && CGDisplayIsInMirrorSet($0.id) == 0 }
    }
    var matchingTextMode:CGDisplayMode? {
        guard let display = hardware.current, CGDisplayIsInMirrorSet(display.id) == 0,
              let reference = textSizeReference, let a = physicalScreen(reference), let b = physicalScreen(display),
              let desired = TextSizeMatch.best(reference:a,target:b,candidates:favoriteEligibleModes.map(FavoriteDisplayMode.init)) else { return nil }
        return favoriteEligibleModes.first { desired.matches(FavoriteDisplayMode($0)) }
    }
    var brightnessProvider:String { hardware.ddc["luminance"] != nil ? "DDC backlight available · software dimming selected":"Software dimming · backlight unchanged" }
    var volumeProvider:String {
        if samsungIsOutput && remote.mediaAvailable { return "Linked Samsung network volume · live readback" }
        if hardware.ddc["volume"] != nil { return "DDC volume available in Hardware controls" }
        return samsungIsOutput ? "Samsung volume unavailable · reconnect the service":"Mac volume keys use the selected audio output"
    }
}

struct DisplayToolsView:View {
    @ObservedObject var model:DeskModel
    var body:some View {
        VStack(spacing:18) {
            DeskCard(title:"YOUR CONTROL PATH",icon:"point.3.connected.trianglepath.dotted") {
                status("Brightness",value:model.brightnessProvider)
                status("Volume",value:model.volumeProvider)
                status("Sound processing",value:model.sound.running ? "Local stereo PCM EQ":"Original audio · EQ off")
                Text(L("A connected remote is not proof of every hardware control. Only verified controls are offered.")).font(.caption).foregroundStyle(.secondary)
            }
            DeskCard(title:"MATCH TEXT SIZE",icon:"textformat.size") {
                if let reference = model.textSizeReference, let mode = model.matchingTextMode {
                    Text(LF("Reference: %@",[reference.name])).font(.callout)
                    Text(modeLabel(mode)).font(.system(.callout,design:.monospaced))
                    Button(L("Preview matching size")) { model.applyMode(mode) }
                        .disabled(model.virtualCanvas.engaged || model.hardware.rollbackSeconds > 0 || mode.ioDisplayModeID == model.hardware.current?.mode?.ioDisplayModeID)
                    Text(L("An estimate from reported screen dimensions. Compare at the same viewing distance; no change is made until you preview.")).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text(L("Connect a second extended display with usable physical dimensions to compare text size.")).font(.caption).foregroundStyle(.secondary)
                }
            }
            DeskCard(title:"RECONNECT RECOVERY",icon:"arrow.triangle.2.circlepath") {
                if let display = model.hardware.current {
                    if let saved = model.savedCanvas {
                        if model.canvasRecovery.pending.contains(display.uuid) {
                            Label(L("This display returned. Review your saved canvas."),systemImage:"display.trianglebadge.exclamationmark").font(.callout)
                        }
                        Text(LF("Saved size: %@ × %@",[String(saved.mode.width),String(saved.mode.height)])).font(.callout)
                        HStack {
                            Button(L("Preview saved size")) { model.previewSavedCanvas() }
                                .disabled(model.virtualCanvas.engaged || model.savedCanvasMode == nil || model.hardware.rollbackSeconds > 0 ||
                                          saved.mode.matches(model.hardware.current?.mode.map(FavoriteDisplayMode.init) ?? saved.mode))
                            if saved.profilePath != nil {
                                Button(L("Restore saved profile")) { model.restoreSavedCanvasProfile() }
                                    .disabled(model.virtualCanvas.engaged || model.savedCanvasProfile == nil || model.hardware.rollbackSeconds > 0 ||
                                              model.colors.currentURL?.standardizedFileURL.path == saved.profilePath)
                            }
                        }.controlSize(.small)
                        if model.savedCanvasMode == nil { Text(L("Saved mode is unavailable on this connection.")).font(.caption).foregroundStyle(.secondary) }
                        if let name = saved.profileName { Text(LF("Saved profile: %@",[name])).font(.caption).foregroundStyle(.secondary) }
                        if saved.profilePath != nil && model.savedCanvasProfile == nil { Text(L("Saved profile is not available for this display. Import it again if needed.")).font(.caption).foregroundStyle(.secondary) }
                        HStack {
                            Button(L("Update saved canvas")) { model.rememberCanvas() }.disabled(model.virtualCanvas.engaged || model.hardware.rollbackSeconds > 0)
                            Button(L("Forget saved canvas")) { model.canvasRecovery.forget(display.uuid) }
                            if model.canvasRecovery.pending.contains(display.uuid) { Button(L("Dismiss")) { model.canvasRecovery.dismiss(display.uuid) } }
                        }.controlSize(.small)
                    } else {
                        Button(L("Remember this canvas")) { model.rememberCanvas() }.disabled(model.virtualCanvas.engaged || model.hardware.rollbackSeconds > 0)
                    }
                    Text(L("Saves size and profile for this display. On reconnect, Studio offers recovery; it never changes a mode, profile or arrangement automatically.")).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
    func status(_ label:String,value:String)->some View {
        HStack(alignment:.firstTextBaseline) { Text(L(label)).font(.caption.bold()); Spacer(); Text(L(value)).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
            .accessibilityElement(children:.combine)
    }
}
