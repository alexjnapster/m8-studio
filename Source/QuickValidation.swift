import AppKit
import SwiftUI

@MainActor func validateQuickUI(_ controller:DeskStatusController,model:DeskModel,directory:String) async {
    let url = URL(fileURLWithPath:directory,isDirectory:true)
    try? FileManager.default.createDirectory(at:url,withIntermediateDirectories:true)
    let language = model.language; let appearance = model.appearance; let scenes = model.scenes
    var fixtures: [DeskScene] = []
    for (index,name) in ["Тихий вечір біля вікна","Зосереджена робота","Відпочинок після роботи","Мій простір для творчості"].enumerated() {
        var scene = model.capture(name:name); scene.brightness = Double(100-index*15)/100; fixtures.append(scene)
    }
    for _ in 0..<30 {
        if controller.item.button?.window != nil { break }
        try? await Task.sleep(for:.milliseconds(100))
    }
    var lines = ["Native NSPopover layout validation — controls, empty scenes, populated scenes", "No network connection or audio/display mutations are requested by this harness."]
    for (locale,style) in [("uk","Light"),("uk","Dark"),("en","Light"),("en","Dark")] {
        model.language = locale; model.appearance = style
        for variant in ["controls","empty-scenes","favorite-scenes"] {
            model.scenes = variant == "favorite-scenes" ? fixtures:[]
            controller.popover.contentViewController = NSHostingController(rootView:QuickStudioView(model:model,initialPage:variant == "controls" ? 0:1))
            controller.showPopover()
            if !controller.popover.isShown {
                await Task.yield(); controller.showPopover()
            }
            try? await Task.sleep(for:.milliseconds(300))
            for _ in 0..<3 where !controller.popover.isShown {
                controller.showPopover(); try? await Task.sleep(for:.milliseconds(200))
            }
            if let view = controller.popover.contentViewController?.view {
                view.layoutSubtreeIfNeeded()
                let size = view.bounds.size
                let valid = controller.popover.isShown && size.width >= 370 && size.width <= 390 && size.height >= 260 && size.height <= 700
                lines.append("\(valid ? "PASS":"FAIL") \(locale) \(style) \(variant): shown=\(controller.popover.isShown), size=\(Int(size.width))×\(Int(size.height))")
                if let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) {
                    view.cacheDisplay(in:view.bounds,to:bitmap)
                    if let png = bitmap.representation(using:.png,properties:[:]) { try? png.write(to:url.appendingPathComponent("Quick-\(locale)-\(style)-\(variant).png")) }
                }
            } else { lines.append("FAIL \(locale) \(style) \(variant): missing hosting view") }
            controller.closePopover()
        }
    }
    model.scenes = scenes; model.language = language; model.appearance = appearance
    try? lines.joined(separator:"\n").write(to:url.appendingPathComponent("Quick-UI.txt"),atomically:true,encoding:.utf8)
    print(lines.joined(separator:"\n")); fflush(stdout); NSApp.terminate(nil)
}
