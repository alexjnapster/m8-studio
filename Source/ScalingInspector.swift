import SwiftUI
import CoreGraphics

struct ScalingInspector:View {
    @ObservedObject var model:DeskModel
    @ViewState private var expanded = false
    @ViewState private var hiDPIOnly = true
    @ViewState private var modes:[CGDisplayMode] = []
    private var key:String { "\(model.hardware.selected):\(model.hardware.current?.mode?.ioDisplayModeID ?? 0)" }
    private var visible:[CGDisplayMode] { modes.filter { (!hiDPIOnly || $0.pixelWidth > $0.width) && (!model.isM8 || $0.refreshRate <= 60.5) } }
    var body:some View {
        DeskCard(title:"SCALING EXPLORER",icon:"textformat.size") {
            if model.isM8 {
                Text(L("For your 4K M80B: 1920 × 1080 HiDPI maps a 3840 × 2160 render buffer to the panel. 2560 × 1440 HiDPI renders 5120 × 2880 before downsampling; it offers more workspace, with a different text and GPU workload tradeoff.")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true)
            }
            DisclosureGroup(L("Compare display modes"),isExpanded:$expanded) {
                VStack(alignment:.leading,spacing:12) {
                    Toggle(L("HiDPI only"),isOn:$hiDPIOnly).toggleStyle(.switch).controlSize(.small)
                    if visible.isEmpty { Text(L("No matching modes are reported by this display.")).font(.caption).foregroundStyle(.secondary) }
                    ScrollView {
                        LazyVStack(spacing:0) {
                            ForEach(visible,id:\.ioDisplayModeID) { mode in
                                HStack(spacing:12) {
                                    VStack(alignment:.leading,spacing:4) {
                                        Text(modeLabel(mode)).font(.system(size:12,weight:.medium,design:.monospaced))
                                        Text(LF("Render buffer: %@ × %@",[String(mode.pixelWidth),String(mode.pixelHeight)])).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if model.hardware.current?.mode?.ioDisplayModeID == mode.ioDisplayModeID { Image(systemName:"checkmark.circle.fill").foregroundStyle(DeskStyle.brand).accessibilityLabel(L("Current")) }
                                    else { Button(L("Preview")) { model.applyMode(mode) }.controlSize(.small).help(L("Preview for 15 seconds")).disabled(model.hardware.rollbackSeconds > 0) }
                                }.padding(.vertical,10)
                                Divider().opacity(0.4)
                            }
                        }
                    }.frame(maxHeight:240)
                }.padding(.top,12)
            }
            Text(L("The render buffer is not the panel resolution. Only modes reported by macOS are offered; every change uses timed recovery.")).font(.caption2).foregroundStyle(.secondary)
        }.task(id:key) { modes = model.hardware.current?.modes ?? [] }
    }
}
