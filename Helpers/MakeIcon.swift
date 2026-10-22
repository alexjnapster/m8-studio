import AppKit
let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath:directory,withIntermediateDirectories:true)
for size in [16,32,128,256,512] { for scale in [1,2] {
    let n = size*scale; let image = NSImage(size:NSSize(width:n,height:n)); image.lockFocus()
    let context = NSGraphicsContext.current!.cgContext; context.scaleBy(x:CGFloat(n)/1024,y:CGFloat(n)/1024)
    let outline = NSBezierPath(roundedRect:NSRect(x:32,y:32,width:960,height:960),xRadius:220,yRadius:220)
    NSColor(red:0.94,green:0.95,blue:0.91,alpha:1).setFill(); outline.fill()
    NSGraphicsContext.saveGraphicsState()
    let screen = NSBezierPath(roundedRect:NSRect(x:153,y:330,width:718,height:440),xRadius:48,yRadius:48)
    NSColor(red:0.83,green:0.84,blue:0.77,alpha:1).setFill(); screen.fill()
    let inner = NSBezierPath(roundedRect:NSRect(x:171,y:348,width:682,height:404),xRadius:31,yRadius:31)
    NSGradient(starting:NSColor(red:0.58,green:0.80,blue:0.68,alpha:1),ending:NSColor(red:0.05,green:0.30,blue:0.25,alpha:1))!.draw(in:inner,angle:-45)
    inner.addClip()
    NSColor.white.withAlphaComponent(0.19).setFill(); NSBezierPath(ovalIn:NSRect(x:560,y:590,width:400,height:400)).fill()
    let wave = NSBezierPath(roundedRect:NSRect(x:-40,y:230,width:670,height:240),xRadius:120,yRadius:120); let transform = AffineTransform(rotationByDegrees:28); wave.transform(using:transform); NSColor.white.withAlphaComponent(0.16).setFill(); wave.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor(red:0.67,green:0.69,blue:0.62,alpha:1).setFill(); NSBezierPath(roundedRect:NSRect(x:491,y:227,width:42,height:105),xRadius:8,yRadius:8).fill()
    NSBezierPath(roundedRect:NSRect(x:363,y:209,width:298,height:24),xRadius:12,yRadius:12).fill()
    image.unlockFocus(); let bitmap = NSBitmapImageRep(data:image.tiffRepresentation!)!
    let suffix = scale == 2 ? "@2x":""; try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:directory+"/icon_\(size)x\(size)\(suffix).png"))
} }
