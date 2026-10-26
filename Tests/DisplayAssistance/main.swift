import Foundation
var passed = 0
func check(_ value:Bool,_ name:String) { precondition(value,name); passed += 1; print("PASS " + name) }
func mode(_ w:Int,_ h:Int,_ hz:Int = 60000) -> FavoriteDisplayMode {
    FavoriteDisplayMode(width:w,height:h,pixelWidth:w*2,pixelHeight:h*2,milliHz:hz)
}
let reference = TextSizeMatch.Screen(widthMM:300,heightMM:200,mode:mode(1500,1000))
let target = TextSizeMatch.Screen(widthMM:600,heightMM:400,mode:mode(1920,1280))
check(TextSizeMatch.best(reference:reference,target:target,candidates:[mode(1920,1280),mode(3000,2000)]) == mode(3000,2000),"physical text scale, not logical width, chooses closest mode")
check(TextSizeMatch.best(reference:reference,target:target,candidates:[mode(3000,2000,59940),mode(3000,2000)]) == mode(3000,2000),"equally close modes preserve refresh")
check(TextSizeMatch.best(reference:reference,target:target,candidates:[mode(3840,2160)]) == nil,"wrong aspect is not suggested")
let low = FavoriteDisplayMode(width:3000,height:2000,pixelWidth:3000,pixelHeight:2000,milliHz:60000)
check(TextSizeMatch.best(reference:reference,target:target,candidates:[low]) == nil,"low resolution mode is not a clarity recommendation")
let invalid = TextSizeMatch.Screen(widthMM:.nan,heightMM:200,mode:mode(1500,1000))
check(TextSizeMatch.best(reference:invalid,target:target,candidates:[mode(3000,2000)]) == nil,"invalid physical dimensions fail closed")
let stretched = TextSizeMatch.Screen(widthMM:300,heightMM:200,mode:mode(1920,1080))
check(TextSizeMatch.best(reference:stretched,target:target,candidates:[mode(3000,2000)]) == nil,"stretched reference is rejected")
let zero = TextSizeMatch.Screen(widthMM:0,heightMM:0,mode:mode(1500,1000))
check(TextSizeMatch.best(reference:reference,target:zero,candidates:[mode(3000,2000)]) == nil,"missing target dimensions fail closed")
check(TextSizeMatch.best(reference:reference,target:target,candidates:[]) == nil,"missing modes yield no suggestion")

MainActor.assumeIsolated {
    let suite = "local.M8Studio.RecoveryTest." + UUID().uuidString
    let defaults = UserDefaults(suiteName:suite)!
    defer { defaults.removePersistentDomain(forName:suite) }
    let a = UUID().uuidString, b = UUID().uuidString
    let record = SavedCanvas(mode:mode(1920,1080),profilePath:"/fixture/profile.icc",profileName:"Test")
    let recovery = CanvasRecovery(preferences:defaults)
    check(recovery.save(record,for:a),"explicit opt-in persists canvas")
    check(CanvasRecovery(preferences:defaults).saved(a) == record,"canvas survives restart")
    recovery.updateConnections([a])
    check(recovery.pending.isEmpty,"initial launch never offers a false reconnect")
    recovery.updateConnections([a]); recovery.updateConnections([a,b])
    check(recovery.pending.isEmpty,"refresh and new unsaved display do not trigger recovery")
    recovery.updateConnections([b]); recovery.updateConnections([a,b])
    check(recovery.pending == [a],"real saved display return offers recovery")
    recovery.dismiss(a); recovery.updateConnections([a,b])
    check(recovery.pending.isEmpty,"dismiss is not undone by repeated refresh")
    recovery.updateConnections([b]); recovery.updateConnections([a,b])
    check(recovery.pending == [a],"next actual reconnect can offer recovery again")
    recovery.updateConnections([b])
    check(recovery.pending.isEmpty,"disconnected screen has no stale review")
    recovery.forget(a); recovery.updateConnections([a,b])
    check(recovery.pending.isEmpty && recovery.saved(a) == nil,"forget cancels reconnect and stored settings")
    check(!recovery.save(record,for:"123"),"transient display IDs are not persisted")
    check(!recovery.save(SavedCanvas(mode:mode(1920,1080),profilePath:"relative.icc",profileName:nil),for:a),"relative profile paths rejected")
    defaults.set(Data("not-json".utf8),forKey:"savedCanvas."+a)
    check(recovery.saved(a) == nil,"corrupt saved canvas ignored")
    defaults.set(Data(repeating:0,count:20000),forKey:"savedCanvas."+a)
    check(recovery.saved(a) == nil,"oversized canvas ignored")
    check(!recovery.save(SavedCanvas(mode:mode(0,0),profilePath:nil,profileName:nil),for:a),"invalid mode is not saved")
    check(recovery.save(record,for:a),"save recovers from corrupt preferences")
    recovery.updateConnections([b]); recovery.updateConnections([a,b])
    check(recovery.pending == [a],"repaired settings allow next genuine reconnect")
    check(recovery.save(record,for:a) && recovery.pending.isEmpty,"saving new baseline clears review")
}
print("\(passed) display-assistance checks passed; no display/profile changes")
