import Cocoa
import SwiftUI
import ServiceManagement

@MainActor func runValidation(to destination: String) async {
    var report = ["M8 Studio validation", "Date: \(ISO8601DateFormatter().string(from: Date()))"]
    var failures = 0
    func check(_ condition: Bool, _ description: String) {
        report.append("\(condition ? "PASS" : "FAIL") — \(description)"); if !condition { failures += 1 }
    }
    for host in ["10.0.0.1", "172.16.0.1", "172.31.255.254", "192.168.1.20", "169.254.1.1", "monitor.local", "samsung.lan"] { check(localHost(host), "Accept local address \(host)") }
    for host in ["8.8.8.8", "172.32.0.1", "192.169.0.1", "127.0.0.1", "10.0.0.1.evil.com", "10.0.0.1@evil.com", "192.168.1.2:8002", "999.0.0.1", "10..0.1", "", "https://monitor.local"] { check(!localHost(host), "Reject invalid or nonlocal address \(host)") }
    let packet = wakePacket("02:00:00:00:00:20")
    check(packet?.count == 102 && packet?.prefix(6) == Data(repeating: 255, count: 6), "Wake packet uses six sync bytes and sixteen MAC repetitions")
    check(packet?.suffix(6) == Data([0x02,0x00,0x00,0x00,0x00,0x20]), "Wake packet targets the monitor MAC")
    check(wakePacket("not-a-mac") == nil && wakePacket("FF:FF:FF:FF:FF:FF") == nil && wakePacket("00:00:00:00:00:00") == nil, "Invalid and broadcast wake targets are rejected")
    let valid = "<s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\"><s:Body><u:GetVolumeResponse xmlns:u=\"urn:schemas-upnp-org:service:RenderingControl:1\"><CurrentVolume>15</CurrentVolume></u:GetVolumeResponse></s:Body></s:Envelope>"
    check(XMLValues.parse(Data(valid.utf8))?["CurrentVolume"] == "15", "Parse namespaced Samsung volume response")
    check(XMLValues.parse(Data("<broken>".utf8)) == nil, "Reject malformed XML")
    check(XMLValues.parse(Data("<Envelope><errorCode>401</errorCode></Envelope>".utf8)) == nil, "Reject SOAP fault")
    let model = StudioState.shared.model
    let originalLanguage = model.language
    model.language = "uk"
    check(L("Brightness") == "Яскравість" && L("Open Studio") == "Відкрити Studio", "Ukrainian labels and native quick-menu strings")
    check(L("Current profile: SAMSUNG") == "Поточний профіль: SAMSUNG", "Interpolated profile label preserves device data")
    check(L("Keep this view? Restoring in 15s") == "Залишити цей режим? Відновлення через 15 с", "Localized recovery countdown")
    check(L("2-channel · 48 kHz") == "Каналів: 2 · 48 кГц", "Localized live stereo format")
    check(LF("%@ · %@% brightness",["2560 × 1440 HiDPI · 60 Гц","100"]) == "2560 × 1440 HiDPI · 60 Гц · яскравість 100%","Explicit formatting keeps refresh rate outside brightness")
    check(LF("Preview %@ before applying",["My %@ scene"]) == "Переглянути сцену «My %@ scene» перед застосуванням","Format values containing placeholder characters stay intact")
    model.language = "en"
    check(L("Brightness") == "Brightness", "English language switch")
    model.language = originalLanguage
    for (key,command) in [(0,DeskCommand.volumeUp),(1,.volumeDown),(7,.mute),(2,.brighter),(3,.dimmer)] {
        check(mediaCommand((key << 16) | (0x0a << 8))?.0 == command && mediaCommand((key << 16) | (0x0a << 8))?.1 == true, "Decode media-key press \(key)")
        check(mediaCommand((key << 16) | (0x0b << 8))?.1 == false, "Decode media-key release \(key)")
    }
    check(mediaCommand((16 << 16) | (0x0a << 8)) == nil && mediaCommand(0) == nil,"Unrelated media keys and invalid phases pass through")
    check(model.keyboard.shortcutStatus == "Global shortcuts ready","All seven global shortcuts register")
    var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
    func clock(_ hour:Int,_ minute:Int)->Date { calendar.date(from:DateComponents(year:2026,month:10,day:19,hour:hour,minute:minute))! }
    check(scheduledPeriod(clock(22,0),start:1320,end:420,calendar:calendar) && scheduledPeriod(clock(0,0),start:1320,end:420,calendar:calendar),"Evening schedule covers start and midnight")
    check(!scheduledPeriod(clock(7,0),start:1320,end:420,calendar:calendar) && !scheduledPeriod(clock(12,0),start:1320,end:420,calendar:calendar),"Evening schedule excludes end and daytime")
    check(!scheduledPeriod(clock(0,0),start:0,end:0,calendar:calendar),"Equal schedule boundaries disable schedule")
    if let url = Bundle.main.url(forResource:"M8-Original",withExtension:"icc",subdirectory:"Profiles"), let data = try? Data(contentsOf:url) {
        check(iccHeaderValid(data),"Original saved M80B ICC is structurally valid")
        check(!iccHeaderValid(data.prefix(100)),"Reject truncated ICC profile")
        var wrong = data; wrong.replaceSubrange(16..<20,with:Data("CMYK".utf8)); check(!iccHeaderValid(wrong),"Reject non-RGB ICC profile")
    }
    var scene = model.capture(name:"Тест / Test")
    check(scene.valid,"Unicode scene names remain valid")
    if let data = try? JSONEncoder().encode(scene), let decoded = try? JSONDecoder().decode(DeskScene.self,from:data) { check(decoded == scene,"Scene JSON preserves Unicode and exact settings") }
    scene.brightness = .nan; check(!scene.valid,"Reject nonfinite scene brightness")
    scene.brightness = 0.1; check(!scene.valid,"Reject invisible scene brightness")
    scene.brightness = 1; scene.volume = 101; check(!scene.valid,"Reject out-of-range scene volume")
    scene.volume = nil; scene.displayUUID = "invalid"; check(!scene.valid,"Reject invalid scene display identity")
    let h = StudioState.shared.hardware
    h.refresh(); report.append(h.diagnostics())
    check(h.displays.count >= 2, "Built-in and external displays enumerated")
    check(h.audio.contains(where: { $0.name.uppercased().contains("SAMSUNG") && $0.channels == 2 && $0.rate == 48000 }), "Samsung audio reports stereo at 48 kHz")
    let color = model.colors; color.refresh(h.selected)
    let originalProfile = color.currentURL
    if let srgb = color.profiles.first(where:{$0.id == "srgb"}) {
        check(color.apply(srgb),"ColorSync applies sRGB reference and confirms URL")
        color.undo()
        check(color.currentURL?.standardizedFileURL == originalProfile?.standardizedFileURL,"ColorSync undo restores original exact monitor profile")
    } else { check(false,"sRGB reference exists for profile roundtrip") }
    let preservedScenes = model.scenes
    let temp = model.capture(name:"Тестова сцена")
    model.scenes.append(temp); model.delete(temp); check(!model.scenes.contains(where:{$0.id == temp.id}) && model.canRestoreDeleted,"Scene removal offers recovery")
    model.restoreDeleted(); check(model.scenes.contains(temp),"Scene removal undo restores exact scene")
    model.scenes = preservedScenes; model.persistScenes()
    let originalOutput = h.output
    h.setOutput(originalOutput)
    check(h.output == originalOutput && h.notice == "Audio output updated.", "Core Audio accepts output selection and reports it back")
    do {
        let before = SMAppService.mainApp.status
        if before == .enabled { try await SMAppService.mainApp.unregister(); check(SMAppService.mainApp.status != .enabled, "Login item can be unregistered"); try SMAppService.mainApp.register(); check(SMAppService.mainApp.status == .enabled, "Login item state restored") }
        else { try SMAppService.mainApp.register(); check(SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval, "Login item registration is accepted by macOS"); try await SMAppService.mainApp.unregister(); check(SMAppService.mainApp.status != .enabled, "Original disabled startup preference restored") }
    } catch { check(false, "Login item lifecycle: \(error.localizedDescription)") }
    if let screen = h.current?.screen {
        let directory = URL(fileURLWithPath: destination).deletingLastPathComponent().appendingPathComponent("Previews")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for kind in PatternKind.allCases {
            PatternController.shared.show(kind, screen: screen)
            check(PatternController.shared.window?.isVisible == true && PatternController.shared.window?.frame == screen.frame, "\(kind.rawValue) opens on selected screen")
            let renderer = ImageRenderer(content: PatternView(kind: kind, close: {}).frame(width: 1440, height: 900)); renderer.scale = 1
            if let cg = renderer.cgImage {
                let bitmap = NSBitmapImageRep(cgImage: cg)
                if let png = bitmap.representation(using: .png, properties: [:]) { try? png.write(to: directory.appendingPathComponent("\(kind.id).png")) }
                check(cg.width == 1440 && cg.height == 900, "\(kind.rawValue) renders at expected preview size")
            } else { check(false, "\(kind.rawValue) preview renders") }
            if let window = PatternController.shared.window,
               let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53) {
                window.keyDown(with: escape)
                check(!window.isVisible, "\(kind.rawValue) closes with Escape")
            }
            PatternController.shared.window?.close(); PatternController.shared.window = nil
        }
    }
    let originalOrigins = h.displays.map { ($0.id, CGDisplayBounds($0.id).origin) }
    let originalMain = CGMainDisplayID()
    h.setMain()
    check(CGMainDisplayID() == h.selected, "Selected external display becomes the main display")
    var configuration: CGDisplayConfigRef?
    if CGBeginDisplayConfiguration(&configuration) == .success, let configuration {
        for (id, origin) in originalOrigins { _ = CGConfigureDisplayOrigin(configuration, id, Int32(origin.x), Int32(origin.y)) }
        let restored = CGCompleteDisplayConfiguration(configuration, .forSession)
        check(restored == .success && CGMainDisplayID() == originalMain, "Original main display and layout restored")
    } else { check(false, "Original layout restoration configuration starts") }
    h.refresh()
    let originalSelected = h.selected
    if let builtin = h.displays.first(where: { $0.builtIn }) { h.select(builtin.id); check(h.current?.builtIn == true && h.ddc.isEmpty, "Display selection switches to built-in without external DDC controls") }
    h.select(originalSelected)
    while h.probing { try? await Task.sleep(for: .milliseconds(100)) }
    check(h.ddc.isEmpty, "M80B unavailable DDC controls remain hidden after probing")
    h.shade(0.8); check(abs(h.dim-0.8) < 0.001, "Per-display software shade applies")
    h.resetShades(); check(h.dim == 1, "Restore all screens removes software shade")
    if let display = h.current, let old = display.mode, let alternate = display.modes.first(where: { $0.width == 1920 && $0.height == 1080 && $0.pixelWidth == 3840 && $0.refreshRate >= 59 }) {
        h.applyMode(alternate)
        check(h.rollbackSeconds == 15 && CGDisplayCopyDisplayMode(display.id)?.width == 1920, "HiDPI mode applies with rollback armed")
        try? await Task.sleep(for: .seconds(17))
        check(CGDisplayCopyDisplayMode(display.id)?.ioDisplayModeID == old.ioDisplayModeID && h.rollbackSeconds == 0, "Automatic 15-second rollback restores the exact original mode")
        h.applyMode(alternate); h.keepMode()
        check(h.rollbackSeconds == 0 && CGDisplayCopyDisplayMode(display.id)?.width == 1920, "Keep mode cancels UI rollback")
        _ = CGDisplaySetDisplayMode(display.id, old, nil); h.refresh()
        check(CGDisplayCopyDisplayMode(display.id)?.ioDisplayModeID == old.ioDisplayModeID, "Validation restores original display mode after keep-mode test")
        // Exercise the independent helper with a short deadline and real mode transition.
        if let helper = Bundle.main.path(forResource: "ModeGuard", ofType: nil) {
            let marker = FileManager.default.temporaryDirectory.appendingPathComponent("M8Studio-mode-"+UUID().uuidString)
            try? Data(display.uuid.utf8).write(to: marker)
            _ = CGDisplaySetDisplayMode(display.id, alternate, nil)
            let result = await Task.detached { runTool(helper, [String(display.id), display.uuid, String(old.ioDisplayModeID), marker.path, "1"], timeout: 4) }.value
            check(result.0 == 0 && CGDisplayCopyDisplayMode(display.id)?.ioDisplayModeID == old.ioDisplayModeID, "Independent mode helper restores original mode without UI timer")
            try? FileManager.default.removeItem(at: marker)
            _ = CGDisplaySetDisplayMode(display.id, old, nil)
        } else { check(false, "Independent recovery helper exists") }
    } else { check(false, "A suitable 4K HiDPI mode is available for recovery integration tests") }
    let remote = StudioState.shared.remote
    remote.connect()
    let mediaDeadline = Date().addingTimeInterval(8)
    while !remote.mediaAvailable && Date() < mediaDeadline { try? await Task.sleep(for:.milliseconds(100)) }
    check(remote.mediaAvailable,"Verified monitor media service works independently of WebSocket pairing")
    if let original = remote.volume, remote.mediaAvailable {
        remote.setVolume(max(0,original-1)); while remote.changingVolume { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.volume == max(0,original-1),"Direct network volume read/write/readback succeeds")
        remote.setVolume(original); while remote.changingVolume { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.volume == original,"Direct network volume restores the exact original value")
        model.setVolume(max(0,original-1)); model.setVolume(max(0,original-2)); model.setVolume(max(0,original-3))
        while model.volumePending { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.volume == max(0,original-3),"Rapid absolute volume targets coalesce to the final exact value")
        model.setVolume(original); while model.volumePending { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.volume == original,"Volume queue restores the original value")
        let mute = remote.muted; remote.toggleMute(); while remote.changingMute { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.muted != mute,"Direct network mute succeeds without WebSocket access")
        remote.toggleMute(); while remote.changingMute { try? await Task.sleep(for:.milliseconds(100)) }
        check(remote.muted == mute,"Direct network mute restores the original state")
    }
    let deadline = Date().addingTimeInterval(45)
    while !remote.connected && Date() < deadline { try? await Task.sleep(for: .milliseconds(200)) }
    check(remote.connected && remote.model == "LS32BM801UIXUA", "Saved pairing reconnects to exact monitor over TLS")
    if remote.connected {
        await remote.refreshMedia()
        if let original = remote.volume {
            let target = max(0, original-1)
            remote.setVolume(target)
            while remote.changingVolume { try? await Task.sleep(for: .milliseconds(100)) }
            check(remote.volume == target, "Precise monitor volume change confirmed by readback")
            remote.setVolume(original)
            while remote.changingVolume { try? await Task.sleep(for: .milliseconds(100)) }
            check(remote.volume == original, "Original monitor volume restored and confirmed")
            if original > 0 {
                remote.send("KEY_VOLDOWN"); try? await Task.sleep(for: .seconds(1)); await remote.refreshMedia()
                check(remote.volume == original-1, "WebSocket volume-down key changes real monitor volume")
                remote.setVolume(original)
                while remote.changingVolume { try? await Task.sleep(for: .milliseconds(100)) }
                check(remote.volume == original, "Original volume restored after WebSocket key test")
            }
        } else { check(false, "Monitor media service returns numeric volume") }
        let originalMute = remote.muted
        remote.send("KEY_MUTE"); try? await Task.sleep(for: .seconds(1)); await remote.refreshMedia()
        check(remote.muted != originalMute, "Remote mute key changes the monitor mute state")
        remote.send("KEY_MUTE"); try? await Task.sleep(for: .seconds(1)); await remote.refreshMedia()
        check(remote.muted == originalMute, "Original monitor mute state restored")
        let generationStatus = remote.status
        remote.send("KEY_FACTORY")
        check(remote.status == generationStatus, "Factory command is excluded from remote allowlist")
        remote.disconnect(); check(!remote.connected && remote.volume == nil, "Disconnect removes live monitor controls")
    }
    report.append("Result: \(failures == 0 ? "PASS" : "FAIL") — \(failures) failures")
    do { try report.joined(separator: "\n").write(toFile: destination, atomically: true, encoding: .utf8) } catch { print(error) }
    print(report.joined(separator: "\n")); fflush(stdout)
}
