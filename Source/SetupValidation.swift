import AppKit
import SwiftUI

@MainActor func validateSetup(model:DeskModel,to directory:String) async {
    let folder = URL(fileURLWithPath:directory,isDirectory:true)
    try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    let selected = model.hardware.selected, output = model.hardware.output
    let profile = model.colors.currentURL
    let language = model.language, appearance = model.appearance, stage = model.setupStage
    let completed = UserDefaults.standard.object(forKey:"guidedSetup.v1.completed")
    var lines = ["Guided setup: native layouts and non-mutation/recovery checks. No mode, profile, sound-output or permission actions invoked."]
    defer { model.language = language; model.appearance = appearance; model.setupStage = stage }
    let window = NSWindow(contentRect:CGRect(x:100,y:100,width:740,height:800),styleMask:[.titled],backing:.buffered,defer:false)
    window.isReleasedWhenClosed = false
    for (locale,style) in [("uk","Light"),("uk","Dark"),("en","Light"),("en","Dark")] {
        model.language = locale; model.appearance = style
        for step in SetupStage.allCases {
            model.setupStage = step
            let root = GuidedSetup(model:model).padding(24).frame(width:740).background(DeskStyle.canvas)
                .preferredColorScheme(style == "Dark" ? .dark:.light)
            let view = NSHostingView(rootView:root); window.contentView = view
            try? await Task.sleep(for:.milliseconds(120)); view.layoutSubtreeIfNeeded()
            let size = view.fittingSize; view.setFrameSize(size)
            lines.append(size.width >= 739 && size.width <= 741 && size.height > 350 && size.height < 1800 ? "PASS \(locale) \(style) \(step.title) native layout":"FAIL \(locale) \(style) \(step.title): \(size)")
            if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                if let png = bitmap.representation(using:.png,properties:[:]) { try? png.write(to:folder.appendingPathComponent("Setup-\(locale)-\(style)-\(step.rawValue).png")) }
            }
        }
    }
    let countdown = model.hardware.rollbackSeconds
    model.hardware.rollbackSeconds = 5
    let accepted = model.finishGuidedSetup()
    model.hardware.rollbackSeconds = countdown
    let after = UserDefaults.standard.object(forKey:"guidedSetup.v1.completed")
    lines.append(!accepted && String(describing:completed) == String(describing:after) ? "PASS pending preview cannot complete or persist setup":"FAIL pending preview setup guard")
    if countdown == 0 {
        let welcome = UserDefaults.standard.object(forKey:"welcomeDismissed")
        let showWelcome = model.showOnboarding, section = model.section
        let finished = model.finishGuidedSetup()
        lines.append(finished && !model.showOnboarding && model.section == .overview && UserDefaults.standard.bool(forKey:"guidedSetup.v1.completed") ? "PASS finishing persists completion and returns to the desk":"FAIL setup completion transition")
        UserDefaults.standard.set(completed,forKey:"guidedSetup.v1.completed")
        UserDefaults.standard.set(welcome,forKey:"welcomeDismissed")
        model.showOnboarding = showWelcome; model.section = section
    } else { lines.append("SKIP finishing with an existing real preview") }
    lines.append(model.hardware.selected == selected && model.hardware.output == output && model.colors.currentURL == profile ? "PASS walkthrough preserved display, output and color profile":"FAIL walkthrough changed hardware state")
    lines.append(!model.keyboard.mediaActive ? "PASS validation did not acquire a media-key tap":"FAIL validation acquired media-key access")
    window.close()
    try? lines.joined(separator:"\n").write(to:folder.appendingPathComponent("Setup-UI.txt"),atomically:true,encoding:.utf8)
    print(lines.joined(separator:"\n")); fflush(stdout)
}
