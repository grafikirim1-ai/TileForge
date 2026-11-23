import AppKit
import Foundation
let directory=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let n=size*scale
        let image=NSImage(size:NSSize(width:n,height:n));image.lockFocus()
        let ctx=NSGraphicsContext.current!.cgContext;ctx.scaleBy(x:CGFloat(n)/1024,y:CGFloat(n)/1024)
        let rect=CGRect(x:35,y:35,width:954,height:954)
        ctx.setFillColor(NSColor(calibratedRed:0.1,green:0.11,blue:0.13,alpha:1).cgColor)
        ctx.addPath(CGPath(roundedRect:rect,cornerWidth:215,cornerHeight:215,transform:nil));ctx.fillPath()
        let colors:[NSColor]=[NSColor(calibratedRed:1,green:0.43,blue:0.24,alpha:1),NSColor(calibratedRed:1,green:0.61,blue:0.32,alpha:1),NSColor(calibratedRed:0.9,green:0.3,blue:0.17,alpha:1),NSColor(calibratedRed:1,green:0.48,blue:0.26,alpha:1)]
        for row in 0..<2 {for col in 0..<2 {
            let x=CGFloat(205+col*323),y=CGFloat(205+row*323)
            ctx.setFillColor(colors[row*2+col].cgColor)
            ctx.addPath(CGPath(roundedRect:CGRect(x:x,y:y,width:290,height:290),cornerWidth:55,cornerHeight:55,transform:nil));ctx.fillPath()
        }}
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.82).cgColor);ctx.setLineWidth(13);ctx.setLineCap(.round)
        ctx.move(to:CGPoint(x:660,y:682));ctx.addLine(to:CGPoint(x:760,y:682));ctx.move(to:CGPoint(x:710,y:632));ctx.addLine(to:CGPoint(x:710,y:732));ctx.strokePath()
        image.unlockFocus()
        let bitmap=NSBitmapImageRep(data:image.tiffRepresentation!)!
        let name="icon_\(size)x\(size)"+(scale==2 ? "@2x" : "")+".png"
        try bitmap.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent(name))
    }
}
