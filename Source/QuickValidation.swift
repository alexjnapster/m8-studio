import AppKit
import SwiftUI

@MainActor func validateQuickUI(_ controller:DeskStatusController,model:DeskModel,directory:String) async {
    let url = URL(fileURLWithPath:directory,isDirectory:true)
    try? FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
    let language = model.language; let appearance = model.appearance
    var lines = ["Native NSPopover layout validation"]
    model.remote.connect()
    try? await Task.sleep(for:.seconds(2))
    for (locale,style) in [("uk","Light"),("uk","Dark"),("en","Light"),("en","Dark")] {
        model.language = locale; model.appearance = style
        controller.showPopover()
        try? await Task.sleep(for:.milliseconds(400))
        if let view = controller.popover.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            let size = view.bounds.size
            let valid = controller.popover.isShown && size.width >= 370 && size.height >= 300 && size.height < 900
            lines.append("\(valid ? "PASS":"FAIL") \(locale) \(style): shown=\(controller.popover.isShown), size=\(Int(size.width))×\(Int(size.height)), audioAvailable=\(model.remote.mediaAvailable)")
            if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                view.cacheDisplay(in:view.bounds,to:bitmap)
                if let png = bitmap.representation(using:.png,properties:[:]) { try? png.write(to:url.appendingPathComponent("Quick-\(locale)-\(style).png")) }
            }
        } else { lines.append("FAIL \(locale) \(style): missing hosting view") }
        controller.closePopover()
    }
    model.language = language; model.appearance = appearance
    try? lines.joined(separator:"\n").write(to:url.appendingPathComponent("Quick-UI.txt"),atomically:true,encoding:.utf8)
    print(lines.joined(separator:"\n")); fflush(stdout); NSApp.terminate(nil)
}
