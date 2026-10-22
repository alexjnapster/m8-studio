import AppKit
import Combine
import CoreAudio

@MainActor func validateSceneRecovery(to path:String) async {
    let model = StudioState.shared.model; let h = model.hardware
    var lines = ["M8 Studio scene recovery integration", "Date: \(ISO8601DateFormatter().string(from:Date()))"]
    func check(_ condition:Bool,_ label:String) { lines.append("\(condition ? "PASS":"FAIL") — \(label)") }
    let selected = h.selected; let linked = model.linked; let schedule = model.scheduleEnabled
    let levels = Dictionary(uniqueKeysWithValues:h.displays.map { ($0.id,h.brightness(for:$0.id)) })
    let language = model.language; model.language = "uk"; model.linked = true; model.scheduleEnabled = false
    defer {
        h.revertMode(); h.select(selected)
        for (id,level) in levels { h.shade(level,on:id) }
        model.linked = linked; model.scheduleEnabled = schedule; model.language = language
    }
    let originalScenes = model.scenes
    defer { model.scenes = originalScenes }
    var searchFixture = model.capture(name:"Everyday"); searchFixture.builtInName = "Everyday"
    model.scenes.append(searchFixture)
    let originalSearch = model.search
    if let everyday = model.scenes.first(where:{$0.builtInName == "Everyday" && $0.displayUUID == h.current?.uuid}) {
        model.search = "  щодня  "
        check(model.visibleScenes.contains(where:{$0.id == everyday.id}),"Ukrainian scene search finds the visible translated name and trims spaces")
        model.language = "en"; model.search = "EVERYDAY"
        check(model.visibleScenes.contains(where:{$0.id == everyday.id}),"English scene search remains case-insensitive")
        model.language = "uk"
    } else { check(false,"Built-in scene available for bilingual search acceptance") }
    model.search = originalSearch
    check(studioTime(Date()).range(of:"^[0-9]{1,2}:[0-9]{2}$",options:.regularExpression) != nil,"Ukrainian activity times use a localized 24-hour clock")
    h.refresh()
    var redundantInvalidations = 0
    let observation = h.objectWillChange.sink { redundantInvalidations += 1 }
    h.refresh(); h.refresh()
    check(redundantInvalidations == 0,"Unchanged hardware polls do not invalidate the interface")
    observation.cancel()
    let originalOutput = h.output
    if let otherOutput = h.audio.first(where:{$0.id != originalOutput}) {
        var address = AudioObjectPropertyAddress(mSelector:kAudioHardwarePropertyDefaultOutputDevice,mScope:kAudioObjectPropertyScopeGlobal,mElement:0)
        var changedOutput = otherOutput.id
        let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,UInt32(MemoryLayout<AudioDeviceID>.size),&changedOutput)
        try? await Task.sleep(for:.milliseconds(400))
        check(status == noErr && h.output == otherOutput.id,"Core Audio route notifications update the selected output without polling")
        var restoredOutput = originalOutput
        let restored = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),&address,0,nil,UInt32(MemoryLayout<AudioDeviceID>.size),&restoredOutput)
        try? await Task.sleep(for:.milliseconds(400))
        check(restored == noErr && h.output == originalOutput,"Output observation check restores the original audio route")
    } else { lines.append("SKIP — No alternate audio output connected for notification integration check") }
    var scene = model.capture(name:"Перевірка відновлення"); scene.volume = nil; scene.brightness = 0.93
    let beforeMode = h.current?.mode?.ioDisplayModeID
    if var unsupported = scene.mode {
        unsupported.width = 1234; unsupported.height = 777; unsupported.pixels = 2468
        var invalid = scene; invalid.mode = unsupported; invalid.brightness = 0.51
        check(invalid.valid,"Unavailable scene remains structurally valid, exercising capability preflight")
        model.applyScene(invalid)
        check(levels.allSatisfy { abs(h.brightness(for:$0.key)-$0.value)<0.001 },"Unavailable saved mode does not dim either screen")
        check(h.current?.mode?.ioDisplayModeID == beforeMode && !model.canUndoScene,"Rejected scene preserves mode and undo state")
        check(model.toast == "This scene’s saved display mode is unavailable. No settings were changed.","Rejected scene provides an actionable capability message")
    }
    model.applyScene(scene)
    check(abs(h.brightness(for:selected)-0.93)<0.001,"Scene sets its own display brightness")
    check(h.displays.filter{$0.id != selected}.allSatisfy { abs(h.brightness(for:$0.id)-(levels[$0.id] ?? 1))<0.001 },"Scene does not dim other screens when manual linking is enabled")
    check(model.sceneIsActive(scene),"Active-scene indication requires actual matching display settings")
    h.shade(0.92)
    check(!model.sceneIsActive(scene),"Changed brightness removes the active-scene indication")
    h.shade(scene.brightness)
    check(model.canUndoScene && model.linked,"Scene preserves the link preference and records undo")
    if let other = h.displays.first(where:{$0.id != selected}) {
        model.selectDisplay(other.id)
        let otherLevel = h.dim
        model.undoScene()
        check(abs(h.dim-otherLevel)<0.001 && abs(h.brightness(for:selected)-0.93)<0.001,"Undo on another selected display leaves both screens unchanged")
        check(model.canUndoScene && model.toast == "Select the original scene’s display before undoing","Wrong-display undo remains available with display-selection guidance")
        model.selectDisplay(selected); model.undoScene()
        check(abs(h.dim-(levels[selected] ?? 1))<0.001 && !model.canUndoScene,"Undo succeeds after reselecting the original screen")
    } else { lines.append("SKIP — Second display absent; wrong-display recovery requires connected hardware") }
    if let current = h.current?.mode, let alternate = model.activeModes.first(where:{$0.ioDisplayModeID != current.ioDisplayModeID && $0.width == 1920}) {
        h.applyMode(alternate)
        check(h.rollbackSeconds > 0,"Real mode preview starts for overlapping-scene check")
        let level = h.dim; model.applyScene(scene)
        check(abs(h.dim-level)<0.001 && model.sceneIssue(scene) == "Keep or revert the current display preview first","A pending display preview prevents competing scene changes")
        h.revertMode()
        check(h.current?.mode?.ioDisplayModeID == current.ioDisplayModeID,"Targeted mode check restores the exact original mode")
    } else { lines.append("SKIP — No suitable alternate mode reported for preview integration") }
    check(L("Select the original scene’s display before undoing") == "Щоб скасувати сцену, виберіть екран, до якого її застосовано","Recovery guidance is localized in Ukrainian")
    model.autoPausedUntil = Date().addingTimeInterval(-1)
    try? await Task.sleep(for:.milliseconds(1200))
    check(model.autoPausedUntil == nil,"Expired automation pause clears itself without relying on redundant hardware redraws")
    try? lines.joined(separator:"\n").write(toFile:path,atomically:true,encoding:.utf8)
    print(lines.joined(separator:"\n")); fflush(stdout)
}
