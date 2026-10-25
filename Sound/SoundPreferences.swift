import Foundation

struct SoundPreset: Identifiable {
    let id: String, uk: String, en: String, detailUK: String, detailEN: String
    let gains: [Double]
    static let all: [SoundPreset] = [
        .init(id: "warm", uk: "Теплий звук", en: "Warmth", detailUK: "М’які високі · повніші голоси", detailEN: "Softer treble · fuller voices", gains: [0,2.5,1,0,0,-0.5,-2,-1.5]),
        .init(id: "bass", uk: "Бас +", en: "Bass +", detailUK: "Контрольований бас · менше різкості", detailEN: "Controlled bass · less harshness", gains: [1,4,1.5,0,0,-1,-2.5,-1.5]),
        .init(id: "voice", uk: "Чіткі голоси", en: "Clear voices", detailUK: "Розмови, подкасти та відеозв’язок", detailEN: "Calls, podcasts and dialogue", gains: [-2,0,0,0,1,1.5,-1,-1]),
        .init(id: "flat", uk: "Рівний EQ", en: "Flat EQ", detailUK: "Без підсилення смуг · із захистом", detailEN: "No band boosts · protection on", gains: [0,0,0,0,0,0,0,0])
    ]
}

// Only EQ values cross the companion boundary; no permissions or route selection.
struct SoundPreferences {
    let gains: [Double]
    let presetID: String
    static func validatedGains(_ raw: Any?) -> [Double]? {
        guard let values = raw as? [NSNumber], values.count == 8,
              values.allSatisfy({ CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite && abs($0.doubleValue) <= 6 }) else { return nil }
        return values.map(\.doubleValue)
    }
    static func load(_ defaults: UserDefaults, legacy: UserDefaults? = nil) -> Self {
        if let legacy, !defaults.bool(forKey:"integratedSoundImported") {
            if defaults.object(forKey:"soundGains") == nil,
               let saved = validatedGains(legacy.array(forKey:"soundGains")) {
                defaults.set(saved,forKey:"soundGains")
            }
            defaults.set(true,forKey:"integratedSoundImported")
        }
        let gains = validatedGains(defaults.array(forKey:"soundGains")) ?? SoundPreset.all[0].gains
        // A preset label must describe the actual gains, even after corrupt/old preferences.
        let id = SoundPreset.all.first(where:{ $0.gains == gains })?.id ?? "custom"
        return Self(gains:gains,presetID:id)
    }
}

/// Attenuation-only channel controls. Neutral defaults preserve the accepted EQ.
struct StereoControls: Codable, Equatable {
    var balance:Double = 0
    var mono:Bool = false
    var leftTrim:Double = 0
    var rightTrim:Double = 0
    var nightMode:Bool = false
    var valid:Bool {
        balance.isFinite && (-1...1).contains(balance) && leftTrim.isFinite && rightTrim.isFinite &&
        (-12...0).contains(leftTrim) && (-12...0).contains(rightTrim)
    }
}
struct OutputSoundSettings:Codable,Equatable {
    let gains:[Double]
    let stereo:StereoControls
    var valid:Bool { gains.count == 8 && gains.allSatisfy { $0.isFinite && abs($0) <= 6 } && stereo.valid }
}
struct OutputSoundPreferences {
    let preferences:UserDefaults
    private func key(_ uid:String)->String { "soundOutput." + Data(uid.utf8).base64EncodedString() }
    func load(_ uid:String)->OutputSoundSettings? {
        guard !uid.isEmpty, uid.utf8.count <= 4096, let data = preferences.data(forKey:key(uid)), data.count < 16384,
              let saved = try? JSONDecoder().decode(OutputSoundSettings.self,from:data), saved.valid else { return nil }
        return saved
    }
    func save(_ settings:OutputSoundSettings,for uid:String) {
        guard !uid.isEmpty, uid.utf8.count <= 4096, settings.valid, let data = try? JSONEncoder().encode(settings) else { return }
        preferences.set(data,forKey:key(uid))
    }
}
