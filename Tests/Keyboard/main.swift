import Cocoa
func openSettings(_ value: String) {}
var count = 0
func check(_ value: Bool, _ name: String) { guard value else { fatalError(name) }; count += 1; print("PASS \(name)") }
for (code, command) in [(0,DeskCommand.volumeUp),(1,.volumeDown),(7,.mute),(2,.brighter),(3,.dimmer)] {
    check(mediaCommand((code << 16) | (0x0a << 8))?.0 == command, "system media press \(code)")
    check(mediaCommand((code << 16) | (0x0a << 8))?.1 == true, "press phase \(code)")
    check(mediaCommand((code << 16) | (0x0b << 8))?.1 == false, "release phase \(code)")
}
for code in [144,113] { check(brightnessCommand(keyCode: code) == .brighter,"brightness up \(code)") }
for code in [145,107] { check(brightnessCommand(keyCode: code) == .dimmer,"brightness down \(code)") }
for code in [122,120,0,49,123,126] { check(brightnessCommand(keyCode: code) == nil,"ordinary function/typing/navigation key passes \(code)") }
check(mediaCommand(0) == nil,"invalid phase passes")
check(mediaCommand((16 << 16) | (0x0a << 8)) == nil,"playback key passes")
print("\(count) checks passed")
var ownership = MediaKeyOwnership()
var decision = ownership.handle(identity: 7, command: .mute, pressed: true, allowed: true)
check(decision.consume && decision.deliver,"mute initial press delivered")
decision = ownership.handle(identity: 7, command: .mute, pressed: true, allowed: true)
check(decision.consume && !decision.deliver,"held mute suppressed")
decision = ownership.handle(identity: 7, command: .mute, pressed: false, allowed: false)
check(decision.consume && !decision.deliver,"owned release consumed after output changed")
decision = ownership.handle(identity: 7, command: .mute, pressed: true, allowed: true)
check(decision.deliver,"next mute press delivered")
ownership.reset()
decision = ownership.handle(identity: 7, command: .mute, pressed: false, allowed: true)
check(!decision.consume,"reset clears ownership")
decision = ownership.handle(identity: 0, command: .volumeUp, pressed: true, allowed: false)
check(!decision.consume && !decision.deliver,"unavailable route passes key through")
decision = ownership.handle(identity: 0, command: .volumeUp, pressed: false, allowed: true)
check(!decision.consume,"unowned release passes through after route changes")
for _ in 0..<3 { decision = ownership.handle(identity: 2, command: .brighter, pressed: true, allowed: true); check(decision.deliver,"brightness repeat delivered") }
print("Total: \(count) checks passed")
for (sku,family) in [("LS32BM801UIXUA","M8"),("LS27CM501ENXZA","M5"),("LS32BM701UIXUA","M7"),("S32DM80","M8"),("LS32FM902SUXEN","M9"),("LS43CG700NUXEN","Odyssey G7")] {
    check(SamsungMonitorIdentity(device:["OS":"Tizen","modelName":sku])?.family == family,"Samsung monitor family \(sku)")
}
for device in [["OS":"Android","modelName":"LS32BM801UIXUA"],["OS":"Tizen","modelName":"QE55S95B"],["OS":"Tizen","modelName":"LS32BM801UIXUA.attacker"],["OS":"Tizen","modelName":""],["OS":"Tizen","modelName":"LS32BG852NNXGO"]] {
    check(SamsungMonitorIdentity(device:device) == nil,"unrecognized service rejected \(device["modelName"] ?? "missing")")
}
check(deskPollingInterval(following:false,scheduled:false) == 30,"idle timer backs off to 30 seconds")
check(deskPollingInterval(following:false,scheduled:true) == 15,"schedule checks every 15 seconds")
check(deskPollingInterval(following:true,scheduled:true) == 1,"brightness follow keeps one-second response")
print("Total: \(count) checks passed")
