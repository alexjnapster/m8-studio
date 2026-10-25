import Foundation

var passed = 0
func check(_ value: Bool, _ name: String) {
    guard value else { fatalError("FAIL \(name)") }
    passed += 1; print("PASS \(name)")
}
for route in StudioRoute.allCases {
    check(StudioRoute(url: route.url) == route, "round-trip \(route.rawValue)")
}
let prefix = StudioRoute.scheme + "://"
for suffix in ["open", "open/", "open/display/", "open//display", "open/../display",
               "open/%64isplay", "open/display?brightness=20", "open/display?",
               "open/sound#enable", "open/sound#", "user@open/sound", "open:80/quick",
               "remote/quick", "open/set-volume", "open/open-file", "open/Display",
               "open./quick", "open/%2e%2e/display", "open/color/anything"] {
    check(StudioRoute(url: URL(string: prefix + suffix)!) == nil, "reject \(suffix)")
}
for text in ["https://open/display", "file:///display", "m8studio-other://open/quick"] {
    check(StudioRoute(url: URL(string: text)!) == nil, "reject foreign scheme")
}
check(StudioRoute(url: URL(string: StudioRoute.scheme.uppercased() + "://OPEN/quick")!) == .quick, "URL scheme and host case-insensitive")
let otherScheme = StudioRoute.scheme == "m8studio" ? "m8studio-preview" : "m8studio"
check(StudioRoute(url: URL(string: otherScheme + "://open/quick")!) == nil, "preview and production routes remain isolated")
print("\(passed) navigation route checks passed (\(StudioRoute.scheme))")
