// This file is appended to the real ForgeView source by make-guide-screens.py.
@main struct GuideRenderer {
    @MainActor static func main() throws {
        _=NSApplication.shared
        NSApplication.shared.appearance=NSAppearance(named:.darkAqua)
        let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let folder=root.appendingPathComponent("docs/guide/screens",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let source=root.appendingPathComponent("docs/guide/examples/reference.png"),result=root.appendingPathComponent("docs/guide/examples/result.png")
        let model=ForgeModel()
        model.accountBusy=false;model.errorMessage=nil;model.signedIn=false
        func render(_ name:String) throws {
            let view=ForgeView(model:model).environment(\.colorScheme,.dark).frame(width:1280,height:900)
            let host=NSHostingView(rootView:view)
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:1280,height:900),styleMask:[.borderless],backing:.buffered,defer:false)
            window.contentView=host
            host.frame=NSRect(x:0,y:0,width:1280,height:900)
            window.displayIfNeeded();host.layoutSubtreeIfNeeded()
            RunLoop.current.run(until:Date().addingTimeInterval(0.15))
            guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2560,pixelsHigh:1800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0) else {throw ForgeError.message("Guide screen could not be rendered")}
            bitmap.size=host.bounds.size
            host.cacheDisplay(in:host.bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(name+".png"))
            window.orderOut(nil)
        }
        try render("01-login")
        model.signedIn=true;model.email="example@example.com";model.planName="ChatGPT"
        try render("02-empty")
        model.sourceURL=source;model.sourceWidth=512;model.sourceHeight=341;model.before=NSImage(contentsOf:source);model.status="Ready to generate."
        try render("03-source")
        model.columns=3;model.rows=3
        try render("04-grid")
        model.columns=2;model.rows=2;model.busy=true;model.completed=2;model.total=4;model.progress=0.45
        model.status="GPT is enhancing tile: 3 / 4…";model.currentTile=NSImage(contentsOf:root.appendingPathComponent("docs/guide/examples/tile-preview.png"))
        try render("05-progress")
        model.busy=false;model.progress=1;model.after=NSImage(contentsOf:result);model.resultURL=result;model.resultWidth=1024;model.resultHeight=682;model.status="Image ready · You can export now."
        try render("06-result")
        print(folder.path)
    }
}
