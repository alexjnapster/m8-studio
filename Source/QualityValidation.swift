import SwiftUI
import AppKit

@MainActor func validateQuality(model:DeskModel,to directory:String) async {
    let folder = URL(fileURLWithPath:directory,isDirectory:true)
    try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    var lines = ["Scaling, color isolation and spatial-playback UI validation. No playback or profile application requested."]
    model.colors.refresh(model.hardware.selected)
    lines += model.colors.validatePanelIsolation()
    if let mode = model.hardware.current?.mode {
        let exact = ModeChoice(mode)
        do {
            let encoded = try JSONEncoder().encode(exact)
            var old = try JSONSerialization.jsonObject(with:encoded) as! [String:Any]; old.removeValue(forKey:"milliHz")
            let legacy = try JSONDecoder().decode(ModeChoice.self,from:JSONSerialization.data(withJSONObject:old))
            lines.append(legacy.matches(mode) ? "PASS legacy integer-refresh scene loads and matches":"FAIL legacy scene compatibility")
            let decoded = try JSONDecoder().decode(ModeChoice.self,from:encoded)
            lines.append(decoded == exact && decoded.matches(mode) ? "PASS exact refresh scene roundtrip":"FAIL exact refresh roundtrip")
            var different = exact; different.milliHz = (exact.milliHz ?? 60000)-60
            lines.append(!different.matches(mode) ? "PASS 59.94 versus 60 Hz remain distinct":"FAIL fractional refresh ambiguity")
        } catch { lines.append("FAIL scene-format validation: \(error.localizedDescription)") }
    }
    let language = model.language; let appearance = model.appearance
    defer { model.language = language; model.appearance = appearance }
    let window = NSWindow(contentRect:CGRect(x:100,y:100,width:780,height:700),styleMask:[.titled],backing:.buffered,defer:false)
    window.isReleasedWhenClosed = false
    for (locale,style) in [("uk","Light"),("uk","Dark"),("en","Light"),("en","Dark")] {
        model.language = locale; model.appearance = style
        let root = VStack(spacing:16) { ScalingInspector(model:model); SpatialPlaybackCard(model:model); SoundTuningCard(model:model) }.padding(20).frame(width:780).background(DeskStyle.canvas).preferredColorScheme(style == "Dark" ? .dark:.light)
        let view = NSHostingView(rootView:root); window.contentView = view; window.orderFrontRegardless()
        try? await Task.sleep(for:.milliseconds(250)); view.layoutSubtreeIfNeeded()
        let size = view.fittingSize; view.setFrameSize(size)
        lines.append(size.width >= 779 && size.width <= 781 && size.height > 400 && size.height < 1800 ? "PASS \(locale) \(style) quality cards layout":"FAIL \(locale) \(style) quality cards layout \(size)")
        if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
            view.cacheDisplay(in:view.bounds,to:bitmap)
            if let png = bitmap.representation(using:.png,properties:[:]) { try? png.write(to:folder.appendingPathComponent("Quality-\(locale)-\(style).png")) }
        }
    }
    window.close()
    try? lines.joined(separator:"\n").write(to:folder.appendingPathComponent("Quality-UI.txt"),atomically:true,encoding:.utf8)
    print(lines.joined(separator:"\n")); fflush(stdout)
}
