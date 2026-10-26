import Cocoa
import CoreAudio
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
for (sku,family) in [("LS32BM801UIXUA","M8"),("LS27CM501ENXZA","M5"),("LS32BM701UIXUA","M7"),("S32DM80","M8"),("LS32FM902SUXEN","M9"),("LS27C900PAWXXL","ViewFinity S9"),("LS27C902PAUXEN","ViewFinity S9"),("LS43CG700NUXEN","Odyssey G7")] {
    check(SamsungMonitorIdentity(device:["OS":"Tizen","modelName":sku])?.family == family,"Samsung monitor family \(sku)")
}
for device in [["OS":"Android","modelName":"LS32BM801UIXUA"],["OS":"Tizen","modelName":"QE55S95B"],["OS":"Tizen","modelName":"LS32BM801UIXUA.attacker"],["OS":"Tizen","modelName":""],["OS":"Tizen","modelName":"LS32BG852NNXGO"]] {
    check(SamsungMonitorIdentity(device:device) == nil,"unrecognized service rejected \(device["modelName"] ?? "missing")")
}
check(deskPollingInterval(following:false,scheduled:false) == 30,"idle timer backs off to 30 seconds")
check(deskPollingInterval(following:false,scheduled:true) == 15,"schedule checks every 15 seconds")
check(deskPollingInterval(following:true,scheduled:true) == 1,"brightness follow keeps one-second response")
print("Total: \(count) checks passed")
check(samsungDisplayAudio(name:"SAMSUNG",manufacturer:"",transport:kAudioDeviceTransportTypeDisplayPort),"Samsung DisplayPort audio recognized")
check(samsungDisplayAudio(name:"S32FM90",manufacturer:"",transport:kAudioDeviceTransportTypeHDMI),"Samsung model-named HDMI audio recognized")
check(samsungDisplayAudio(name:"Display Audio",manufacturer:"Samsung",transport:kAudioDeviceTransportTypeHDMI),"Samsung manufacturer metadata recognized on display transport")
check(!samsungDisplayAudio(name:"Samsung Buds",manufacturer:"Samsung",transport:kAudioDeviceTransportTypeBluetooth),"Samsung Bluetooth headset keeps native Mac volume")
check(!samsungDisplayAudio(name:"Samsung USB Headset",manufacturer:"Samsung",transport:kAudioDeviceTransportTypeUSB),"Samsung USB headset is not mistaken for monitor speakers")
check(!samsungDisplayAudio(name:"Other Display",manufacturer:"Other",transport:kAudioDeviceTransportTypeHDMI),"Unrelated HDMI audio is not controlled")
check(monitorAudioRouteMatches(candidates:["display-a"],active:"display-a",binding:nil),"One connected monitor audio route works automatically")
check(!monitorAudioRouteMatches(candidates:["display-a","display-b"],active:"display-a",binding:nil),"Multiple monitor outputs require explicit binding")
check(monitorAudioRouteMatches(candidates:["display-a","display-b"],active:"display-a",binding:"display-a"),"Bound monitor route is controlled")
check(!monitorAudioRouteMatches(candidates:["display-a","display-b"],active:"display-b",binding:"display-a"),"Other monitor route is not controlled")
check(!monitorAudioRouteMatches(candidates:["display-b"],active:"display-b",binding:"display-a"),"Disconnected saved route does not redirect to a different monitor")
check(!monitorAudioRouteMatches(candidates:["display-a"],active:nil,binding:nil),"Missing output remains native")
check(!monitorAudioRouteMatches(candidates:[""],active:"",binding:nil),"Empty audio identity never matches")
print("Total: \(count) checks passed")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0x7267) == SamsungDriverIdentity(family:"M80B",variant:"USB-C"),"Official M80B USB-C identity")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0x7269) == SamsungDriverIdentity(family:"M80B",variant:"HDMI"),"Official M80B HDMI identity receives M8 guidance")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0xe099) == SamsungDriverIdentity(family:"M90SF",variant:"USB-C VRR"),"Official M9 USB-C VRR variant stays M9")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0xe08f)?.family != "M80B","M9 HDMI VRR never acquires M8 policy")
check(SamsungDriverIdentity.match(vendor:0x1234,product:0x7267) == nil,"Other vendor with same product is not Samsung")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0x7394) == SamsungDriverIdentity(family:"S90PC",variant:"DP"),"Official S9 DP identity stays S9")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0x7395) == SamsungDriverIdentity(family:"S90PC",variant:"USB-C"),"Official S9 USB-C identity stays S9")
check(SamsungDriverIdentity.match(vendor:0x1234,product:0x7395) == nil,"S9 product code requires Samsung vendor")
check(SamsungMonitorIdentity(device:["OS":"Tizen","modelName":"LS27C900QAUXEN"]) == nil,"Nearby unverified C900 variant stays unsupported")
check(SamsungDriverIdentity.match(vendor:0x4c2d,product:0x1234) == nil,"Unknown Samsung panel stays unclassified")
print("Total: \(count) checks passed")
check(refreshLabel(59.94) == "59.94","Fractional refresh label is preserved")
check(refreshLabel(60) == "60","Integer refresh label stays compact")
check(refreshLabel(59.9999) == "60","Display precision avoids floating-point noise")
check(refreshLabel(0) == "Variable / unspecified","Unspecified refresh is not advertised as zero Hz")
check(refreshLabel(.infinity) == "Variable / unspecified","Invalid refresh has a safe label")
print("Total: \(count) checks passed")

// Companion routing regression: a stereo Samsung headset formerly passed its
// name-only filter. No device, capture permission or audio route is changed here.
let eqRoutes:[(String,String,UInt32,String,UInt32,UInt32,Double,Bool,String)] = [
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeDisplayPort,"display",kAudioFormatLinearPCM,2,48000,true,"M80B DisplayPort PCM eligible"),
    ("S32FM90","",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatLinearPCM,2,48000,true,"model-named HDMI PCM eligible"),
    ("Display Audio","Samsung",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatLinearPCM,2,48000,true,"manufacturer-named display PCM eligible"),
    ("Samsung Buds","Samsung",kAudioDeviceTransportTypeBluetooth,"buds",kAudioFormatLinearPCM,2,48000,false,"Samsung Bluetooth stereo excluded from EQ"),
    ("Samsung USB Headset","Samsung",kAudioDeviceTransportTypeUSB,"headset",kAudioFormatLinearPCM,2,48000,false,"Samsung USB headset excluded from EQ"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeAirPlay,"wireless",kAudioFormatLinearPCM,2,48000,false,"wireless Samsung output excluded from EQ"),
    ("SAMSUNG","SAM",0,"unknown",kAudioFormatLinearPCM,2,48000,false,"missing transport fails closed"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeDisplayPort,"",kAudioFormatLinearPCM,2,48000,false,"missing endpoint UID excluded"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatAC3,2,48000,false,"encoded carrier excluded from PCM EQ"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatLinearPCM,6,48000,false,"multichannel excluded from stereo EQ"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatLinearPCM,2,.nan,false,"invalid sample rate excluded"),
    ("SAMSUNG","SAM",kAudioDeviceTransportTypeHDMI,"display",kAudioFormatLinearPCM,2,0,false,"zero sample rate excluded")
]
for (name,maker,transport,uid,format,channels,rate,expected,label) in eqRoutes {
    check(samsungEQRouteEligible(name:name,manufacturer:maker,transport:transport,uid:uid,formatID:format,channels:channels,sampleRate:rate) == expected,label)
}
print("Total: \(count) checks passed")
