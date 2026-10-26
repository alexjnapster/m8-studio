import Foundation
import CoreGraphics

/// Stable geometry/rate identity; transient mode IDs are never persisted.
struct FavoriteDisplayMode: Codable, Equatable {
    let width: Int, height: Int, pixelWidth: Int, pixelHeight: Int, milliHz: Int
    init(width:Int,height:Int,pixelWidth:Int,pixelHeight:Int,milliHz:Int) {
        self.width=width; self.height=height; self.pixelWidth=pixelWidth; self.pixelHeight=pixelHeight; self.milliHz=milliHz
    }
    init(_ mode:CGDisplayMode) {
        self.init(width:mode.width,height:mode.height,pixelWidth:mode.pixelWidth,pixelHeight:mode.pixelHeight,
                  milliHz:mode.refreshRate.isFinite && (0...1000).contains(mode.refreshRate) ? Int((mode.refreshRate*1000).rounded()): -1)
    }
    var valid: Bool {
        (640...32768).contains(width) && (480...32768).contains(height) &&
        (width...32768).contains(pixelWidth) && (height...32768).contains(pixelHeight) &&
        (0...1000000).contains(milliHz)
    }
    func matches(_ other: Self) -> Bool {
        width == other.width && height == other.height && pixelWidth == other.pixelWidth &&
        pixelHeight == other.pixelHeight && abs(milliHz-other.milliHz) <= 1
    }
}
struct DisplayModeFavorites {
    let defaults: UserDefaults
    static let limit = 8
    private func key(_ display:String) -> String { "favoriteDisplayModes." + display }
    func modes(for display:String) -> [FavoriteDisplayMode] {
        guard !display.isEmpty, let data = defaults.data(forKey:key(display)), data.count < 16384,
              let decoded = try? JSONDecoder().decode([FavoriteDisplayMode].self,from:data) else { return [] }
        var result = [FavoriteDisplayMode]()
        for item in decoded where item.valid && !result.contains(where:{$0.matches(item)}) {
            result.append(item); if result.count == Self.limit { break }
        }
        return result
    }
    /// Returns false for an invalid key or a full collection; existing entries toggle off.
    @discardableResult func toggle(_ item:FavoriteDisplayMode,for display:String) -> Bool {
        guard !display.isEmpty, item.valid else { return false }
        var saved = modes(for:display)
        if let index = saved.firstIndex(where:{$0.matches(item)}) { saved.remove(at:index) }
        else { guard saved.count < Self.limit else { return false }; saved.append(item) }
        guard let data = try? JSONEncoder().encode(saved) else { return false }
        defaults.set(data,forKey:key(display)); return true
    }
}
