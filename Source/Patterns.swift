import Cocoa
import SwiftUI

enum PatternKind: String, CaseIterable, Identifiable {
    case chroma = "Text & chroma", gray = "Grayscale & clipping", gradient = "Smooth gradients", pixels = "Solid colors & pixels", geometry = "Geometry & sharpness"
    var id: String { rawValue }
}
@MainActor final class PatternController {
    static let shared = PatternController()
    var window: NSWindow?
    func show(_ kind: PatternKind, screen: NSScreen?) {
        guard let screen else { return }
        window?.close()
        let w = PatternWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.title = "M8 Studio · " + kind.rawValue
        w.isReleasedWhenClosed = false; w.level = .floating; w.backgroundColor = .black
        w.contentView = NSHostingView(rootView: PatternView(kind: kind) { [weak self] in self?.window?.close(); self?.window = nil })
        window = w; w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}
final class PatternWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { close() } else { super.keyDown(with: event) } }
}
struct PatternView: View {
    let kind: PatternKind; let close: () -> Void
    @ViewState<Int> var index = 0
    let colors: [Color] = [.white, .black, .red, .green, .blue]
    var body: some View {
        ZStack {
            Color.black
            switch kind {
            case .chroma:
                VStack(spacing: 20) {
                    Text(L("Chroma & text clarity")).font(.system(size: 32, weight: .semibold))
                    Text(L("Look for colored fringes, blur or missing fine strokes. View at native resolution.")).foregroundStyle(.gray)
                    ForEach([Color.red, Color.blue, Color(nsColor: .magenta), Color.white], id: \.self) { color in
                        Text(L("The quick brown fox jumps over the lazy dog. 0123456789\nЧіткість тексту · RGB · 4:4:4 · ABCDEFGHIJKLMNOPQRSTUVWXYZ")).font(.system(size: 13, design: .monospaced)).foregroundStyle(color).padding(12).frame(maxWidth: .infinity).background(.gray.opacity(0.2))
                    }
                    Canvas { context, size in
                        for x in stride(from: 0, to: size.width, by: 2) { context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(.white)) }
                    }.frame(height: 80)
                    Text(L("Alternating lines above use logical points; judge single-pixel detail only at 1× scale.")).font(.caption).foregroundStyle(.gray)
                }.padding(80)
            case .gray:
                VStack(spacing: 28) {
                    Text(L("Grayscale & clipping")).font(.largeTitle)
                    Text(L("Each adjacent patch should remain distinguishable. These are SDR patterns.")).foregroundStyle(.gray)
                    HStack(spacing: 0) { ForEach(0..<17) { i in VStack { Rectangle().fill(Color(white: Double(i)/16)); Text(LF("%@",[String(describing:i*16 == 256 ? 255 : i*16)])).font(.caption).foregroundStyle(.gray) } } }.frame(height: 230)
                    HStack(spacing: 2) { ForEach([0,4,8,12,16,20,24,28,32], id: \.self) { i in Rectangle().fill(Color(white: Double(i)/255)).overlay(Text(LF("%@",[String(describing:i)])).foregroundStyle(.gray).font(.caption), alignment: .bottom) } }.frame(height: 150)
                    HStack(spacing: 2) { ForEach([223,227,231,235,239,243,247,251,255], id: \.self) { i in Rectangle().fill(Color(white: Double(i)/255)).overlay(Text(LF("%@",[String(describing:i)])).foregroundStyle(.black).font(.caption), alignment: .bottom) } }.frame(height: 150)
                }.padding(70)
            case .gradient:
                VStack(spacing: 18) { Text(L("Smooth gradients · SDR")).font(.largeTitle); ForEach([Color.white, .red, .green, .blue], id: \.self) { color in Rectangle().fill(LinearGradient(colors: [.black, color], startPoint: .leading, endPoint: .trailing)).frame(maxHeight: .infinity) }; Text(L("Look for abrupt steps and tint shifts. This is a visual check, not a bit-depth measurement.")).foregroundStyle(.gray) }.padding(70)
            case .pixels:
                colors[index].onTapGesture { index = (index+1)%colors.count }
                VStack { Spacer(); Button(L("Next color · click anywhere")) { index = (index+1)%colors.count }.buttonStyle(.plain).foregroundStyle(.white).padding(12).background(Color(white: 0.18), in: Capsule()).padding(.bottom, 70) }
            case .geometry:
                Canvas { ctx, size in
                    for x in stride(from: 0.0, through: size.width, by: 40) { var p = Path(); p.move(to: CGPoint(x:x,y:0)); p.addLine(to: CGPoint(x:x,y:size.height)); ctx.stroke(p, with: .color(.gray), lineWidth: 1) }
                    for y in stride(from: 0.0, through: size.height, by: 40) { var p = Path(); p.move(to: CGPoint(x:0,y:y)); p.addLine(to: CGPoint(x:size.width,y:y)); ctx.stroke(p, with: .color(.gray), lineWidth: 1) }
                    let s = min(size.width,size.height)*0.7
                    ctx.stroke(Path(ellipseIn: CGRect(x:(size.width-s)/2,y:(size.height-s)/2,width:s,height:s)), with: .color(.white), lineWidth: 2)
                }.padding(20)
                Text(L("Geometry · circle should be round · edges should be visible")).font(.headline).padding().background(.black).frame(maxHeight: .infinity, alignment: .top)
            }
            VStack { HStack { Spacer(); Button(L("Close · Esc"), action: close).keyboardShortcut(.cancelAction).buttonStyle(.plain).foregroundStyle(.white).padding(12).background(Color(white: 0.18), in: Capsule()) }; Spacer() }.padding(20)
        }.foregroundStyle(.white).ignoresSafeArea()
    }
}
