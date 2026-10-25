import Foundation
import Combine

/// Physical dimensions may come from EDID or macOS estimates. Suggestions are
/// advisory, never a reason to generate a timing or change a screen automatically.
struct TextSizeMatch {
    struct Screen {
        let widthMM: Double, heightMM: Double
        let mode: FavoriteDisplayMode
        var valid: Bool {
            mode.valid && widthMM.isFinite && heightMM.isFinite &&
            (100...2500).contains(widthMM) && (70...1800).contains(heightMM)
        }
    }
    static func best(reference:Screen,target:Screen,candidates:[FavoriteDisplayMode]) -> FavoriteDisplayMode? {
        guard reference.valid, target.valid else { return nil }
        let x = Double(reference.mode.width)/reference.widthMM
        let y = Double(reference.mode.height)/reference.heightMM
        // Reject substantially asymmetric reports (e.g. wrong orientation or stretched mode).
        guard abs(log(x/y)) < 0.08 else { return nil }
        return candidates.filter { candidate in
            guard candidate.valid, candidate.pixelWidth > candidate.width else { return false }
            return abs(log((Double(candidate.width)/Double(candidate.height))/(target.widthMM/target.heightMM))) < 0.08
        }.min { a,b in
            func score(_ m:FavoriteDisplayMode) -> Double {
                let sx = Double(m.width)/target.widthMM, sy = Double(m.height)/target.heightMM
                return abs(log(sx/x)) + abs(log(sy/y))
            }
            let sa = score(a), sb = score(b)
            if abs(sa-sb) > 0.00001 { return sa < sb }
            return abs(a.milliHz-target.mode.milliHz) < abs(b.milliHz-target.mode.milliHz)
        }
    }
}

struct SavedCanvas: Codable, Equatable {
    let mode: FavoriteDisplayMode
    let profilePath: String?
    let profileName: String?
    var valid:Bool {
        mode.valid && (profilePath.map { $0.hasPrefix("/") && $0.utf8.count <= 4096 } ?? true) &&
        (profileName.map { $0.count <= 512 } ?? true)
    }
}
/// Only a real absent -> present transition offers recovery. No writes, polling,
/// startup restoration or automatic retries: all changes require review in Studio.
@MainActor final class CanvasRecovery: ObservableObject {
    @Published private(set) var pending = Set<String>()
    private let preferences:UserDefaults
    private var connected:Set<String>?
    private var detached = Set<String>()
    init(preferences:UserDefaults = .standard) { self.preferences = preferences }
    private func key(_ uuid:String) -> String { "savedCanvas." + uuid }
    func saved(_ uuid:String) -> SavedCanvas? {
        guard UUID(uuidString:uuid) != nil, let data = preferences.data(forKey:key(uuid)), data.count < 16384,
              let item = try? JSONDecoder().decode(SavedCanvas.self,from:data), item.valid else { return nil }
        return item
    }
    @discardableResult func save(_ item:SavedCanvas,for uuid:String) -> Bool {
        guard UUID(uuidString:uuid) != nil, item.valid, let data = try? JSONEncoder().encode(item) else { return false }
        objectWillChange.send(); preferences.set(data,forKey:key(uuid)); pending.remove(uuid); return true
    }
    func forget(_ uuid:String) {
        objectWillChange.send(); preferences.removeObject(forKey:key(uuid)); pending.remove(uuid); detached.remove(uuid)
    }
    func dismiss(_ uuid:String) { pending.remove(uuid) }
    func updateConnections(_ uuids:Set<String>) {
        let fresh = Set(uuids.filter { UUID(uuidString:$0) != nil })
        guard let previous = connected else { connected = fresh; return }
        detached.formUnion(previous.subtracting(fresh).filter { saved($0) != nil })
        let returning = fresh.subtracting(previous).intersection(detached)
        pending.formUnion(returning.filter { saved($0) != nil })
        pending.formIntersection(fresh)
        detached.subtract(returning); connected = fresh
    }
}
