import SwiftUI
import AppKit

@MainActor final class VirtualCanvasController:ObservableObject {
    enum State { case off, starting, preview, active, stopping, failed }
    @Published private(set) var state = State.off
    @Published private(set) var seconds = 0
    @Published private(set) var logicalWidth = 0
    @Published private(set) var detail = ""
    @Published private(set) var targetUUID:String?
    private var process:Process?
    private var input:Pipe?
    private var output:Pipe?
    private var timer:Timer?
    private var buffer = Data()
    private var ticket = UUID()
    private var sleepObserver:NSObjectProtocol?
    init() {
        sleepObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in
            Task { @MainActor in self?.stop() }
        }
    }
    var engaged:Bool { [.starting,.preview,.active,.stopping].contains(state) }
    var stateLabel:String {
        switch state {
        case .off: return "Virtual canvas off"
        case .starting: return "Preparing HiDPI canvas…"
        case .preview: return "Preview · automatic return enabled"
        case .active: return "HiDPI canvas active"
        case .stopping: return "Returning to the physical display…"
        case .failed: return "Virtual canvas could not finish safely"
        }
    }
    func start(_ plan:VirtualCanvasPlan,display:DisplayInfo) {
        guard !engaged, process == nil, plan.valid else { return }
        logicalWidth = plan.width
        #if M8_UI_PREVIEW && !M8_CANVAS_HARDWARE_TEST
        precondition(Bundle.main.bundleIdentifier == "local.M8Studio.Preview")
        targetUUID=display.uuid; state = .preview; detail = "Simulated preview · no display changes"
        beginCountdown(); return
        #else
        let identity=SamsungDriverIdentity.match(vendor:CGDisplayVendorNumber(display.id),product:CGDisplayModelNumber(display.id))
        guard let mode=display.mode, VirtualCanvasPlan.eligible(builtIn:display.builtIn,isM80B:identity?.family == "M80B",
            mirrored:CGDisplayIsInMirrorSet(display.id) != 0,rotation:CGDisplayRotation(display.id),rate:mode.refreshRate,
            aspect:Double(mode.width)/Double(mode.height),previewing:false),
            let helper=Bundle.main.path(forResource:"VirtualCanvas",ofType:nil) else { state = .failed; detail = "Connect an unmirrored landscape M80B near 60 Hz first."; return }
        ticket=UUID(); let current=ticket
        let child=Process(), commands=Pipe(), messages=Pipe()
        child.executableURL=URL(fileURLWithPath:helper)
        child.arguments=[String(display.id),display.uuid,String(plan.width),String(ProcessInfo.processInfo.processIdentifier)]
        child.standardInput=commands; child.standardOutput=messages
        child.standardError=FileHandle.nullDevice
        state = .starting; detail=""; targetUUID=display.uuid; buffer=Data()
        process=child; input=commands; output=messages
        messages.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data=handle.availableData
            Task { @MainActor in self?.receive(data,ticket:current) }
        }
        child.terminationHandler = { [weak self] child in
            Task { @MainActor in
                guard let self, self.ticket == current else { return }
                self.output?.fileHandleForReading.readabilityHandler=nil
                self.input=nil; self.output=nil; self.process=nil; self.targetUUID=nil
                self.timer?.invalidate(); self.timer=nil; self.seconds=0
                if self.state != .failed { self.state = child.terminationStatus == 0 ? .off:.failed }
                if child.terminationStatus != 0 && self.detail.isEmpty { self.detail="The canvas stopped unexpectedly. Check macOS Displays before trying again." }
            }
        }
        do { try child.run() }
        catch { messages.fileHandleForReading.readabilityHandler=nil; process=nil; input=nil; output=nil; targetUUID=nil; state = .failed; detail=error.localizedDescription }
        #endif
    }
    private func receive(_ data:Data,ticket:UUID) {
        guard ticket == self.ticket, !data.isEmpty else { return }
        buffer.append(data)
        guard buffer.count < 32768 else { stop(); return }
        while let newline=buffer.firstIndex(of:10) {
            let line=buffer.prefix(upTo:newline); buffer.removeSubrange(...newline)
            guard let object=(try? JSONSerialization.jsonObject(with:line)) as? [String:Any], let event=object["state"] as? String else { continue }
            switch event {
            case "preview": if state == .starting { state = .preview; beginCountdown() }
            case "active": if state == .preview { timer?.invalidate(); timer=nil; seconds=0; state = .active }
            case "failed","restoreFailed": detail=object["detail"] as? String ?? ""; state = .failed
            case "stopped": if state != .failed { state = .off }; timer?.invalidate(); timer=nil; seconds=0
            default: break
            }
        }
    }
    private func beginCountdown() {
        seconds=15; timer?.invalidate()
        timer=Timer(timeInterval:1,repeats:true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.state == .preview else { return }
                self.seconds-=1; if self.seconds<=0 { self.stop() }
            }
        }
        if let timer { RunLoop.main.add(timer,forMode:.common) }
    }
    func keep() {
        guard state == .preview, seconds>0 else { return }
        #if M8_UI_PREVIEW && !M8_CANVAS_HARDWARE_TEST
        timer?.invalidate(); timer=nil; seconds=0; state = .active
        #else
        send("keep\n") // Active is acknowledged only by the independent host.
        #endif
    }
    private func send(_ command:String) { try? input?.fileHandleForWriting.write(contentsOf:Data(command.utf8)) }
    func stop() {
        guard engaged || process != nil else { return }
        timer?.invalidate(); timer=nil; seconds=0
        #if M8_UI_PREVIEW && !M8_CANVAS_HARDWARE_TEST
        state = .off; targetUUID=nil; detail=""; return
        #else
        state = .stopping; send("stop\n")
        try? input?.fileHandleForWriting.close()
        // SIGTERM also takes the helper's restoration path if stdin handling failed.
        process?.terminate()
        #endif
    }
    func shutdown() { stop() }
}

extension DeskModel {
    var showsAdvancedCanvas:Bool {
        #if M8_UI_PREVIEW && !M8_CANVAS_HARDWARE_TEST
        return true
        #else
        return isM8 || virtualCanvas.engaged
        #endif
    }
}

struct VirtualCanvasView:View {
    @ObservedObject var model:DeskModel
    @ObservedObject var canvas:VirtualCanvasController
    @ViewState private var width=2560.0
    var canStart:Bool {
        #if M8_UI_PREVIEW && !M8_CANVAS_HARDWARE_TEST
        return model.hardware.current != nil
        #else
        guard let display=model.hardware.current, let mode=display.mode else { return false }
        return VirtualCanvasPlan.eligible(builtIn:display.builtIn,isM80B:model.isM8,mirrored:CGDisplayIsInMirrorSet(display.id) != 0,
            rotation:CGDisplayRotation(display.id),rate:mode.refreshRate,aspect:Double(mode.width)/Double(mode.height),previewing:model.hardware.rollbackSeconds>0)
        #endif
    }
    var nativeMode:CGDisplayMode? {
        model.favoriteEligibleModes.first { $0.width == Int(width) && $0.height == Int(width)*9/16 && $0.pixelWidth == Int(width)*2 && $0.pixelHeight == Int(width)*9/8 }
    }
    var body:some View {
        DeskCard(title:"ADVANCED HIDPI CANVAS",icon:"rectangle.on.rectangle.angled") {
            HStack { Text(L("Desktop width")).font(.callout); Spacer(); Text("\(Int(width)) × \(Int(width)*9/16)").font(.system(.callout,design:.monospaced)) }
            Slider(value:$width,in:1280...3072,step:16).accessibilityLabel(L("HiDPI desktop width")).disabled(canvas.engaged)
            Text(LF("2× render buffer: %@ × %@",[String(Int(width)*2),String(Int(width)*9/8)])).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(L("Preview HiDPI size")) {
                    if let mode=nativeMode { model.applyMode(mode) }
                    else if let display=model.hardware.current { canvas.start(.init(width:Int(width)),display:display) }
                }.disabled(!canStart || canvas.engaged || model.hardware.rollbackSeconds>0 || !VirtualCanvasPlan(width:Int(width)).valid)
                if nativeMode != nil && !canvas.engaged { Text(L("Available directly from macOS")).font(.caption).foregroundStyle(.secondary) }
                if canvas.state == .preview { Button(L("Keep virtual canvas")) { canvas.keep() }.buttonStyle(.borderedProminent) }
                if canvas.engaged { Button(L("Return to physical display")) { canvas.stop() } }
                if canvas.seconds>0 { Text(LF("%@ s",[String(canvas.seconds)])).monospacedDigit().font(.caption) }
            }.controlSize(.small)
            Text(L(canvas.stateLabel)).font(.caption.bold())
            if !canvas.detail.isEmpty { Text(L(canvas.detail)).font(.caption).foregroundStyle(.secondary) }
            Text(L("Experimental SDR mirroring for landscape M80B at 60 Hz. Adds a virtual rendering layer, not physical panel pixels. Color, latency and HDR parity are not verified. Preview returns automatically unless kept; quitting or losing the monitor stops the canvas.")).font(.caption).foregroundStyle(.secondary)
            if !canStart && !canvas.engaged && model.hardware.rollbackSeconds == 0 { Text(L("Connect an unmirrored landscape M80B near 60 Hz first.")).font(.caption).foregroundStyle(.secondary) }
        }.onAppear { if canvas.engaged { width=Double(canvas.logicalWidth) } }
    }
}
