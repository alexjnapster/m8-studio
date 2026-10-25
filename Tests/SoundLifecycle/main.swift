import Foundation

// Actual lifecycle controller with synthetic sessions. No Core Audio, device,
// capture permission or output changes. Delay work/results to reproduce races.
final class Mailbox {
    private let lock = NSLock()
    private var pending: [() -> Void] = []
    func append(_ work: @escaping () -> Void) { lock.lock(); pending.append(work); lock.unlock() }
    func flush() {
        lock.lock(); let work = pending; pending = []; lock.unlock()
        work.forEach { $0() }
    }
}
final class FakeSession: SoundSession {
    var onStart: () throws -> Void = {}
    var starts = 0, stops = 0
    var headroom: Double { 5.5 }
    var meters: SoundMeters { SoundMeters(peak: 0.25, reduction: 0.5, frames: 1024) }
    func start(route: SoundRoute) throws { starts += 1; try onStart() }
    func stop() { stops += 1 }
}
final class Fixture {
    static let display = SoundRoute(uid: "synthetic-display", sampleRate: 48000)
    private let lock = NSLock()
    private var route: SoundRoute? = display
    let mailbox = Mailbox()
    var sessions: [FakeSession] = [] // read after the lifecycle barrier only
    var configure: (FakeSession) -> Void = { _ in }
    var events: [String] = [] // delivered only when test flushes the mailbox
    lazy var lifecycle = SoundLifecycle(readRoute: { [unowned self] in
        self.lock.lock(); defer { self.lock.unlock() }; return self.route
    }, makeSession: { [unowned self] gains in
        let session = FakeSession(); self.configure(session); self.sessions.append(session); return session
    }, deliver: { [unowned self] in self.mailbox.append($0) })
    func setRoute(_ value: SoundRoute?) { lock.lock(); route = value; lock.unlock() }
    func receive(_ event: SoundLifecycle.Event) {
        switch event {
        case .started(let headroom): events.append("start:\(headroom)")
        case .stopped: events.append("stop")
        case .failed: events.append("failure")
        case .meters(let values): events.append("meter:\(values.frames):\(values.peak)")
        }
    }
    func start() { lifecycle.start(route: Self.display, gains: Array(repeating: 0, count: 8), receive: receive) }
    func stop() { lifecycle.stop(receive: receive) }
    func drain() { lifecycle.waitForPendingWork(); mailbox.flush() }
    func finish() { lifecycle.shutdown(); mailbox.flush() }
}
var passed = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fatalError("FAIL \(name)") }
    passed += 1; print("PASS \(name)")
}
enum SimulatedFailure: Error { case start }

do {
    let f = Fixture(); f.start(); f.drain()
    check(f.events == ["start:5.5"], "successful start publishes actual headroom")
    f.lifecycle.meter(receive: f.receive); f.drain()
    check(f.events.last == "meter:1024:0.25", "meters originate from the active session")
    f.stop(); f.drain()
    check(f.sessions[0].stops == 1 && f.events.last == "stop", "bypass tears down before acknowledging completion")
    let count = f.events.count; f.lifecycle.meter(receive: f.receive); f.drain()
    check(f.events.count == count, "no meter events after teardown")
    f.finish()
}
do {
    let f = Fixture(); f.setRoute(nil); f.start(); f.drain()
    check(f.sessions.isEmpty && f.events == ["failure"], "ineligible output before start never creates a tap session")
    f.finish()
}
for replacement in [nil, SoundRoute(uid: "native-speakers", sampleRate: 48000), SoundRoute(uid: "synthetic-display", sampleRate: 44100)] as [SoundRoute?] {
    let f = Fixture(); f.configure = { session in session.onStart = { f.setRoute(replacement) } }
    f.start(); f.drain()
    check(f.events == ["failure"] && f.sessions[0].stops == 1, "eligibility/UID/rate transition during startup disposes candidate: \(String(describing: replacement))")
    f.configure = { _ in }; f.sessions[0].onStart = {}; f.finish()
}
do {
    let f = Fixture(); f.configure = { $0.onStart = { throw SimulatedFailure.start } }
    f.start(); f.drain()
    check(f.sessions[0].stops == 1 && f.events == ["failure"], "partially failed startup is torn down")
    f.configure = { _ in }; f.start(); f.drain()
    check(f.events.last == "start:5.5", "a failed start can be retried deliberately")
    f.finish()
}
do {
    let f = Fixture(); f.start(); f.lifecycle.waitForPendingWork()
    f.lifecycle.meter(receive: f.receive); f.lifecycle.waitForPendingWork()
    // Startup and meter succeeded, but their UI delivery has not happened yet.
    f.stop(); f.drain()
    check(f.events == ["stop"], "late startup and meter callbacks cannot reactivate UI after bypass")
    check(f.sessions[0].stops == 1, "cancelled acknowledged start still releases its session")
    f.finish()
}
do {
    let f = Fixture(); let entered = DispatchSemaphore(value: 0), resume = DispatchSemaphore(value: 0)
    f.configure = { $0.onStart = { entered.signal(); resume.wait() } }
    f.start()
    check(entered.wait(timeout: .now()+5) == .success, "synthetic blocking startup reached")
    f.start(); f.stop(); resume.signal(); f.drain()
    check(f.sessions.count == 1 && f.sessions[0].stops == 1, "stop cancels both in-flight and queued startup")
    check(f.events == ["stop"], "superseded startup publishes no success or error")
    f.configure = { _ in }; f.sessions[0].onStart = {}; f.finish()
}
do {
    let f = Fixture(); f.configure = { $0.onStart = { throw SimulatedFailure.start } }
    f.start(); f.lifecycle.waitForPendingWork()
    f.configure = { _ in }; f.start(); f.drain()
    check(f.events == ["start:5.5"], "stale failure cannot overwrite a newer successful start")
    f.stop(); f.lifecycle.waitForPendingWork(); f.start(); f.drain()
    check(f.events == ["start:5.5", "start:5.5"], "stale stop completion cannot clear a newer session")
    f.finish()
}
do {
    let f = Fixture(); f.start(); f.lifecycle.waitForPendingWork(); f.finish()
    check(f.events.isEmpty && f.sessions[0].stops == 1, "shutdown rejects already queued UI callbacks")
    f.start(); f.stop(); f.lifecycle.meter(receive: f.receive); f.drain()
    check(f.sessions.count == 1 && f.events.isEmpty, "closed lifecycle cannot start again or emit meters")
    f.finish()
    check(f.sessions[0].stops == 1, "repeated shutdown is idempotent")
}
do {
    let f = Fixture()
    for _ in 0..<100 { f.start(); f.drain() }
    f.finish()
    check(f.sessions.count == 100 && f.sessions.allSatisfy { $0.starts == 1 && $0.stops == 1 }, "100 deliberate reapplications release every synthetic session exactly once")
}
print("\(passed) sound lifecycle checks passed")
