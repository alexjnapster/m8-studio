import Cocoa
import ColorSync
import UniformTypeIdentifiers

struct DisplayProfile: Identifiable, Equatable {
    let id: String
    let name: String
    let detail: String
    let url: URL
    let measured: Bool
}
func cs(_ constant: Unmanaged<CFString>?) -> CFString { constant!.takeUnretainedValue() }
func iccHeaderValid(_ data: Data) -> Bool {
    guard data.count >= 132, data.count <= 16_777_216 else { return false }
    let bytes = [UInt8](data)
    let size = bytes.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    return size >= 132 && size <= data.count && String(bytes: bytes[36..<40], encoding: .ascii) == "acsp" && String(bytes: bytes[16..<20], encoding: .ascii) == "RGB " && ["mntr","spac"].contains(String(bytes: bytes[12..<16], encoding: .ascii) ?? "")
}
@MainActor final class ColorProfiles: ObservableObject {
    @Published var profiles: [DisplayProfile] = []
    @Published var currentURL: URL?
    @Published var currentName = "Display profile"
    @Published var status = ""
    @Published var canUndo = false
    private var display: CGDirectDisplayID = 0
    private var previous: URL?
    private var factory: URL?
    private var profileID = "1"
    private var observer:NSObjectProtocol?
    init() {
        observer = DistributedNotificationCenter.default().addObserver(forName:Notification.Name("com.apple.ColorSync.DisplayProfileNotification"),object:nil,queue:.main) { [weak self] _ in Task { @MainActor in guard let self else { return }; self.refresh(self.display) } }
    }
    var library: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("M8 Studio/Profiles", isDirectory: true) }
    func refresh(_ id: CGDirectDisplayID) {
        if display != id { previous = nil; canUndo = false }; display = id
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(), let raw = ColorSyncDeviceCopyDeviceInfo(cs(kColorSyncDisplayDeviceClass), uuid)?.takeRetainedValue() as? [String: Any], let factories = raw["FactoryProfiles"] as? [String: Any] else { profiles = []; currentURL = nil; currentName = "Display profile"; previous = nil; canUndo = false; return }
        profileID = String(describing: factories["DeviceDefaultProfileID"] ?? "1")
        factory = (factories[profileID] as? [String: Any])?["DeviceProfileURL"] as? URL
        currentURL = (raw["CustomProfiles"] as? [String: Any])?[profileID] as? URL ?? factory
        if let url = currentURL { currentName = description(url) }
        var choices: [DisplayProfile] = []
        if let factory { choices.append(DisplayProfile(id: "factory", name: "Display original", detail: "macOS profile for this exact connected display", url: factory, measured: false)) }
        if CGDisplayVendorNumber(id) == 19501, CGDisplayModelNumber(id) == 29287, let saved = Bundle.main.url(forResource: "M8-Original", withExtension: "icc", subdirectory: "Profiles") { choices.append(DisplayProfile(id: "saved", name: "M8 baseline", detail: "Original profile saved from your Mac · not instrument-calibrated", url: saved, measured: false)) }
        let srgb = URL(fileURLWithPath: "/System/Library/ColorSync/Profiles/sRGB Profile.icc")
        if FileManager.default.fileExists(atPath: srgb.path) { choices.append(DisplayProfile(id: "srgb", name: "sRGB reference", detail: "Use only when the panel is set to match sRGB · not a custom calibration", url: srgb, measured: false)) }
        let files = (try? FileManager.default.contentsOfDirectory(at: library, includingPropertiesForKeys: nil)) ?? []
        for file in files where ["icc","icm"].contains(file.pathExtension.lowercased()) { choices.append(DisplayProfile(id: file.path, name: description(file), detail: "Imported profile · accuracy depends on how it was measured", url: file, measured: false)) }
        profiles = choices
    }
    func description(_ url: URL) -> String {
        guard let profile = ColorSyncProfileCreateWithURL(url as CFURL, nil)?.takeRetainedValue(), let description = ColorSyncProfileCopyDescriptionString(profile)?.takeRetainedValue() else { return url.deletingPathExtension().lastPathComponent }
        return description as String
    }
    @discardableResult func apply(_ profile: DisplayProfile) -> Bool {
        guard let data = try? Data(contentsOf: profile.url), iccHeaderValid(data), let uuid = CGDisplayCreateUUIDFromDisplayID(display)?.takeRetainedValue() else { status = "This is not a valid RGB display profile."; return false }
        let old = currentURL
        let ok = ColorSyncDeviceSetCustomProfiles(cs(kColorSyncDisplayDeviceClass), uuid, [cs(kColorSyncDeviceDefaultProfileID) as String: profile.url] as CFDictionary)
        refresh(display)
        guard ok, currentURL?.standardizedFileURL == profile.url.standardizedFileURL else { status = "macOS did not confirm this profile change."; return false }
        previous = old; canUndo = old != nil; status = "Applied \(profile.name). You can undo this change."; return true
    }
    func undo() {
        guard let previous else { return }
        let target = DisplayProfile(id: "undo", name: description(previous), detail: "Previous profile", url: previous, measured: false)
        if apply(target) { self.previous = nil; canUndo = false; status = "Previous profile restored." }
    }
    func importProfile() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        panel.allowedContentTypes = [UTType(filenameExtension: "icc"), UTType(filenameExtension: "icm")].compactMap { $0 }
        panel.message = L("Choose an ICC profile measured for your panel and its current picture settings.")
        guard panel.runModal() == .OK, let file = panel.url else { return }
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: file.path)
            guard let size = attrs[.size] as? NSNumber, size.intValue <= 16_777_216 else { status = "Profile must be smaller than 16 MB."; return }
            let data = try Data(contentsOf: file); guard iccHeaderValid(data), ColorSyncProfileCreateWithURL(file as CFURL, nil) != nil else { status = "Choose a valid RGB display ICC profile."; return }
            try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
            let name = file.deletingPathExtension().lastPathComponent.prefix(80)
            let target = library.appendingPathComponent(String(name) + "-" + UUID().uuidString.prefix(8) + ".icc")
            try data.write(to: target, options: .atomic); refresh(display); status = "Profile imported. Select it to apply; the current profile is unchanged."
        } catch { status = "Could not import profile: \(error.localizedDescription)" }
    }
}
