import SwiftUI
import AppKit
import CoreAudio


final class SoundProcessor: AudioProcessor {
    let gains: [Double]
    let stereo:StereoControls
    private(set) var dsp: OpaquePointer?
    init(gains: [Double], stereo:StereoControls = .init()) { self.gains = gains; self.stereo = stereo }
    func prepare(sampleRate: Double) {
        if let dsp { m8_destroy(dsp) }
        dsp = gains.withUnsafeBufferPointer { m8_create_with_options(sampleRate, $0.baseAddress, stereo.balance, stereo.mono ? 1:0, stereo.leftTrim, stereo.rightTrim, stereo.nightMode ? 1:0) }
    }
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        guard let dsp, channelCount == 2 else { return }
        m8_process(dsp, samples, Int32(frameCount))
    }
    deinit { if let dsp { m8_destroy(dsp) } }
}

private final class ProcessingSession: SoundSession {
    private let processor: SoundProcessor
    private let engine: SystemAudioTapEngine
    init(gains: [Double], stereo:StereoControls = .init()) {
        let processor = SoundProcessor(gains: gains,stereo:stereo)
        self.processor = processor; engine = SystemAudioTapEngine(processor: processor)
    }
    func start(route: SoundRoute) throws {
        try engine.start(outputUID: route.uid)
        guard processor.dsp != nil else { throw NSError(domain: "M8 Sound", code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Unsupported DSP configuration"]) }
    }
    func stop() { engine.stop() }
    var headroom: Double { m8_headroom(processor.dsp) }
    var meters: SoundMeters { SoundMeters(peak: m8_peak(processor.dsp), reduction: m8_reduction(processor.dsp), frames: m8_frames(processor.dsp)) }
}

#if (M8_SOUND_PREVIEW || M8_UI_PREVIEW) && !M8_SOUND_HARDWARE_TEST
// A synthetic blocking start for native cancellation testing, never a HAL tap.
private final class PreviewSoundSession: SoundSession {
    func start(route: SoundRoute) throws { Thread.sleep(forTimeInterval: 8) }
    func stop() {}
    var headroom: Double { 5.5 }
    var meters: SoundMeters { SoundMeters() }
}
#endif

final class SoundModel: ObservableObject {
    @Published var english: Bool {
        didSet { preferences.set(english, forKey: "soundEnglish") }
    }
    @Published var gains: [Double]
    @Published var selectedPreset: String
    @Published var stereo = StereoControls()
    @Published private(set) var running = false
    @Published private(set) var busy = false
    @Published private(set) var route = "—"
    @Published private(set) var eligible = false
    private enum Notice { case none, starting, stopping, off, outputChanged, legacyCompanion, failure(String) }
    @Published private var notice = Notice.none
    var message: String {
        switch notice {
        case .none: return ""
        case .legacyCompanion: return t("Закрийте M8 Studio Sound перед запуском вбудованого EQ. Ваш звук не змінено.", "Quit M8 Studio Sound before enabling integrated EQ. Your audio has not changed.")
        case .starting: return t("Запуск… Підтвердьте доступ до системного аудіо, якщо macOS запитає.", "Starting… Allow system audio access if macOS asks.")
        case .stopping: return t("Зупинка EQ…", "Stopping EQ…")
        case .off: return t("Оригінальний звук macOS · EQ вимкнено", "Original macOS sound · EQ off")
        case .outputChanged: return t("Вихід змінився. Звук macOS відновлено; EQ вимкнено.", "Output changed. Native playback restored; EQ is off.")
        case .failure(let detail): return t("EQ не запущено. Звук macOS відновлено. ", "EQ could not start. Native playback restored. ") + detail
        }
    }
    @Published private(set) var peak: Float = 0
    @Published private(set) var reduction: Float = 0
    @Published private(set) var headroom: Double = 0
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var receivedAudio = false
    @Published var dirty = false
    private let preferences: UserDefaults
    private let companionRunning: () -> Bool
    private let sessionFactory: ([Double]) -> SoundSession
    private let configuredFactory: ([Double],StereoControls) -> SoundSession
    private let baselineGains:[Double]
    private var settingsUID:String?
    private let routeOverride: (() -> SoundRoute?)?
    private lazy var lifecycle = SoundLifecycle(readRoute: { [weak self] in self?.supportedRoute() }, makeSession: sessionFactory)
    private static func makeSession(_ gains: [Double], _ stereo:StereoControls = .init()) -> SoundSession {
        #if (M8_SOUND_PREVIEW || M8_UI_PREVIEW) && !M8_SOUND_HARDWARE_TEST
        return PreviewSoundSession()
        #else
        return ProcessingSession(gains:gains,stereo:stereo)
        #endif
    }
    private var expectedRoute: SoundRoute?
    private var meterTimer: Timer?
    private var sleepToken: NSObjectProtocol?
    private var companionLaunchToken:NSObjectProtocol?
    private var outputListener: AudioObjectPropertyListenerBlock?
    private var listeners = [AudioObjectPropertySelector]()
    private var shuttingDown = false
    var canBypass: Bool { expectedRoute != nil && (running || busy) }
    var stereoSummary:String {
        var parts=[String]()
        if stereo.mono { parts.append(t("Моно","Mono")) }
        if stereo.nightMode { parts.append(t("Нічний режим","Night listening")) }
        if stereo.balance != 0 || stereo.leftTrim != 0 || stereo.rightTrim != 0 { parts.append(t("Баланс і канали","Balance & channels")) }
        return parts.joined(separator:" · ")
    }
    func t(_ uk: String, _ en: String) -> String { english ? en : uk }
    init(preferences: UserDefaults = .standard, legacyPreferences: UserDefaults? = nil,
         companionRunning: (() -> Bool)? = nil, observeHardware: Bool = true,
         routeOverride: (() -> SoundRoute?)? = nil,
         makeSession: (([Double]) -> SoundSession)? = nil,
         makeConfiguredSession: (([Double],StereoControls) -> SoundSession)? = nil) {
        self.preferences = preferences
        self.routeOverride = routeOverride
        self.sessionFactory = makeSession ?? { Self.makeSession($0) }
        self.configuredFactory = makeConfiguredSession ?? { gains,stereo in makeSession?(gains) ?? Self.makeSession(gains,stereo) }
        #if M8_INTEGRATED_SOUND && (!M8_UI_PREVIEW || M8_SOUND_HARDWARE_TEST)
        let legacy = legacyPreferences ?? UserDefaults(suiteName:"local.M8Studio.Sound")
        self.companionRunning = companionRunning ?? {
            !NSRunningApplication.runningApplications(withBundleIdentifier:"local.M8Studio.Sound").isEmpty
        }
        #else
        let legacy = legacyPreferences
        self.companionRunning = companionRunning ?? { false }
        #endif
        let settings = SoundPreferences.load(preferences,legacy:legacy)
        gains = settings.gains; baselineGains = settings.gains; selectedPreset = settings.presetID
        english = preferences.bool(forKey:"soundEnglish")
        refreshRoute()
        guard observeHardware else { return }
        #if (M8_SOUND_PREVIEW || M8_UI_PREVIEW) && !M8_SOUND_HARDWARE_TEST
        precondition(["local.M8Studio.Sound.Preview", "local.M8Studio.Preview", "local.M8Studio.CanvasTest", "local.M8Studio.HardwareTest"].contains(Bundle.main.bundleIdentifier ?? ""))
        #else
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.outputDidChange() }
        outputListener = listener
        for selector in [kAudioHardwarePropertyDefaultOutputDevice,kAudioHardwarePropertyDevices] {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, listener) == noErr { listeners.append(selector) }
        }
        #if M8_INTEGRATED_SOUND
        companionLaunchToken = NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didLaunchApplicationNotification,object:nil,queue:.main) { [weak self] notification in
            guard let app=notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "local.M8Studio.Sound" else { return }
            self?.checkCompanionConflict()
        }
        #endif
        sleepToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() }
        #endif
    }
    private func isSamsung(_ device: AudioOutputDevice) -> Bool {
        // Share the main app's transport-aware policy; names alone match Buds.
        var transportAddress = AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyTransportType,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var transport:UInt32 = 0; var transportSize = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device.id,&transportAddress,0,nil,&transportSize,&transport) == noErr else { return false }
        var makerAddress = AudioObjectPropertyAddress(mSelector:kAudioObjectPropertyManufacturer,mScope:kAudioObjectPropertyScopeGlobal,mElement:kAudioObjectPropertyElementMain)
        var maker:CFString = "" as CFString; var makerSize = UInt32(MemoryLayout<CFString>.size)
        let makerStatus = withUnsafeMutablePointer(to:&maker) { AudioObjectGetPropertyData(device.id,&makerAddress,0,nil,&makerSize,$0) }
        var a = AudioObjectPropertyAddress(mSelector:kAudioDevicePropertyStreamFormat,mScope:kAudioObjectPropertyScopeOutput,mElement:kAudioObjectPropertyElementMain)
        var f = AudioStreamBasicDescription(); var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        guard AudioObjectGetPropertyData(device.id,&a,0,nil,&size,&f) == noErr else { return false }
        return samsungEQRouteEligible(name:device.name,manufacturer:makerStatus == noErr ? maker as String:"",
            transport:transport,uid:device.uid,formatID:f.mFormatID,channels:f.mChannelsPerFrame,sampleRate:f.mSampleRate)
    }

    func refreshRoute() {
        if let routeOverride { route = "Synthetic display"; eligible = routeOverride() != nil; loadOutputSettings(routeOverride()?.uid); return }
        #if (M8_SOUND_PREVIEW || M8_UI_PREVIEW) && !M8_SOUND_HARDWARE_TEST
        route = "Samsung — UI Preview"; eligible = true; loadOutputSettings("synthetic-display")
        #else
        if let device = try? AudioDevices.defaultOutput() {
            route = device.name; eligible = isSamsung(device); loadOutputSettings(eligible ? device.uid:nil)
        } else { route = "—"; eligible = false; loadOutputSettings(nil) }
        #endif
    }
    private func supportedRoute() -> SoundRoute? {
        if let routeOverride { return routeOverride() }
        #if (M8_SOUND_PREVIEW || M8_UI_PREVIEW) && !M8_SOUND_HARDWARE_TEST
        return SoundRoute(uid: "synthetic-display", sampleRate: 48000)
        #else
        guard let output = try? AudioDevices.defaultOutput(), isSamsung(output) else { return nil }
        return SoundRoute(uid: output.uid, sampleRate: output.sampleRate)
        #endif
    }
    @discardableResult func checkCompanionConflict() -> Bool {
        guard !shuttingDown, companionRunning() else { return false }
        if canBypass { stop(reason:.legacyCompanion) }
        return true
    }
    func outputDidChange() {
        guard !shuttingDown else { return }
        refreshRoute()
        if checkCompanionConflict() { return }
        if let expectedRoute, supportedRoute() != expectedRoute {
            stop(reason: .outputChanged)
        }
    }
    private func loadOutputSettings(_ uid:String?) {
        guard uid != settingsUID else { return }
        settingsUID = uid
        guard let uid else { return }
        let saved = OutputSoundPreferences(preferences:preferences).load(uid)
        gains = saved?.gains ?? baselineGains; stereo = saved?.stereo ?? .init()
        selectedPreset = SoundPreset.all.first(where:{$0.gains == gains})?.id ?? "custom"
        dirty = false
    }
    func stereoEdited() { dirty = true; save() }
    func resetStereo() { stereo = .init(); stereoEdited() }
    func choose(_ preset: SoundPreset) {
        gains = preset.gains; selectedPreset = preset.id; dirty = true; save()
    }
    func edited() { selectedPreset = "custom"; dirty = true; save() }
    private func save() {
        preferences.set(gains, forKey: "soundGains")
        preferences.set(selectedPreset, forKey: "soundPreset")
        if let settingsUID { OutputSoundPreferences(preferences:preferences).save(.init(gains:gains,stereo:stereo),for:settingsUID) }
    }
    func apply() {
        if checkCompanionConflict() { if !busy { notice = .legacyCompanion }; return }
        guard !busy, !shuttingDown, let output = supportedRoute() else { refreshRoute(); return }
        guard stereo.valid, gains.count == 8, gains.allSatisfy({$0.isFinite && abs($0) <= 6}) else { return }
        save(); busy = true; expectedRoute = output
        notice = .starting
        let desired = gains, desiredStereo = stereo
        let create = configuredFactory
        lifecycle.start(route: output, gains: desired, sessionFactory:{ create($0,desiredStereo) }) { [weak self] event in
            guard let self else { return }
            switch event {
            case .started(let headroom):
                self.running = true; self.busy = false; self.dirty = self.gains != desired || self.stereo != desiredStereo
                self.headroom = headroom; self.sampleRate = output.sampleRate; self.receivedAudio = false
                self.notice = .none; self.startMeter()
            case .failed(let error):
                self.running = false; self.busy = false; self.expectedRoute = nil; self.stopMeter()
                self.notice = .failure(error)
            default: break
            }
        }
    }
    func stop() {
        stop(reason: .off)
    }
    private func stop(reason: Notice) {
        guard !shuttingDown else { return }
        busy = true; running = false; expectedRoute = nil; stopMeter()
        notice = .stopping
        lifecycle.stop { [weak self] event in
            guard let self else { return }
            if case .stopped = event {
                self.busy = false; self.notice = reason
            }
        }
    }
    private func startMeter() {
        stopMeter()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.meter() }
    }
    private func stopMeter() { meterTimer?.invalidate(); meterTimer = nil; peak = 0; reduction = 0 }
    private func meter() {
        outputDidChange()
        guard running else { return }
        lifecycle.meter { [weak self] event in
            guard let self, self.running, case .meters(let values) = event else { return }
            self.peak = values.peak; self.reduction = values.reduction
            self.receivedAudio = self.receivedAudio || (values.frames > 0 && values.peak > 0.00001)
        }
    }
    func shutdown() {
        guard !shuttingDown else { return }
        shuttingDown = true; running = false; busy = false; notice = .off; stopMeter()
        if let outputListener {
            for selector in listeners {
                var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, outputListener)
            }
        }
        if let sleepToken { NSWorkspace.shared.notificationCenter.removeObserver(sleepToken) }
        if let companionLaunchToken { NSWorkspace.shared.notificationCenter.removeObserver(companionLaunchToken) }
        expectedRoute = nil; lifecycle.shutdown()
    }
}

struct EQFader: NSViewRepresentable {
    @Binding var value: Double
    var label: String
    var changed: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSSlider {
        let s = NSSlider(value: value, minValue: -6, maxValue: 6, target: context.coordinator, action: #selector(Coordinator.change(_:)))
        s.isVertical = true; s.isContinuous = true; s.numberOfTickMarks = 5; s.allowsTickMarkValuesOnly = false
        s.setAccessibilityLabel(label); return s
    }
    func updateNSView(_ view: NSSlider, context: Context) { context.coordinator.parent = self; view.doubleValue = value; view.setAccessibilityValue(String(format:"%.1f dB",value)) }
    final class Coordinator: NSObject {
        var parent: EQFader
        init(_ parent: EQFader) { self.parent = parent }
        @objc func change(_ slider: NSSlider) { parent.value = (slider.doubleValue*2).rounded()/2; parent.changed() }
    }
}

struct SoundView: View {
    @ObservedObject var model: SoundModel
    var embedded = false
    var accent = Color.cyan
    let frequencies = ["63","125","250","500","1k","2k","4k","8k"]
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
                if !embedded { HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("M8 STUDIO / SOUND", systemImage: "waveform").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                        Text(model.t("Звук із характером.", "Find your sound.")).font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(model.t("Більше тепла. Менше різкості. Ваш баланс.", "More warmth. Less harshness. Your balance.")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.english ? "УКР" : "EN") { model.english.toggle() }.help(model.t("English interface", "Український інтерфейс"))
                }
                }
                HStack(spacing: 12) {
                    Image(systemName: "display").font(.title2).foregroundStyle(accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.route).font(.headline)
                        Text(model.running ? String(format: model.t("Стерео PCM · %.0f кГц · затримка DSP 5 мс", "Stereo PCM · %.0f kHz · 5 ms DSP lookahead"), model.sampleRate/1000) : model.t("Обробка лише на вашому Mac · без запису аудіо", "Processed on your Mac · no audio recordings")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle().fill(model.busy ? Color.orange : model.running ? Color.green : Color.secondary.opacity(0.4)).frame(width: 8,height: 8)
                    Text(model.busy ? model.t("Перемикання…", "Switching…") : model.running ? model.t("EQ активний", "EQ active") : model.t("Оригінал", "Original")).font(.caption.bold())
                }.padding(16).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
                LazyVGrid(columns: [GridItem(.flexible()),GridItem(.flexible())], spacing: 10) {
                    ForEach(SoundPreset.all) { preset in
                        Button { model.choose(preset) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(model.english ? preset.en : preset.uk).font(.headline)
                                    Text(model.english ? preset.detailEN : preset.detailUK).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if model.selectedPreset == preset.id { Image(systemName:"checkmark.circle.fill").foregroundStyle(accent) }
                            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                            .background(model.selectedPreset == preset.id ? accent.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius:14).stroke(model.selectedPreset == preset.id ? accent.opacity(0.5) : .clear))
                        }.buttonStyle(.plain).disabled(model.busy)
                    }
                }
                VStack(alignment:.leading,spacing:14) {
                    HStack {
                        Text(model.t("Ваш еквалайзер", "Your equalizer")).font(.title3.bold())
                        Spacer()
                        Text(model.selectedPreset == "custom" ? model.t("Власний", "Custom") : "±6 dB").font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing:0) {
                        ForEach(0..<8,id:\.self) { index in
                            VStack(spacing:8) {
                                Text(String(format:"%+.1f",model.gains[index])).monospacedDigit().font(.caption).foregroundStyle(model.gains[index] > 0 ? accent : .secondary)
                                EQFader(value:$model.gains[index],label:"\(frequencies[index]) Hz",changed:model.edited).frame(width:30,height:125)
                                Text(frequencies[index]).font(.caption.bold())
                            }.frame(maxWidth:.infinity)
                        }
                    }.disabled(model.busy)
                    HStack { Text(model.t("Бас", "Bass")); Spacer(); Text(model.t("Голоси", "Voices")); Spacer(); Text(model.t("Деталі", "Detail")) }.font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack {
                        Label(model.t("Захист від піків", "Peak protection"),systemImage:"checkmark.shield")
                        Spacer()
                        Text(model.running ? String(format: model.t("Запас %.1f dB", "Headroom %.1f dB"),model.headroom) : model.t("Автоматичний запас рівня", "Automatic headroom"))
                    }.font(.caption).foregroundStyle(.secondary)
                    if model.running {
                        ProgressView(value:Double(model.peak)).tint(accent).accessibilityLabel(model.t("Вихідний рівень", "Output peak"))
                        Text(model.receivedAudio ? (model.reduction > 0.01 ? model.t("Лімітер стримує піки", "Limiter controlling peaks") : model.t("Аудіо надходить · без перевантаження", "Audio flowing · protected output")) : model.t("Увімкніть музику для перевірки звуку", "Play music to check audio flow")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(18).background(Color.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:18))
                SoundStereoView(model:model,accent:accent)
                HStack {
                    Button { model.apply() } label: {
                        Label(model.running ? model.t("Застосувати EQ", "Apply EQ") : model.t("Увімкнути EQ", "Enable EQ"),systemImage:"waveform.path")
                            .frame(maxWidth:.infinity).padding(.vertical,8)
                    }.buttonStyle(.borderedProminent).tint(accent).disabled(model.busy || !model.eligible || (model.running && !model.dirty))
                    Button { model.stop() } label: { Label(model.t("Оригінал / Bypass", "Original / Bypass"),systemImage:"ear").padding(.vertical,8) }
                        .disabled(!model.canBypass).keyboardShortcut(".", modifiers: .command)
                }
                if model.dirty && !model.busy {
                    Text(model.running
                        ? model.t("Є незастосовані зміни. Натисніть «Застосувати EQ».", "Changes pending. Press Apply EQ to hear them.")
                        : model.t("Налаштування збережено. Натисніть «Увімкнути EQ», щоб почути їх.", "Settings saved. Press Enable EQ to hear them."))
                        .font(.caption).foregroundStyle(.orange)
                }
                if !model.message.isEmpty { Text(model.message).font(.callout).textSelection(.enabled).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color.secondary.opacity(0.07),in:RoundedRectangle(cornerRadius:12)) }
                if !model.eligible { Label(model.t("Оберіть Samsung як вихід звуку в macOS, щоб увімкнути EQ.", "Select Samsung as the macOS sound output to enable EQ."),systemImage:"speaker.badge.exclamationmark").font(.callout).foregroundStyle(.secondary) }
                DisclosureGroup(model.t("Як отримати найкращий результат", "Get the best result")) {
                    VStack(alignment:.leading,spacing:9) {
                        Text(model.t("Почніть зі Standard у меню монітора та рівного апаратного EQ. Вимкніть Adaptive Sound+ і Auto Volume, якщо вони доступні. Порівнюйте Dolby Atmos увімк./вимк. на однаковій гучності.", "Start with Standard sound and flat hardware EQ on the monitor. Turn off Adaptive Sound+ and Auto Volume if available. Compare Dolby Atmos on/off at matched loudness."))
                        Text(model.t("«Бас +» додає верхнього басу біля 125 Гц і пом’якшує різкі високі. Фільтр 50 Гц зменшує непотрібний суббас. Запас рівня може зробити звук тихішим; компенсуйте гучністю монітора.", "Bass + adds upper bass around 125 Hz and softens harsh treble. A 50 Hz filter reduces unnecessary sub-bass. Headroom can make playback quieter; compensate with monitor volume."))
                        Text(model.t("Це інженерні початкові налаштування, а не виміряна калібрація ваших динаміків і кімнати. EQ не додає фізичного глибокого басу та не вмикає Atmos. Підтримується лише стерео PCM; захищене аудіо може бути недоступне для обробки.", "These are engineered starting points, not measured calibration of your speakers and room. EQ cannot create physical deep bass or enable Atmos. Stereo PCM only; protected audio may be unavailable for processing."))
                        Text(model.t("Bypass, зміна виходу, сон і вихід із програми зупиняють обробку. Загальна затримка включає буфери Core Audio на додачу до 5 мс DSP.", "Bypass, output changes, sleep and quitting stop processing. Total latency includes Core Audio buffers in addition to 5 ms DSP."))
                    }.font(.caption).foregroundStyle(.secondary).padding(.top,8)
                }
            }.padding(embedded ? 0 : 26)
        .frame(maxWidth:.infinity)
        .background(LinearGradient(colors:[accent.opacity(0.035),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
    }
}

struct SoundStereoView:View {
    @ObservedObject var model:SoundModel
    var accent:Color
    var body:some View {
        DisclosureGroup(model.t("Стерео та нічний режим", "Stereo & night listening")) {
            VStack(alignment:.leading,spacing:14) {
                HStack {
                    Text(model.t("Баланс", "Balance"))
                    Slider(value:Binding(get:{model.stereo.balance},set:{model.stereo.balance=$0; model.stereoEdited()}),in:-1...1)
                        .accessibilityLabel(model.t("Баланс стерео", "Stereo balance"))
                    Text(String(format:"%+.0f%%",model.stereo.balance*100)).monospacedDigit().frame(width:50)
                }
                Toggle(model.t("Моно · обидва канали разом", "Mono · combine both channels"),isOn:Binding(get:{model.stereo.mono},set:{model.stereo.mono=$0; model.stereoEdited()}))
                HStack {
                    trim(model.t("Лівий канал", "Left trim"),value:$model.stereo.leftTrim)
                    trim(model.t("Правий канал", "Right trim"),value:$model.stereo.rightTrim)
                }
                Toggle(model.t("Нічний режим · м’якші перепади гучності", "Night listening · gentler volume changes"),isOn:Binding(get:{model.stereo.nightMode},set:{model.stereo.nightMode=$0; model.stereoEdited()}))
                Text(model.t("Нічний режим стискає гучні піки без автоматичного підсилення. Це не калібрація кімнати; порівнюйте на однаковій сприйнятій гучності.", "Night listening compresses louder peaks without automatic gain boost. This is not room calibration; compare at matched perceived loudness."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(model.t("Скинути стерео", "Reset stereo")) { model.resetStereo() }
                    Spacer()
                    Text(model.t("Окремо для кожного звукового виходу", "Remembered per audio output")).font(.caption).foregroundStyle(.secondary)
                }
            }.padding(.top,12).disabled(model.busy)
        }.tint(accent)
    }
    func trim(_ title:String,value:Binding<Double>)->some View {
        VStack(alignment:.leading) {
            Text(title).font(.caption)
            Slider(value:Binding(get:{value.wrappedValue},set:{value.wrappedValue=$0; model.stereoEdited()}),in:-12...0,step:0.5).accessibilityLabel(title)
            Text(String(format:"%.1f dB",value.wrappedValue)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        }
    }
}
