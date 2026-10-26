import Foundation
var passed=0
func check(_ v:Bool,_ name:String) { precondition(v,name); passed+=1; print("PASS "+name) }
check(VirtualCanvasPlan(width:2560).valid && VirtualCanvasPlan(width:2560).height == 1440,"2560 x 1440 2x canvas geometry")
check(VirtualCanvasPlan(width:3072).valid && VirtualCanvasPlan(width:3072).height == 1728,"maximum stays within 6144 x 3456 render buffer")
for width in [0,-16,1279,1921,3073,Int.max] { check(!VirtualCanvasPlan(width:width).valid,"invalid custom width rejected") }
func eligible(_ builtIn:Bool = false,_ m8:Bool = true,_ mirror:Bool = false,_ rotation:Double = 0,_ hz:Double = 60,_ aspect:Double = 16.0/9.0,_ previewing:Bool = false)->Bool {
    VirtualCanvasPlan.eligible(builtIn:builtIn,isM80B:m8,mirrored:mirror,rotation:rotation,rate:hz,aspect:aspect,previewing:previewing)
}
check(eligible(),"landscape external M80B near 60 Hz eligible for experiment")
check(eligible(false,true,false,0,59.94),"fractional physical refresh accepted")
check(!eligible(true),"built-in display protected")
check(!eligible(false,false),"other models require their own acceptance")
check(!eligible(false,true,true),"existing mirror configuration protected")
check(!eligible(false,true,false,90),"portrait layout protected")
check(!eligible(false,true,false,0,120),"higher physical refresh not injected")
check(!eligible(false,true,false,0,60,4.0/3.0),"stretched or non-16:9 physical mode rejected")
check(!eligible(false,true,false,0,60,16.0/9.0,true),"native preview cannot overlap custom canvas")
check(!eligible(false,true,false,.nan),"invalid rotation rejected")
check(!eligible(false,true,false,0,.nan),"invalid refresh rejected")
print("\(passed) virtual-canvas policy checks passed; no display created")
