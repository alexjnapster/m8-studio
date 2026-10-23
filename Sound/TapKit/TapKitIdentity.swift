import Foundation

/// Logger subsystem for the whole package.
let tapKitLogSubsystem = "local.M8Studio.Sound"

/// Names CoreAudioTapKit uses when creating its process tap and aggregate device.
/// Consumers who ship two tap-based apps side by side can fork these.
enum TapKitIdentity {
    static let tapName = "M8 Studio Sound"
    static let aggregateDeviceName = "M8 Studio Sound Processing"
    static let aggregateDeviceUIDPrefix = "local.M8Studio.Sound.CATap"
}
