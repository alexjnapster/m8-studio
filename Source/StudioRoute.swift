import Foundation

/// Navigation only. External links cannot apply settings, select devices or
/// supply credentials, file paths, network addresses or arbitrary commands.
enum StudioRoute: String, CaseIterable {
    case quick, display, color, sound, scenes, settings, setup
    static var scheme: String {
        #if M8_UI_PREVIEW || M8_WIDGET_PREVIEW
        "m8studio-preview"
        #else
        "m8studio"
        #endif
    }
    var url: URL { URL(string: "\(Self.scheme)://open/\(rawValue)")! }
    init?(url: URL) {
        guard let c = URLComponents(url: url, resolvingAgainstBaseURL: false),
              c.scheme?.lowercased() == Self.scheme, c.host?.lowercased() == "open",
              c.user == nil, c.password == nil, c.port == nil,
              c.query == nil, c.fragment == nil,
              c.path == c.percentEncodedPath, c.path.hasPrefix("/"),
              let route = Self(rawValue: String(c.path.dropFirst())) else { return nil }
        self = route
    }
}
