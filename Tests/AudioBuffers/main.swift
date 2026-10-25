import AudioToolbox
import Foundation

// Synthetic memory only: no HAL calls, tap, device, permission or audio output.
final class Fixture {
    let list: UnsafeMutableAudioBufferListPointer
    let storage: [UnsafeMutablePointer<Float>?]
    let lengths: [Int]
    init(_ channels:[UInt32], _ samples:[[Float]?]) {
        precondition(channels.count == samples.count)
        list = AudioBufferList.allocate(maximumBuffers:max(1,channels.count))
        list.unsafeMutablePointer.pointee.mNumberBuffers = UInt32(channels.count)
        var allocations = [UnsafeMutablePointer<Float>?]()
        var counts = [Int]()
        for i in channels.indices {
            let values = samples[i]
            let count = values?.count ?? 0
            counts.append(count)
            let memory = values.map { values -> UnsafeMutablePointer<Float> in
                // Guard samples detect a destination write beyond declared byte size.
                let p = UnsafeMutablePointer<Float>.allocate(capacity:count+2)
                p.initialize(repeating:9876,count:count+2)
                for j in values.indices { p[j] = values[j] }
                return p
            }
            allocations.append(memory)
            list[i] = AudioBuffer(mNumberChannels:channels[i],mDataByteSize:UInt32(count*MemoryLayout<Float>.size),mData:memory.map { UnsafeMutableRawPointer($0) })
        }
        storage = allocations; lengths = counts
    }
    var pointer: UnsafeMutablePointer<AudioBufferList> { list.unsafeMutablePointer }
    func values(_ index:Int) -> [Float] {
        guard let p = storage[index] else { return [] }
        return Array(UnsafeBufferPointer(start:p,count:lengths[index]))
    }
    var canariesIntact:Bool { storage.indices.allSatisfy { i in guard let p = storage[i] else { return true }; return p[lengths[i]] == 9876 && p[lengths[i]+1] == 9876 } }
    deinit { for p in storage { p?.deallocate() }; free(list.unsafeMutablePointer) }
}
var checks = 0
func check(_ passed:Bool,_ label:String) {
    guard passed else { fatalError("FAIL \(label)") }
    checks += 1; print("PASS \(label)")
}
let scratch = UnsafeMutablePointer<Float>.allocate(capacity:18)
scratch.initialize(repeating:777,count:18)
defer { scratch.deallocate() }

let stereo = Fixture([2],[[1,2,3,4,5,6]])
check(normalizeToInterleavedStereo(stereo.pointer,into:scratch,maxFrames:8) == 3,"interleaved input frame count")
check(Array(UnsafeBufferPointer(start:scratch,count:6)) == [1,2,3,4,5,6],"interleaved stereo channel order")
check(scratch[6] == 777,"normalization leaves unused scratch untouched")
let split = Fixture([1,1],[[1,3,5],[2,4]])
check(normalizeToInterleavedStereo(split.pointer,into:scratch,maxFrames:8) == 2,"split input uses shortest channel")
check(Array(UnsafeBufferPointer(start:scratch,count:4)) == [1,2,3,4],"split input preserves left/right")
let mono = Fixture([1],[[9,8]])
check(normalizeToInterleavedStereo(mono.pointer,into:scratch,maxFrames:1) == 1 && scratch[0] == 9 && scratch[1] == 9,"mono duplication respects frame cap")
let duplex = Fixture([1,1,1,1],[[99,99],[98,98],[1,3],[2,4]])
let start = tapBufferStartIndex(bufferCount:4,tapStreamCount:2)
check(start == 2,"tap input skips leading physical microphone streams")
check(normalizeToInterleavedStereo(duplex.pointer,into:scratch,maxFrames:8,startingAtBuffer:start) == 2 && scratch[0] == 1 && scratch[1] == 2,"tap normalization excludes microphone samples")
let nilInput = Fixture([2],[nil])
check(normalizeToInterleavedStereo(nilInput.pointer,into:scratch,maxFrames:8) == 0,"nil input produces no frames")
check(normalizeToInterleavedStereo(stereo.pointer,into:scratch,maxFrames:0) == 0,"zero frame request reads no samples")
check(normalizeToInterleavedStereo(stereo.pointer,into:scratch,maxFrames:8,startingAtBuffer:1) == 0,"missing selected tap input produces no frames")
check(normalizeToInterleavedStereo(stereo.pointer,into:scratch,maxFrames:8,startingAtBuffer:-1) == 0,"negative input index is rejected")

_ = normalizeToInterleavedStereo(stereo.pointer,into:scratch,maxFrames:3)
let out = Fixture([2],[[0,0,0,0,0,0]])
check(writableFrameCapacity(out.list) == 3,"interleaved output capacity counts channels")
writeInterleavedStereo(scratch,frameCount:3,to:out.list)
check(out.values(0) == [1,2,3,4,5,6] && out.canariesIntact,"interleaved output writes within declared capacity")
let outSplit = Fixture([1,1],[[0,0,0],[0,0]])
check(writableFrameCapacity(outSplit.list) == 2,"split output uses shortest writable channel")
writeInterleavedStereo(scratch,frameCount:writableFrameCapacity(outSplit.list),to:outSplit.list)
check(outSplit.values(0) == [1,3,0] && outSplit.values(1) == [2,4] && outSplit.canariesIntact,"split output preserves channels and bounds")
let wide = Fixture([4],[[0,0,0,0,0,0,0,0]])
writeInterleavedStereo(scratch,frameCount:writableFrameCapacity(wide.list),to:wide.list)
check(wide.values(0) == [1,2,0,0,3,4,0,0] && wide.canariesIntact,"wide output uses channel stride without touching extra channels")
zeroFillAudioBuffers(outSplit.pointer)
check(outSplit.values(0) == [0,0,0] && outSplit.values(1) == [0,0] && outSplit.canariesIntact,"silence clears declared bytes without overwriting guards")
let nilOutput = Fixture([2],[nil])
zeroFillAudioBuffers(nilOutput.pointer)
check(writableFrameCapacity(nilOutput.list) == 0,"nil output has no writable frames")
let empty = Fixture([],[])
check(writableFrameCapacity(empty.list) == 0 && normalizeToInterleavedStereo(empty.pointer,into:scratch,maxFrames:8) == 0,"empty lists are safe")
check(stereo.canariesIntact && split.canariesIntact && duplex.canariesIntact,"input allocations remain intact")
print("Total: \(checks) audio-buffer checks passed; no audio devices accessed")
