import Cocoa
import Carbon
func openSettings(_ value: String) {}
_ = NSApplication.shared
MainActor.assumeIsolated {
    let keyboard = DeskKeyboard()
    var received: [DeskCommand] = []
    keyboard.onCommand = { command, _ in received.append(command) }
    for command in DeskCommand.allCases {
        var event: EventRef?
        precondition(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), GetCurrentEventTime(), EventAttributes(0), &event) == noErr)
        var id = EventHotKeyID(signature:0x4d385354, id:command.rawValue)
        precondition(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id) == noErr)
        precondition(SendEventToEventTarget(event, GetEventDispatcherTarget()) == noErr)
        ReleaseEvent(event)
    }
    precondition(received == DeskCommand.allCases)
    print("PASS: all seven Carbon command events reach the real registered callback in order")
    print("Scope: internal Carbon dispatch; physical/global OS input delivery is a separate live check")
}
