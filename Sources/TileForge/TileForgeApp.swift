import SwiftUI
import AppKit
import TileCore

@main struct TileForgeApp: App {
    @StateObject private var model=ForgeModel()
    var body: some Scene {
        WindowGroup {
            ForgeView(model:model).preferredColorScheme(.dark).frame(minWidth:1040,minHeight:720)
        }.windowStyle(.hiddenTitleBar).defaultSize(width:1280,height:850)
        .commands {
            CommandGroup(replacing:.newItem) { Button("Open image…") { model.chooseImage() }.keyboardShortcut("o").disabled(model.busy) }
            CommandGroup(after:.saveItem) { Button("Export…") { model.export() }.keyboardShortcut("e",modifiers:[.command,.shift]).disabled(model.resultURL == nil) }
        }
    }
}
private let accent=Color(red:1,green:0.49,blue:0.27)
private let panel=Color(red:0.105,green:0.11,blue:0.12)
struct ForgeView: View {
    @ObservedObject var model:ForgeModel
    @State private var zoom=0.0
    @State private var dragging=false
    var body: some View {
        HStack(spacing:0) {
            ScrollView { sidebar }.frame(width:292).background(panel)
            Divider()
            VStack(spacing:0) {
                toolbar
                Divider()
                canvas
                Divider()
                footer
            }.background(Color(red:0.065,green:0.07,blue:0.08))
        }.tint(accent)
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) { _ in model.shutdown() }
        .alert("Operation could not be completed",isPresented:Binding(get:{model.errorMessage != nil},set:{if !$0 {model.errorMessage=nil}})) { Button("OK") {model.errorMessage=nil} } message: {Text(model.errorMessage ?? "")}
        .onDrop(of:["public.file-url"],isTargeted:$dragging) { providers in
            guard !model.busy,let p=providers.first else {return false}
            _=p.loadObject(ofClass:URL.self) { url,_ in if let url {Task { @MainActor in model.loadSource(url) }} };return true
        }
    }
    private var sidebar: some View {
        VStack(alignment:.leading,spacing:22) {
            HStack(spacing:11) {
                Image(systemName:"square.grid.3x3.fill").font(.system(size:27)).foregroundStyle(accent)
                VStack(alignment:.leading,spacing:1) {Text("TileForge").font(.system(size:23,weight:.semibold,design:.rounded));Text("GPT DETAIL STUDIO").font(.system(size:9,weight:.medium)).tracking(2).foregroundStyle(.secondary)}
            }.padding(.top,22)
            accountCard
            Divider()
            VStack(alignment:.leading,spacing:12) {
                label("01", "SOURCE IMAGE")
                Button(action:model.chooseImage) {Label(model.sourceURL == nil ? "Choose image…" : "Change image…",systemImage:"photo.badge.plus").frame(maxWidth:.infinity).padding(.vertical,7)}.disabled(model.busy)
                if let source=model.sourceURL { Text(source.lastPathComponent).font(.system(size:11)).lineLimit(1).truncationMode(.middle);Text("\(model.sourceWidth) × \(model.sourceHeight) px").font(.system(size:11,design:.monospaced)).foregroundStyle(.secondary) }
            }
            VStack(alignment:.leading,spacing:12) {
                label("02","TILING")
                HStack(spacing:5) {
                    ForEach([[2,2],[2,3],[3,3],[4,4]],id:\.self) { p in
                        Button("\(p[0])×\(p[1])") {model.columns=p[0];model.rows=p[1]}.buttonStyle(.plain).font(.system(size:12,weight:.medium,design:.monospaced)).padding(.vertical,8).frame(maxWidth:.infinity).background(model.columns==p[0] && model.rows==p[1] ? accent.opacity(0.2) : Color.white.opacity(0.045),in:RoundedRectangle(cornerRadius:6)).overlay(RoundedRectangle(cornerRadius:6).stroke(model.columns==p[0] && model.rows==p[1] ? accent.opacity(0.6) : Color.clear))
                    }
                }
                HStack {Stepper("Columns: \(model.columns)",value:$model.columns,in:1...8);Stepper("Rows: \(model.rows)",value:$model.rows,in:1...8)}.font(.system(size:11))
                Text("\(model.columns*model.rows) tiles · 25% context margins").font(.system(size:11)).foregroundStyle(.secondary)
            }.disabled(model.busy)
            VStack(alignment:.leading,spacing:12) {
                label("03","DETAIL AND OUTPUT")
                Picker("Scale",selection:$model.scale) {Text("1×").tag(1);Text("2×").tag(2);Text("4×").tag(4)}.pickerStyle(.segmented)
                HStack {Text("Detail transfer");Spacer();Text("\(Int(model.strength*100))%").monospacedDigit().foregroundStyle(.secondary)}.font(.system(size:11))
                Slider(value:$model.strength,in:0.2...1)
                TextEditor(text:$model.instruction).font(.system(size:12)).scrollContentBackground(.hidden).padding(7).frame(height:75).background(Color.black.opacity(0.22),in:RoundedRectangle(cornerRadius:7))
                HStack {Text("Output").foregroundStyle(.secondary);Spacer();Text(model.outputLabel).monospacedDigit()}.font(.system(size:11))
                if model.targetPixels>48_000_000 { Text("Exceeds 48 MP. Reduce the scale.").font(.system(size:11)).foregroundStyle(accent) }
            }.disabled(model.busy)
            Spacer(minLength:0)
            VStack(spacing:9) {
                if model.busy {
                    Button(action:model.cancel) {Label("Stop processing",systemImage:"stop.fill").frame(maxWidth:.infinity).padding(.vertical,9)}
                } else {
                    Button(action:model.start) {Label(model.canResumeCurrent ? "Resume where you left off" : "Enhance and compose",systemImage:model.canResumeCurrent ? "play.fill" : "sparkles").fontWeight(.semibold).frame(maxWidth:.infinity).padding(.vertical,9)}.buttonStyle(.borderedProminent).disabled(!model.canRun)
                }
                Button("Resume saved job…",action:model.resume).buttonStyle(.plain).font(.system(size:11)).foregroundStyle(.secondary).disabled(model.busy || !model.signedIn)
                Text("Tiles are sent to OpenAI. Generations consume your ChatGPT / Codex usage allowance.").font(.system(size:10)).foregroundStyle(.tertiary).multilineTextAlignment(.center).fixedSize(horizontal:false,vertical:true)
            }
        }.padding(.horizontal,22).padding(.bottom,18)
    }
    private var accountCard: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {Circle().fill(model.signedIn ? Color.green : Color.gray).frame(width:6,height:6);Text(model.signedIn ? "ChatGPT connected" : "ChatGPT account").font(.system(size:12,weight:.medium));Spacer();if model.accountBusy {ProgressView().controlSize(.mini)}}
            if model.signedIn {
                Text(model.email).font(.system(size:11)).foregroundStyle(.secondary).lineLimit(1)
                HStack {Text(model.planName.uppercased()).font(.system(size:9,weight:.semibold)).tracking(1).foregroundStyle(accent);Spacer();Button("Switch Google account",action:model.login).font(.system(size:10)).buttonStyle(.plain).disabled(model.busy || model.accountBusy)}
            } else {
                Button("Sign in with Google",action:model.login).buttonStyle(.borderedProminent).controlSize(.small).disabled(model.accountBusy)
                Text("Choose “Continue with Google” on the official OpenAI page. The app never asks for your password.").font(.system(size:10)).foregroundStyle(.secondary)
            }
            Button("Refresh connection") { Task {await model.refreshAccount()} }.buttonStyle(.plain).font(.system(size:10)).foregroundStyle(.secondary).disabled(model.accountBusy || model.busy)
        }.padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color.white.opacity(0.035),in:RoundedRectangle(cornerRadius:9))
    }
    private func label(_ n:String,_ title:String)->some View {HStack(spacing:8) {Text(n).foregroundStyle(accent);Text(title).foregroundStyle(.secondary)}.font(.system(size:10,weight:.semibold)).tracking(1.4)}
    private var toolbar:some View {
        HStack(spacing:15) {
            Text(model.after == nil ? "Workspace" : "Result").font(.system(size:13,weight:.medium))
            Spacer()
            if model.after != nil { Picker("View",selection:$model.showOriginal) {Text("Before").tag(true);Text("After").tag(false)}.pickerStyle(.segmented).frame(width:150) }
            HStack(spacing:8) {Button {zoom=zoom == 0 ? 0.5 : max(0.25,zoom-0.25)} label:{Image(systemName:"minus.magnifyingglass")};Text(zoom == 0 ? "Fit" : "\(Int(zoom*100))%").font(.system(size:10,design:.monospaced)).frame(width:38);Button {zoom=zoom == 0 ? 1 : min(4,zoom+0.25)} label:{Image(systemName:"plus.magnifyingglass")}}.buttonStyle(.plain)
            Button {zoom=0} label: {Image(systemName:"arrow.down.right.and.arrow.up.left")}.buttonStyle(.plain).help("Fit to window")
            Button(action:model.export) {Label("Export",systemImage:"square.and.arrow.up")}.disabled(model.resultURL == nil || model.busy)
        }.padding(.horizontal,22).frame(height:65)
    }
    private func previewSize(_ available:CGSize)->CGSize {
        if zoom == 0 {return CGSize(width:max(1,available.width-70),height:max(1,available.height-70))}
        let result=model.after != nil && !model.showOriginal
        let screenScale=NSScreen.main?.backingScaleFactor ?? 2
        return CGSize(width:CGFloat(result ? model.resultWidth : model.sourceWidth)*zoom/screenScale,height:CGFloat(result ? model.resultHeight : model.sourceHeight)*zoom/screenScale)
    }
    private var canvas:some View {
        GeometryReader { geo in
            ZStack {
                if let image=(model.showOriginal ? model.before : model.after ?? model.before) {
                    ScrollView([.horizontal,.vertical]) {
                        ZStack {
                            Image(nsImage:image).resizable().interpolation(.high).scaledToFit().frame(width:previewSize(geo.size).width,height:previewSize(geo.size).height)
                            if model.after == nil {
                                Canvas {ctx,size in
                                    let imageRatio=image.size.width/max(1,image.size.height),viewRatio=size.width/max(1,size.height)
                                    let w=viewRatio>imageRatio ? size.height*imageRatio : size.width,h=viewRatio>imageRatio ? size.height : size.width/imageRatio
                                    let ox=(size.width-w)/2,oy=(size.height-h)/2
                                    var path=Path()
                                    if model.columns>1 {for col in 1..<model.columns {let x=ox+w*CGFloat(col)/CGFloat(model.columns);path.move(to:CGPoint(x:x,y:oy));path.addLine(to:CGPoint(x:x,y:oy+h))}}
                                    if model.rows>1 {for row in 1..<model.rows {let y=oy+h*CGFloat(row)/CGFloat(model.rows);path.move(to:CGPoint(x:ox,y:y));path.addLine(to:CGPoint(x:ox+w,y:y))}}
                                    ctx.stroke(path,with:.color(.white.opacity(0.75)),style:StrokeStyle(lineWidth:1,dash:[5,5]))
                                }.allowsHitTesting(false)
                            }
                        }.padding(35)
                    }
                } else {
                    VStack(spacing:18) {
                        Image(systemName:"square.stack.3d.up").font(.system(size:58,weight:.ultraLight)).foregroundStyle(accent.opacity(0.8))
                        VStack(spacing:8) {Text("One image. More detail.").font(.system(size:25,weight:.medium,design:.rounded));Text("Drop your image here or choose a file.").font(.system(size:13)).foregroundStyle(.secondary)}
                        Button("Choose image…",action:model.chooseImage).controlSize(.large)
                        Text("PNG · JPEG · TIFF · HEIC · WEBP").font(.system(size:10,design:.monospaced)).tracking(1).foregroundStyle(.tertiary)
                    }.frame(maxWidth:.infinity,maxHeight:.infinity)
                }
                if dragging { RoundedRectangle(cornerRadius:12).stroke(accent,lineWidth:3).padding(12) }
                if model.busy,let tile=model.currentTile {
                    VStack {Spacer();HStack {Spacer();Image(nsImage:tile).resizable().scaledToFit().frame(width:120,height:100).padding(8).background(panel,in:RoundedRectangle(cornerRadius:10)).overlay(alignment:.topLeading){Text("LATEST TILE").font(.system(size:8,weight:.bold)).padding(5).background(.black.opacity(0.6))}}}.padding(18)
                }
            }
        }
    }
    private var footer:some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {if model.busy {ProgressView().controlSize(.small)} else {Image(systemName:model.after == nil ? "info.circle" : "checkmark.circle").foregroundStyle(model.after == nil ? Color.secondary : Color.green)};Text(model.status).font(.system(size:11)).lineLimit(2);Spacer();Button(action:model.revealJob){Image(systemName:"folder")}.buttonStyle(.plain).help("Show job files")}
            if model.busy {ProgressView(value:model.progress).tint(accent)
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.willTerminateNotification)) { _ in model.shutdown() }}
            Text("Source lighting is retained. Generation may change object details; review at 100% before delivery.").font(.system(size:10)).foregroundStyle(.tertiary)
        }.padding(.horizontal,22).padding(.vertical,14).frame(minHeight:78)
    }
}
