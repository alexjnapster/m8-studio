import Cocoa
import AVFoundation

final class TonePlayer {
    static let shared = TonePlayer()
    private var player: AVAudioPlayer?
    func play(channel: Int) {
        let rate: UInt32 = 48000; let frames = 12000
        var data = Data()
        func ascii(_ s: String) { data.append(contentsOf: s.utf8) }
        func u16(_ v: UInt16) { var v = v.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        func u32(_ v: UInt32) { var v = v.littleEndian; withUnsafeBytes(of: &v) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36+frames*4)); ascii("WAVEfmt "); u32(16); u16(1); u16(2); u32(rate); u32(rate*4); u16(4); u16(16); ascii("data"); u32(UInt32(frames*4))
        for i in 0..<frames {
            let envelope = min(1, Double(i)/600) * min(1, Double(frames-i)/600)
            let sample = Int16(sin(Double(i)*2*Double.pi*440/Double(rate))*1800*envelope)
            for c in 0..<2 { u16(UInt16(bitPattern: c == channel ? sample : 0)) }
        }
        player = try? AVAudioPlayer(data: data); player?.play()
    }
}
