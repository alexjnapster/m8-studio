import Foundation

struct VirtualCanvasPlan:Equatable {
    let width:Int
    var height:Int { width*9/16 }
    var valid:Bool { (1280...3072).contains(width) && width%16 == 0 }
    static func eligible(builtIn:Bool,isM80B:Bool,mirrored:Bool,rotation:Double,rate:Double,aspect:Double,previewing:Bool)->Bool {
        !builtIn && isM80B && !mirrored && rotation.isFinite && abs(rotation)<0.1 && rate.isFinite &&
        (59...60.5).contains(rate) && aspect.isFinite && abs(aspect-16.0/9.0)<0.02 && !previewing
    }
}
