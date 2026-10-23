import SwiftUI
import AppKit
import CoreAudio


struct SoundPreset: Identifiable {
    let id: String, uk: String, en: String, detailUK: String, detailEN: String
    let gains: [Double]
    static let all: [SoundPreset] = [
        .init(id: "warm", uk: "Теплий звук", en: "Warmth", detailUK: "М’які високі · повніші голоси", detailEN: "Softer treble · fuller voices", gains: [0,2.5,1,0,0,-0.5,-2,-1.5]),
        .init(id: "bass", uk: "Бас +", en: "Bass +", detailUK: "Контрольований бас · менше різкості", detailEN: "Controlled bass · less harshness", gains: [1,4,1.5,0,0,-1,-2.5,-1.5]),
        .init(id: "voice", uk: "Чіткі голоси", en: "Clear voices", detailUK: "Розмови, подкасти та відеозв’язок", detailEN: "Calls, podcasts and dialogue", gains: [-2,0,0,0,1,1.5,-1,-1]),
        .init(id: "flat", uk: "Рівний EQ", en: "Flat EQ", detailUK: "Без підсилення смуг · із захистом", detailEN: "No band boosts · protection on", gains: [0,0,0,0,0,0,0,0])
    ]
}

final class SoundProcessor: AudioProcessor {
    let gains: [Double]
    private(set) var dsp: OpaquePointer?
    init(gains: [Double]) { self.gains = gains }
    func prepare(sampleRate: Double) {
        if let dsp { m8_destroy(dsp) }
        dsp = gains.withUnsafeBufferPointer { m8_create(sampleRate, $0.baseAddress) }
    }
    func process(_ samples: UnsafeMutablePointer<Float>, frameCount: Int, channelCount: Int) {
        guard let dsp, channelCount == 2 else { return }
        m8_process(dsp, samples, Int32(frameCount))
    }
    deinit { if let dsp { m8_destroy(dsp) } }
}

final class SoundModel: ObservableObject {
    @Published var english = UserDefaults.standard.bool(forKey: "soundEnglish") {
        didSet { UserDefaults.standard.set(english, forKey: "soundEnglish") }
    }
    @Published var gains: [Double] = UserDefaults.standard.array(forKey: "soundGains") as? [Double] ?? SoundPreset.all[0].gains
    @Published var selectedPreset = UserDefaults.standard.string(forKey: "soundPreset") ?? "warm"
    @Published private(set) var running = false
    @Published private(set) var busy = false
    @Published private(set) var route = "—"
    @Published private(set) var eligible = false
    @Published private(set) var message = ""
    @Published private(set) var peak: Float = 0
    @Published private(set) var reduction: Float = 0
    @Published private(set) var headroom: Double = 0
    @Published private(set) var sampleRate: Double = 0
    @Published private(set) var receivedAudio = false
    @Published var dirty = false
    private let queue = DispatchQueue(label: "local.M8Studio.Sound.lifecycle", qos: .userInitiated)
    // Accessed only on lifecycle queue; the processor owns atomically published meters.
    private var engine: SystemAudioTapEngine?
    private var processor: SoundProcessor?
    private var activeUID: String?
    private var activeRate: Double = 0
    private var meterTimer: Timer?
    private var sleepToken: NSObjectProtocol?
    private var outputListener: AudioObjectPropertyListenerBlock?
    private var listeners = [AudioObjectPropertySelector]()
    private var shuttingDown = false
    func t(_ uk: String, _ en: String) -> String { english ? en : uk }
    init() {
        if gains.count != 8 || gains.contains(where: { !$0.isFinite || abs($0)>6 }) { gains = SoundPreset.all[0].gains }
        refreshRoute()
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.routeChanged() }
        outputListener = listener
        for selector in [kAudioHardwarePropertyDefaultOutputDevice,kAudioHardwarePropertyDevices] {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, listener) == noErr { listeners.append(selector) }
        }
        sleepToken = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() }
    }
    private func isSamsung(_ device: AudioOutputDevice) -> Bool {
        // Restrict to the actual Samsung display audio endpoint, never a headset.
        let name = device.name.lowercased()
        guard name.contains("samsung"), !name.contains("aggregate") else { return false }
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreamFormat, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        var f = AudioStreamBasicDescription(); var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        return AudioObjectGetPropertyData(device.id,&a,0,nil,&size,&f) == noErr && f.mFormatID == kAudioFormatLinearPCM && f.mChannelsPerFrame == 2
    }
    func refreshRoute() {
        if let device = try? AudioDevices.defaultOutput() {
            route = device.name; eligible = isSamsung(device)
        } else { route = "—"; eligible = false }
    }
    private func routeChanged() {
        refreshRoute()
        guard running || busy else { return }
        queue.async { [weak self] in
            guard let self else { return }
            let device = try? AudioDevices.defaultOutput()
            if device?.uid != self.activeUID || device?.sampleRate != self.activeRate || device.map({ !self.isSamsung($0) }) ?? true {
                self.engine?.stop(); self.engine = nil; self.processor = nil; self.activeUID = nil
                DispatchQueue.main.async {
                    self.running = false; self.busy = false; self.stopMeter()
                    self.message = self.t("Вихід змінився. Звук macOS відновлено; EQ вимкнено.", "Output changed. Native playback restored; EQ is off.")
                }
            }
        }
    }
    func choose(_ preset: SoundPreset) {
        gains = preset.gains; selectedPreset = preset.id; dirty = true; save()
    }
    func edited() { selectedPreset = "custom"; dirty = true; save() }
    private func save() {
        UserDefaults.standard.set(gains, forKey: "soundGains")
        UserDefaults.standard.set(selectedPreset, forKey: "soundPreset")
    }
    func apply() {
        guard !busy, !shuttingDown, let output = try? AudioDevices.defaultOutput(), isSamsung(output) else { refreshRoute(); return }
        save(); busy = true
        message = t("Запуск… Підтвердьте доступ до системного аудіо, якщо macOS запитає.", "Starting… Allow system audio access if macOS asks.")
        let desired = gains
        queue.async { [weak self] in
            guard let self else { return }
            self.engine?.stop(); self.engine = nil; self.processor = nil
            do {
                guard let current = try AudioDevices.defaultOutput(), current.uid == output.uid, self.isSamsung(current) else { throw NSError(domain: "M8 Sound", code: 1, userInfo: [NSLocalizedDescriptionKey:"Output changed before start"] ) }
                let processor = SoundProcessor(gains: desired)
                let engine = SystemAudioTapEngine(processor: processor)
                self.processor = processor; self.engine = engine
                self.activeUID = output.uid; self.activeRate = output.sampleRate
                try engine.start(outputUID: output.uid)
                guard processor.dsp != nil, let after = try AudioDevices.defaultOutput(), after.uid == output.uid, after.sampleRate == output.sampleRate else { throw NSError(domain: "M8 Sound", code: 2, userInfo: [NSLocalizedDescriptionKey:"Output changed during start"] ) }
                let headroom = m8_headroom(processor.dsp)
                DispatchQueue.main.async {
                    self.running = true; self.busy = false; self.dirty = self.gains != desired
                    self.headroom = headroom; self.sampleRate = output.sampleRate; self.receivedAudio = false
                    self.message = ""; self.startMeter()
                }
            } catch {
                self.engine?.stop(); self.engine = nil; self.processor = nil; self.activeUID = nil
                let errorMessage = error.localizedDescription
                DispatchQueue.main.async {
                    self.running = false; self.busy = false; self.stopMeter()
                    self.message = self.t("EQ не запущено. Звук macOS відновлено. ", "EQ could not start. Native playback restored. ") + errorMessage
                }
            }
        }
    }
    func stop() {
        guard !shuttingDown else { return }
        busy = true
        queue.async { [weak self] in
            guard let self else { return }
            self.engine?.stop(); self.engine = nil; self.processor = nil; self.activeUID = nil
            DispatchQueue.main.async {
                self.running = false; self.busy = false; self.stopMeter()
                self.message = self.t("Оригінальний звук macOS · EQ вимкнено", "Original macOS sound · EQ off")
            }
        }
    }
    private func startMeter() {
        stopMeter()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.meter() }
    }
    private func stopMeter() { meterTimer?.invalidate(); meterTimer = nil; peak = 0; reduction = 0 }
    private func meter() {
        routeChanged()
        queue.async { [weak self] in
            guard let self, let dsp = self.processor?.dsp else { return }
            let peak = m8_peak(dsp), reduction = m8_reduction(dsp), frames = m8_frames(dsp)
            DispatchQueue.main.async { if self.running { self.peak = peak; self.reduction = reduction; self.receivedAudio = self.receivedAudio || (frames > 0 && peak > 0.00001) } }
        }
    }
    func shutdown() {
        shuttingDown = true; stopMeter()
        if let outputListener {
            for selector in listeners {
                var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
                AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, outputListener)
            }
        }
        if let sleepToken { NSWorkspace.shared.notificationCenter.removeObserver(sleepToken) }
        queue.sync { engine?.stop(); engine = nil; processor = nil; activeUID = nil }
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
    let frequencies = ["63","125","250","500","1k","2k","4k","8k"]
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("M8 STUDIO / SOUND", systemImage: "waveform").font(.caption.bold()).tracking(2).foregroundStyle(.secondary)
                        Text(model.t("Звук із характером.", "Find your sound.")).font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(model.t("Більше тепла. Менше різкості. Ваш баланс.", "More warmth. Less harshness. Your balance.")).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(model.english ? "УКР" : "EN") { model.english.toggle() }.help(model.t("English interface", "Український інтерфейс"))
                }
                HStack(spacing: 12) {
                    Image(systemName: "display").font(.title2).foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(model.route).font(.headline)
                        Text(model.running ? String(format: model.t("Стерео PCM · %.0f кГц · затримка DSP 5 мс", "Stereo PCM · %.0f kHz · 5 ms DSP lookahead"), model.sampleRate/1000) : model.t("Обробка лише на вашому Mac · без запису аудіо", "Processed on your Mac · no audio recordings")).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle().fill(model.running ? Color.green : Color.secondary.opacity(0.4)).frame(width: 8,height: 8)
                    Text(model.running ? model.t("EQ активний", "EQ active") : model.t("Оригінал", "Original")).font(.caption.bold())
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
                                if model.selectedPreset == preset.id { Image(systemName:"checkmark.circle.fill").foregroundStyle(.cyan) }
                            }.padding(14).frame(maxWidth:.infinity,alignment:.leading)
                            .background(model.selectedPreset == preset.id ? Color.cyan.opacity(0.12) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius:14).stroke(model.selectedPreset == preset.id ? Color.cyan.opacity(0.5) : .clear))
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
                                Text(String(format:"%+.1f",model.gains[index])).monospacedDigit().font(.caption).foregroundStyle(model.gains[index] > 0 ? .cyan : .secondary)
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
                        ProgressView(value:Double(model.peak)).tint(.cyan).accessibilityLabel(model.t("Вихідний рівень", "Output peak"))
                        Text(model.receivedAudio ? (model.reduction > 0.01 ? model.t("Лімітер стримує піки", "Limiter controlling peaks") : model.t("Аудіо надходить · без перевантаження", "Audio flowing · protected output")) : model.t("Увімкніть музику для перевірки звуку", "Play music to check audio flow")).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(18).background(Color.secondary.opacity(0.06),in:RoundedRectangle(cornerRadius:18))
                HStack {
                    Button { model.apply() } label: {
                        Label(model.running ? model.t("Застосувати EQ", "Apply EQ") : model.t("Увімкнути EQ", "Enable EQ"),systemImage:"waveform.path")
                            .frame(maxWidth:.infinity).padding(.vertical,8)
                    }.buttonStyle(.borderedProminent).tint(.cyan).disabled(model.busy || !model.eligible || (model.running && !model.dirty))
                    Button { model.stop() } label: { Label(model.t("Оригінал / Bypass", "Original / Bypass"),systemImage:"ear").padding(.vertical,8) }.disabled(!model.running || model.busy)
                }
                if model.dirty { Text(model.t("Є незастосовані зміни. Натисніть «Застосувати EQ».", "Changes pending. Press Apply EQ to hear them.")).font(.caption).foregroundStyle(.orange) }
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
            }.padding(26)
        }.frame(minWidth:600,idealWidth:650,minHeight:720,idealHeight:850)
        .background(LinearGradient(colors:[Color.cyan.opacity(0.035),Color.clear],startPoint:.topLeading,endPoint:.bottomTrailing))
    }
}

final class SoundDelegate: NSObject, NSApplicationDelegate {
    var model: SoundModel?
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { model?.shutdown(); return .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool { false }
}

struct SoundMenu: View {
    @ObservedObject var model: SoundModel
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Text(model.route)
        Text(model.running ? model.t("EQ активний", "EQ active") : model.t("EQ вимкнено", "EQ off"))
        Divider()
        ForEach(SoundPreset.all) { p in Button(model.english ? p.en : p.uk) { model.choose(p); if model.running { model.apply() } }.disabled(model.busy) }
        Divider()
        Button(model.running ? model.t("Оригінал / Bypass", "Original / Bypass") : model.t("Увімкнути EQ", "Enable EQ")) { if model.running { model.stop() } else { model.apply() } }.disabled(model.busy || (!model.running && !model.eligible))
        Button(model.t("Показати еквалайзер", "Show equalizer")) { openWindow(id:"sound"); NSApp.activate(ignoringOtherApps:true) }
        Button(model.t("Вийти", "Quit")) { NSApp.terminate(nil) }
    }
}

@main struct M8SoundApp: App {
    @NSApplicationDelegateAdaptor(SoundDelegate.self) var delegate
    @StateObject private var model = SoundModel()
    var body: some Scene {
        WindowGroup("M8 Studio Sound",id:"sound") {
            SoundView(model:model).onAppear { delegate.model=model }
        }.defaultSize(width:650,height:850)
        MenuBarExtra("M8 Studio Sound",systemImage:"waveform.circle") {
            SoundMenu(model:model)
        }
    }
}
