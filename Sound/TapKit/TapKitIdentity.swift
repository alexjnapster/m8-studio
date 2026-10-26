import Foundation

/// Logger subsystem for the whole package.
#if M8_INTEGRATED_SOUND
let tapKitLogSubsystem = "local.M8Studio"
#else
let tapKitLogSubsystem = "local.M8Studio.Sound"
#endif

/// Names CoreAudioTapKit uses when creating its process tap and aggregate device.
/// Consumers who ship two tap-based apps side by side can fork these.
enum TapKitIdentity {
    #if M8_SOUND_HARDWARE_TEST
    static let tapName = "M8 Studio Hardware Test EQ"
    static let aggregateDeviceName = "M8 Studio Hardware Test Processing"
    static let aggregateDeviceUIDPrefix = "local.M8Studio.HardwareTest.CATap"
    #elseif M8_INTEGRATED_SOUND
    static let tapName = "M8 Studio EQ"
    static let aggregateDeviceName = "M8 Studio Processing"
    static let aggregateDeviceUIDPrefix = "local.M8Studio.CATap"
    #else
    static let tapName = "M8 Studio Sound"
    static let aggregateDeviceName = "M8 Studio Sound Processing"
    static let aggregateDeviceUIDPrefix = "local.M8Studio.Sound.CATap"
    #endif
}
