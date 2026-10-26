import AppKit
let target = CommandLine.arguments[1]
let image = NSImage(size:NSSize(width:720,height:520))
image.lockFocus()
NSColor(calibratedRed:0.94,green:0.97,blue:0.95,alpha:1).setFill()
NSBezierPath(rect:NSRect(x:0,y:0,width:720,height:520)).fill()
let brand=NSColor(calibratedRed:0.08,green:0.34,blue:0.26,alpha:1)
func text(_ value:String,_ y:CGFloat,_ size:CGFloat,_ weight:NSFont.Weight,_ color:NSColor) {
 let style=NSMutableParagraphStyle();style.alignment = .center
 (value as NSString).draw(in:NSRect(x:30,y:y,width:660,height:50),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color,.paragraphStyle:style])
}
text("M8 Studio",432,34,.semibold,brand)
text("Перетягніть застосунок до Applications",397,18,.medium,brand)
text("Drag the app into Applications",372,14,.regular,.secondaryLabelColor)
brand.withAlphaComponent(0.45).setStroke()
let arrow=NSBezierPath();arrow.lineWidth=3;arrow.lineCapStyle = .round
arrow.move(to:NSPoint(x:322,y:290));arrow.line(to:NSPoint(x:397,y:290))
arrow.move(to:NSPoint(x:385,y:302));arrow.line(to:NSPoint(x:397,y:290));arrow.line(to:NSPoint(x:385,y:278));arrow.stroke()
text("Apple silicon  ·  macOS 14.2+  ·  Development preview",14,12,.regular,.secondaryLabelColor)
image.unlockFocus()
let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:target))
