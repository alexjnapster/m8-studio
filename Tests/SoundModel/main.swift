import Foundation

// The real integrated SoundModel and SoundLifecycle, with private preference
// suites and injected fake routes/sessions. No hardware observers, HAL or TCC.
var passed = 0
func check(_ value: @autoclosure () -> Bool, _ label: String) {
    guard value() else { fatalError("FAIL " + label) }
    passed += 1; print("PASS " + label)
}
func eventually(_ predicate: () -> Bool) {
    let deadline = Date().addingTimeInterval(3)
    while !predicate(), Date() < deadline { RunLoop.current.run(until:Date().addingTimeInterval(0.005)) }
    check(predicate(),"asynchronous model transition completed")
}
let prefix = "local.M8Studio.Test." + UUID().uuidString
let mainName = prefix + ".Main", legacyName = prefix + ".Legacy"
let prefs = UserDefaults(suiteName:mainName)!, legacy = UserDefaults(suiteName:legacyName)!
defer { prefs.removePersistentDomain(forName:mainName); legacy.removePersistentDomain(forName:legacyName) }
func reset() { prefs.removePersistentDomain(forName:mainName); legacy.removePersistentDomain(forName:legacyName) }
let bass = SoundPreset.all.first(where:{$0.id == "bass"})!, warm = SoundPreset.all[0]
legacy.set(bass.gains,forKey:"soundGains"); legacy.set(true,forKey:"soundEnglish")
legacy.set("private-token",forKey:"pairingToken")
let imported = SoundPreferences.load(prefs,legacy:legacy)
check(imported.gains == bass.gains && imported.presetID == "bass","valid legacy gains imported and identified")
check(prefs.object(forKey:"soundEnglish") == nil && prefs.object(forKey:"pairingToken") == nil,"language and credentials never imported")
check(prefs.bool(forKey:"integratedSoundImported"),"one-time migration recorded")
legacy.set(warm.gains,forKey:"soundGains")
check(SoundPreferences.load(prefs,legacy:legacy).gains == bass.gains,"later legacy changes cannot overwrite migrated main settings")
reset(); prefs.set(warm.gains,forKey:"soundGains"); legacy.set(bass.gains,forKey:"soundGains")
check(SoundPreferences.load(prefs,legacy:legacy).gains == warm.gains,"existing main settings take precedence")
for invalid: Any in [[1.0], Array(repeating:7.0,count:8), Array(repeating:"bad",count:8), Array(repeating:true,count:8)] {
    reset(); legacy.set(invalid,forKey:"soundGains")
    check(SoundPreferences.load(prefs,legacy:legacy).gains == warm.gains,"malformed legacy gains rejected")
}
check(SoundPreferences.validatedGains(Array(repeating:Double.nan,count:8)) == nil,"nonfinite gains rejected")
reset(); prefs.set(bass.gains,forKey:"soundGains"); prefs.set("voice",forKey:"soundPreset")
check(SoundPreferences.load(prefs).presetID == "bass","stored label cannot misrepresent actual gains")
var custom = bass.gains; custom[1] = 3.0; prefs.set(custom,forKey:"soundGains")
check(SoundPreferences.load(prefs).presetID == "custom","custom gains retain custom identity")
reset()

struct SyntheticFailure: LocalizedError { var errorDescription: String? { "Synthetic capture unavailable" } }
final class FakeSession: SoundSession {
    let started = DispatchSemaphore(value:0), release = DispatchSemaphore(value:0)
    var delayed = false, fails = false
    private(set) var stops = 0
    func start(route: SoundRoute) throws { started.signal(); if delayed { release.wait() }; if fails { throw SyntheticFailure() } }
    func stop() { stops += 1 }
    var headroom: Double { 5.5 }
    var meters: SoundMeters { SoundMeters(peak:0.2,reduction:0,frames:512) }
}
final class Fixture {
    let lock = NSLock()
    private var route: SoundRoute? = SoundRoute(uid:"fixture-monitor",sampleRate:48000)
    private var sessions: [FakeSession] = []
    var delayNext = false, failNext = false
    func readRoute() -> SoundRoute? { lock.lock(); defer {lock.unlock()}; return route }
    func changeRoute(_ new: SoundRoute?) { lock.lock(); route = new; lock.unlock() }
    func makeSession(_ gains:[Double]) -> SoundSession {
        lock.lock(); defer {lock.unlock()}
        let session = FakeSession(); session.delayed = delayNext; delayNext = false; session.fails = failNext; failNext = false
        sessions.append(session); return session
    }
    func snapshot() -> [FakeSession] { lock.lock(); defer {lock.unlock()}; return sessions }
}
let f = Fixture(); var companionOpen = true
let model = SoundModel(preferences:prefs,legacyPreferences:legacy,companionRunning:{companionOpen},
    observeHardware:false,routeOverride:f.readRoute,makeSession:f.makeSession)
model.english = true
check(!model.running && !model.busy && f.snapshot().isEmpty,"launch never starts a session")
model.apply()
check(!model.running && !model.busy && f.snapshot().isEmpty,"legacy conflict refuses capture before constructing engine")
check(model.message.contains("Quit M8 Studio Sound"),"legacy refusal actionable in English")
model.english = false
check(model.message.contains("Закрийте M8 Studio Sound"),"legacy refusal updates live to Ukrainian")
companionOpen = false; model.choose(bass); model.apply()
eventually { model.running && !model.busy }
check(model.gains == bass.gains && model.canBypass,"same model starts desired gains after conflict clears")
check(f.snapshot().count == 1,"one engine for the integrated model")
model.choose(warm)
check(model.dirty && model.running,"editing a running preset waits for explicit apply")
model.apply(); eventually { model.running && !model.busy && !model.dirty }
check(f.snapshot().count == 2 && f.snapshot()[0].stops == 1,"reapply disposes old engine exactly once")
f.changeRoute(nil); model.outputDidChange()
check(!model.running && model.busy && !model.canBypass,"output change immediately invalidates active EQ")
eventually { !model.busy }
check(!model.eligible && f.snapshot()[1].stops == 1,"other output restores native playback and releases engine")
model.apply(); check(f.snapshot().count == 2 && !model.running,"unsupported output cannot start EQ")
f.changeRoute(SoundRoute(uid:"fixture-monitor",sampleRate:48000)); model.outputDidChange()
check(model.eligible && !model.running,"reconnection does not auto-enable capture")
f.delayNext = true; model.apply()
eventually { f.snapshot().count == 3 }
let pending = f.snapshot()[2]
check(pending.started.wait(timeout:.now()+1) == .success,"synthetic start is in flight")
model.stop(); check(model.busy && !model.canBypass && !model.running,"bypass invalidates pending start immediately")
pending.release.signal(); eventually { !model.busy }
check(!model.running && pending.stops == 1,"stale startup cannot reactivate EQ")
f.failNext = true; model.english = true; model.apply()
eventually { !model.busy }
check(!model.running && !model.canBypass && f.snapshot()[3].stops == 1,"failed startup tears down partial session and clears active state")
check(model.message.contains("EQ could not start") && model.message.contains("Synthetic capture unavailable"),"failure gives actionable English status")
model.english = false
check(model.message.contains("EQ не запущено"),"failure status follows Ukrainian language without retry")
model.apply(); eventually { model.running && !model.busy }
check(f.snapshot().count == 5,"explicit retry after failure creates one fresh session")
model.shutdown()
check(!model.running && !model.busy && !model.canBypass,"shutdown clears active and pending UI state")
check(f.snapshot()[4].stops == 1,"shutdown releases active session exactly once")
model.shutdown(); model.apply()
check(!model.running && f.snapshot().count == 5 && f.snapshot()[4].stops == 1,"repeated shutdown is safe and prevents subsequent starts")

// Actual-model output memory and immutable processing configuration payload.
reset()
let outputFixture = Fixture()
let configLock = NSLock()
var receivedConfigurations = [StereoControls]()
let perOutput = SoundModel(preferences:prefs,legacyPreferences:legacy,companionRunning:{false},
    observeHardware:false,routeOverride:outputFixture.readRoute,
    makeConfiguredSession:{ gains,stereo in
        configLock.lock(); receivedConfigurations.append(stereo); configLock.unlock()
        return outputFixture.makeSession(gains)
    })
perOutput.choose(bass); perOutput.stereo.balance = 0.25; perOutput.stereo.mono = true
perOutput.stereo.leftTrim = -2; perOutput.stereo.nightMode = true; perOutput.stereoEdited()
let desiredStereo = perOutput.stereo
perOutput.apply(); eventually { perOutput.running && !perOutput.busy }
configLock.lock(); let received = receivedConfigurations; configLock.unlock()
check(received == [desiredStereo],"actual engine request carries immutable stereo settings")
perOutput.stereo.rightTrim = -4; perOutput.stereoEdited()
check(perOutput.dirty,"stereo edit waits for explicit Apply")
outputFixture.changeRoute(SoundRoute(uid:"second-display",sampleRate:48000)); perOutput.outputDidChange()
eventually { !perOutput.busy }
check(!perOutput.running && perOutput.stereo == StereoControls(),"new output starts neutral and cannot retain previous channel imbalance")
check(perOutput.gains == warm.gains,"new output uses startup baseline rather than the previous output EQ")
perOutput.choose(SoundPreset.all.first(where:{$0.id == "voice"})!)
perOutput.stereo.rightTrim = -1; perOutput.stereoEdited()
outputFixture.changeRoute(SoundRoute(uid:"fixture-monitor",sampleRate:48000)); perOutput.outputDidChange()
check(perOutput.gains == bass.gains && perOutput.stereo.rightTrim == -4 && perOutput.stereo.mono,"returning output restores its own saved settings without enabling EQ")
check(!perOutput.running && !perOutput.busy,"restoring per-output settings never starts capture")
perOutput.resetStereo()
check(perOutput.stereo == StereoControls() && perOutput.gains == bass.gains,"Reset stereo keeps accepted EQ bands")
let settingsStore = OutputSoundPreferences(preferences:prefs)
check(settingsStore.load("second-display")?.stereo.rightTrim == -1,"second output settings remain independent")
settingsStore.save(.init(gains:bass.gains,stereo:StereoControls(balance:2)),for:"invalid-output")
check(settingsStore.load("invalid-output") == nil,"invalid channel settings never persist")
perOutput.shutdown()

// A companion may be opened after capture has started or while it is pending.
reset()
let handoffFixture = Fixture(); var lateCompanion = false
let handoff = SoundModel(preferences:prefs,legacyPreferences:legacy,companionRunning:{lateCompanion},
    observeHardware:false,routeOverride:handoffFixture.readRoute,makeSession:handoffFixture.makeSession)
handoff.apply(); eventually { handoff.running && !handoff.busy }
lateCompanion = true; handoff.outputDidChange()
check(!handoff.running && handoff.busy && !handoff.canBypass,"late companion immediately invalidates the active integrated processor")
eventually { !handoff.busy }
check(handoffFixture.snapshot()[0].stops == 1,"late companion handoff releases the active session once")
handoff.english = true
check(handoff.message.contains("Quit M8 Studio Sound"),"late companion has an actionable handoff notice")
lateCompanion = false; handoff.outputDidChange()
check(!handoff.running && handoffFixture.snapshot().count == 1,"closing companion never auto-starts integrated capture")
handoffFixture.delayNext = true; handoff.apply()
eventually { handoffFixture.snapshot().count == 2 }
let lateStartup = handoffFixture.snapshot()[1]
check(lateStartup.started.wait(timeout:.now()+1) == .success,"handoff fixture startup in flight")
lateCompanion = true; _ = handoff.checkCompanionConflict()
lateStartup.release.signal(); eventually { !handoff.busy }
check(!handoff.running && lateStartup.stops == 1,"companion opening during startup cancels late success")
handoff.apply()
check(handoffFixture.snapshot().count == 2 && !handoff.running,"repeated companion refusal cannot create another engine")
handoff.shutdown()

print("\(passed) integrated SoundModel checks passed; synthetic routes only")
