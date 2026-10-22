import Foundation

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
        let families = [("M50", "M5"), ("M70", "M7"), ("M80", "M8"), ("M90", "M9"), ("M1", "M1"), ("G65", "Odyssey G6"), ("G70", "Odyssey G7")]
        guard let family = families.first(where: { model.contains($0.0) })?.1 else { return nil }
        self.model = model; self.family = family
    }
}

func deskPollingInterval(following: Bool, scheduled: Bool) -> TimeInterval {
    following ? 1 : scheduled ? 15 : 30
}
