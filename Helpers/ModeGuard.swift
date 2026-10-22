import Cocoa
import CoreGraphics
// Runs independently of the UI process. A marker is removed when a mode is kept or restored.
let args = CommandLine.arguments
if args.count != 6 { exit(2) }
guard let id = UInt32(args[1]), let oldID = UInt32(args[3]), let seconds = Double(args[5]), (0.5...25).contains(seconds) else { exit(2) }
let marker = URL(fileURLWithPath: args[4])
guard marker.lastPathComponent.hasPrefix("M8Studio-mode-") else { exit(2) }
Thread.sleep(forTimeInterval: seconds)
guard FileManager.default.fileExists(atPath: marker.path),
      let uuid = CGDisplayCreateUUIDFromDisplayID(id).map({ CFUUIDCreateString(nil, $0.takeRetainedValue()) as String }), uuid == args[2],
      let modes = CGDisplayCopyAllDisplayModes(id, [kCGDisplayShowDuplicateLowResolutionModes:true] as CFDictionary) as? [CGDisplayMode],
      let old = modes.first(where: { $0.ioDisplayModeID == oldID }) else { exit(0) }
let result = CGDisplaySetDisplayMode(id, old, nil)
if result == .success { try? FileManager.default.removeItem(at: marker) }
exit(result == .success ? 0 : 1)
