import Foundation

struct SoundRoute: Equatable {
    let uid: String
    let sampleRate: Double
}

struct SoundMeters {
    var peak: Float = 0
    var reduction: Float = 0
    var frames: UInt64 = 0
}

protocol SoundSession: AnyObject {
    func start(route: SoundRoute) throws
    func stop()
    var headroom: Double { get }
    var meters: SoundMeters { get }
}

/// Serializes blocking HAL work and rejects results from superseded requests.
/// No part of this controller runs in the realtime audio callback.
final class SoundLifecycle {
    enum Event {
        case started(headroom: Double)
        case stopped
        case failed(String)
        case meters(SoundMeters)
    }
    private let queue = DispatchQueue(label: "local.M8Studio.Sound.lifecycle", qos: .userInitiated)
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var closed = false
    private var session: SoundSession? // lifecycle queue only
    private let readRoute: () -> SoundRoute?
    private let makeSession: ([Double]) -> SoundSession
    private let deliver: (@escaping () -> Void) -> Void

    init(readRoute: @escaping () -> SoundRoute?, makeSession: @escaping ([Double]) -> SoundSession,
         deliver: @escaping (@escaping () -> Void) -> Void = { DispatchQueue.main.async(execute: $0) }) {
        self.readRoute = readRoute; self.makeSession = makeSession; self.deliver = deliver
    }
    private func request() -> UInt64? {
        lock.lock(); defer { lock.unlock() }
        guard !closed else { return nil }
        generation &+= 1
        return generation
    }
    private func current(_ ticket: UInt64) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !closed && generation == ticket
    }
    private func emit(_ event: Event, ticket: UInt64, receive: @escaping (Event) -> Void) {
        deliver { [weak self] in
            guard let self, self.current(ticket) else { return }
            receive(event)
        }
    }
    private func tearDown() { session?.stop(); session = nil }

    func start(route: SoundRoute, gains: [Double], sessionFactory: (([Double]) -> SoundSession)? = nil, receive: @escaping (Event) -> Void) {
        guard let ticket = request() else { return }
        queue.async { [self] in
            guard current(ticket) else { return }
            tearDown()
            do {
                guard readRoute() == route else { throw Failure.routeChanged }
                let candidate = (sessionFactory ?? makeSession)(gains)
                session = candidate // also tears down a partially failed start
                try candidate.start(route: route)
                // Re-check eligibility, format and rate, even when the UID stayed the same.
                guard current(ticket) else { tearDown(); return }
                guard readRoute() == route else { throw Failure.routeChanged }
                emit(.started(headroom: candidate.headroom), ticket: ticket, receive: receive)
            } catch {
                tearDown()
                emit(.failed(error.localizedDescription), ticket: ticket, receive: receive)
            }
        }
    }
    func stop(receive: @escaping (Event) -> Void) {
        guard let ticket = request() else { return }
        queue.async { [self] in
            guard current(ticket) else { return }
            tearDown()
            emit(.stopped, ticket: ticket, receive: receive)
        }
    }
    func meter(receive: @escaping (Event) -> Void) {
        lock.lock(); let ticket = generation; let allowed = !closed; lock.unlock()
        guard allowed else { return }
        queue.async { [self] in
            guard current(ticket), let session else { return }
            emit(.meters(session.meters), ticket: ticket, receive: receive)
        }
    }
    func shutdown() {
        lock.lock(); closed = true; generation &+= 1; lock.unlock()
        queue.sync { tearDown() }
    }
    // A barrier for the synthetic recovery harness; never waits on the main queue.
    func waitForPendingWork() { queue.sync {} }

    private enum Failure: LocalizedError {
        case routeChanged
        var errorDescription: String? { "Output changed or is no longer eligible for stereo EQ" }
    }
}
