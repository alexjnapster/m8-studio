import Foundation
import CoreAudio

// PnP identities extracted from Samsung's official monitor INFs. These identify
// a declared monitor variant, not the live cable, negotiated timing or audio codec.
struct SamsungDriverIdentity: Equatable {
    let family:String
    let variant:String
    static func match(vendor:UInt32,product:UInt32)->Self? {
        guard vendor == 0x4c2d else { return nil }
        if product == 0x7267 { return Self(family:"M80B",variant:"USB-C") }
        if product == 0x7269 { return Self(family:"M80B",variant:"HDMI") }
        if product == 0x7394 { return Self(family:"S90PC",variant:"DP") }
        if product == 0x7395 { return Self(family:"S90PC",variant:"USB-C") }
        let m9:[UInt32:String] = [0xe093:"DP 1.4",0xe095:"DP PBP",0xe092:"DP 1.1",0xe094:"DP VRR",0xe096:"DP WS",0xe08e:"HDMI 2.1",0xe08d:"HDMI 1.4",0xe090:"HDMI PBP",0xe08f:"HDMI VRR",0xe091:"HDMI WS",0xe098:"USB-C 1.4",0xe09a:"USB-C PBP",0xe097:"USB-C 1.1",0xe099:"USB-C VRR",0xe09b:"USB-C WS"]
        return m9[product].map { Self(family:"M90SF",variant:$0) }
    }
}

// Model-family recognition is an eligibility check, not proof that a service exists.
// Volume is exposed only after RenderingControl readback, hardware sliders after DDC probing.
struct SamsungMonitorIdentity: Equatable {
    let model: String
    let family: String
    init?(device: [String: Any]) {
        guard (device["OS"] as? String)?.lowercased() == "tizen",
              let raw = device["modelName"] as? String else { return nil }
        let model = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        // Samsung regional SKUs (LS32BM801UIXUA), shortened SKUs (S32BM80),
        // Smart Monitor's platform identifiers, and the smart Odyssey G6/G7 family.
        guard model.range(of: "^L?S[0-9]{2}[A-Z][A-Z0-9]{3,20}$", options: .regularExpression) != nil else { return nil }
        // S90PC identities from Samsung's S27C90xP INF. A family match still
        // requires service/readback checks before volume or remote control.
        if model.range(of:"^L?S27C90[0-9]P",options:.regularExpression) != nil {
            self.model = model; self.family = "ViewFinity S9"; return
        }
        let families = [("M50", "M5"), ("M70", "M7"), ("M80", "M8"), ("M90", "M9"), ("M1", "M1"), ("G65", "Odyssey G6"), ("G70", "Odyssey G7")]
        guard let family = families.first(where: { model.contains($0.0) })?.1 else { return nil }
        self.model = model; self.family = family
    }
}

func deskPollingInterval(following: Bool, scheduled: Bool) -> TimeInterval {
    following ? 1 : scheduled ? 15 : 30
}

// Limit automatic speaker control to display transports. A Samsung Bluetooth
// headset is not the speakers of the network monitor.
func samsungDisplayAudio(name: String, manufacturer: String, transport: UInt32) -> Bool {
    guard transport == kAudioDeviceTransportTypeHDMI || transport == kAudioDeviceTransportTypeDisplayPort else { return false }
    let label = name.uppercased(); let maker = manufacturer.uppercased()
    return label.contains("SAMSUNG") || maker.contains("SAMSUNG") || label.range(of:"^L?S[0-9]{2}[A-Z][A-Z0-9]{3,20}$",options:.regularExpression) != nil
}
// Shared by the main app and sound companion. Brand names alone also match
// Samsung headsets; processing is limited to a physical display's stereo PCM.
func samsungEQRouteEligible(name:String, manufacturer:String, transport:UInt32,
                            uid:String, formatID:UInt32, channels:UInt32,
                            sampleRate:Double) -> Bool {
    !uid.isEmpty && sampleRate.isFinite && sampleRate > 0 &&
    formatID == kAudioFormatLinearPCM && channels == 2 &&
    samsungDisplayAudio(name:name,manufacturer:manufacturer,transport:transport)
}
func monitorAudioRouteMatches(candidates: [String], active: String?, binding: String?) -> Bool {
    let unique = Set(candidates.filter { !$0.isEmpty })
    guard let active, !active.isEmpty, unique.contains(active) else { return false }
    if let binding, !binding.isEmpty { return active == binding }
    return unique.count == 1
}

func refreshLabel(_ hz:Double)->String {
    guard hz.isFinite, hz > 0 else { return "Variable / unspecified" }
    let rounded = (hz*100).rounded()/100
    return rounded == rounded.rounded() ? String(Int(rounded)):String(format:"%.2f",rounded)
}
