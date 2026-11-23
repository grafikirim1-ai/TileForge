import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TileCore
import ImageIO

struct JobRecord: Codable {
    let id:String, created:Date, columns:Int, rows:Int, scale:Int, instruction:String, strength:Float
    var width:Int, height:Int, completed:[Int], status:String, overlapError:Float?
}
@MainActor final class ForgeModel: ObservableObject {
    @Published var email=""
    @Published var planName=""
    @Published var accountBusy=false
    @Published var signedIn=false
    @Published var columns=2
    @Published var rows=2
    @Published var scale=2
    @Published var strength=0.8
    @Published var instruction="Preserve the source structure; enhance natural texture and fine detail."
    @Published var sourceURL:URL?
    @Published var before:NSImage?
    @Published var after:NSImage?
    @Published var sourceWidth=0
    @Published var sourceHeight=0
    @Published var busy=false
    @Published var status="Choose an image to get started."
    @Published var progress=0.0
    @Published var completed=0
    @Published var total=0
    @Published var errorMessage:String?
    @Published var jobURL:URL?
    @Published var resultURL:URL?
    @Published var resultWidth=0
    @Published var resultHeight=0
    @Published var showOriginal=false
    @Published var overlapError:Float?
    @Published var currentTile:NSImage?
    private var accountConnection:AccountConnection?
    private var task:Task<Void,Never>?, worker:GenerationWorker?
    let root:URL
    let runtime:URL?
    init() {
        root=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("TileForge/Jobs",isDirectory:true)
        let bundled=Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/codex-runtime/bin/codex")
        let candidates=[bundled.path,ProcessInfo.processInfo.environment["TILEFORGE_CODEX"] ?? "","/opt/homebrew/bin/codex","/usr/local/bin/codex"]
        runtime=candidates.first(where:{ FileManager.default.isExecutableFile(atPath:$0) }).map { URL(fileURLWithPath:$0) }
        if let runtime { accountConnection=AccountConnection(runtime:runtime);accountConnection?.onAccountChange={ [weak self] in Task { await self?.refreshAccount() } } }
        Task { await refreshAccount();if sourceURL == nil { restoreInterruptedJob() } }
    }
    func refreshAccount() async {
        guard let accountConnection else { errorMessage="Codex runtime not found. Open the app from its complete bundle.";return }
        accountBusy=true;defer { accountBusy=false }
        do { if let (email,plan)=try await accountConnection.account() { self.email=email;planName=plan; signedIn=true } else { signedIn=false;email="" } }
        catch { errorMessage=error.localizedDescription }
    }
    func login() {
        guard !accountBusy else { return }
        task=Task { accountBusy=true;defer { accountBusy=false };do { try await accountConnection?.login();status="Sign in using ‘Continue with Google’ on the OpenAI page." } catch { errorMessage=error.localizedDescription } }
    }
    func chooseImage() {
        let panel=NSOpenPanel();panel.allowedContentTypes=[.image];panel.allowsMultipleSelection=false
        guard panel.runModal() == .OK,let url=panel.url else { return }
        loadSource(url)
    }
    @discardableResult func loadSource(_ url:URL) -> Bool {
        guard !busy else { return false }
        do {
            let raster=try Raster.load(url,maxEdge:1400)
            let src=CGImageSourceCreateWithURL(url as CFURL,nil)!
            let p=CGImageSourceCopyPropertiesAtIndex(src,0,nil) as? [CFString:Any]
            var w=p?[kCGImagePropertyPixelWidth] as? Int ?? raster.width,h=p?[kCGImagePropertyPixelHeight] as? Int ?? raster.height
            let orientation=p?[kCGImagePropertyOrientation] as? Int ?? 1
            if (5...8).contains(orientation) { swap(&w,&h) }
            guard w*h<=48_000_000 else { throw ForgeError.message("Source exceeds the 48 MP limit.") }
            let preview=try raster.cgImage()
            sourceURL=url;sourceWidth=w;sourceHeight=h;before=NSImage(contentsOf:url) ?? NSImage(cgImage:preview,size:.zero)
            after=nil;resultURL=nil;resultWidth=0;resultHeight=0;jobURL=nil;completed=0;progress=0;overlapError=nil;currentTile=nil;status="Ready to generate."
            return true
        } catch { errorMessage=error.localizedDescription;return false }
    }
    var targetPixels:Int { sourceWidth*sourceHeight*scale*scale }
    var canRun:Bool { signedIn && sourceURL != nil && !busy && targetPixels<=48_000_000 }
    var outputLabel:String { sourceURL == nil ? "—" : "\(sourceWidth*scale) × \(sourceHeight*scale) px" }
    var canResumeCurrent:Bool { jobURL != nil && resultURL == nil }
    func start() {
        if canResumeCurrent,let jobURL { resume(from:jobURL.appendingPathComponent("job.json"));return }
        guard canRun,let sourceURL else { return }
        guard instruction.count<=4000 else {errorMessage="Detail instructions must be 4,000 characters or fewer.";return}
        let folder=root.appendingPathComponent(UUID().uuidString,isDirectory:true)
        let settings=JobRecord(id:folder.lastPathComponent,created:Date(),columns:columns,rows:rows,scale:scale,instruction:instruction,strength:Float(strength),width:sourceWidth*scale,height:sourceHeight*scale,completed:[],status:"preparing",overlapError:nil)
        execute(folder:folder,record:settings,input:sourceURL)
    }
    func resume() {
        let p=NSOpenPanel();p.allowedContentTypes=[.json];p.directoryURL=root;p.message="Select job.json in the job folder to resume."
        guard p.runModal() == .OK,let url=p.url else { return }
        resume(from:url)
    }
    private func restoreInterruptedJob() {
        let files=(try? FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil)) ?? []
        let jobs=files.compactMap { folder -> (URL,JobRecord)? in
            let url=folder.appendingPathComponent("job.json")
            guard let data=try? Data(contentsOf:url),let job=try? JSONDecoder().decode(JobRecord.self,from:data),job.status != "completed" else {return nil}
            return (url,job)
        }
        if let latest=jobs.max(by:{$0.1.created<$1.1.created}) { resume(from:latest.0,run:false) }
    }
    func resume(from url:URL,run:Bool=true) {
        guard !busy else { return }
        do {
            let record=try JSONDecoder().decode(JobRecord.self,from:Data(contentsOf:url))
            guard [1,2,4].contains(record.scale),record.instruction.count<=4000,(0.2...1).contains(record.strength) else { throw ForgeError.message("Invalid job settings.") }
            _=try GridPlan(width:record.width,height:record.height,columns:record.columns,rows:record.rows)
            let folder=url.deletingLastPathComponent(),source=folder.appendingPathComponent("source.png")
            guard FileManager.default.fileExists(atPath:source.path) else { throw ForgeError.message("Job source image not found.") }
            columns=record.columns;rows=record.rows;scale=record.scale;strength=Double(record.strength);instruction=record.instruction
            guard loadSource(source) else {return}
            guard sourceWidth*record.scale==record.width,sourceHeight*record.scale==record.height else {throw ForgeError.message("Job record and source image dimensions do not match.")}
            jobURL=folder
            total=record.columns*record.rows;completed=record.completed.count
            progress=Double(completed)/Double(total)*0.9
            status="Interrupted job ready · \(completed) / \(total) tiles saved."
            if run { execute(folder:folder,record:record,input:source) }
        } catch { errorMessage=error.localizedDescription }
    }
    private func writeRecord(_ record:JobRecord,folder:URL) throws {
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];try encoder.encode(record).write(to:folder.appendingPathComponent("job.json"),options:.atomic)
    }
    private func execute(folder:URL,record:JobRecord,input:URL) {
        guard signedIn,!busy,let runtime else { return }
        errorMessage=nil
        busy=true;showOriginal=false;after=nil;resultURL=nil;overlapError=nil;progress=0;completed=0;total=record.columns*record.rows;jobURL=folder
        let worker=GenerationWorker();self.worker=worker
        task=Task {
            var job=record
            do {
                status="Preparing source and overlapping tiles…"
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let target=folder.appendingPathComponent("source.png")
                let source=try await Task.detached(priority:.userInitiated) { () throws -> Raster in
                    let original=try Raster.load(input)
                    if input.standardizedFileURL != target.standardizedFileURL { try original.save(target) }
                    _=try GridPlan(width:job.width,height:job.height,columns:job.columns,rows:job.rows)
                    return original.resized(width:job.width,height:job.height)
                }.value
                try Task.checkCancellation()
                let grid=try GridPlan(width:source.width,height:source.height,columns:job.columns,rows:job.rows)
                let reference=folder.appendingPathComponent("reference.png")
                try await Task.detached { try Raster.load(target,maxEdge:1536).save(reference) }.value
                job.status="generating";try writeRecord(job,folder:folder)
                var images:[Raster]=[]
                for tile in grid.tiles {
                    try Task.checkCancellation()
                    let tileFolder=folder.appendingPathComponent(String(format:"tile-%02d",tile.id+1),isDirectory:true)
                    try FileManager.default.createDirectory(at:tileFolder,withIntermediateDirectories:true)
                    let output=tileFolder.appendingPathComponent("generated.png")
                    let cached=await Task.detached {TileCache.load(output)}.value
                    if cached == nil {
                        status="GPT is enhancing tile: \(tile.id+1) / \(total)…"
                        let cropped=source.cropped(tile.region),url=tileFolder.appendingPathComponent("input.png")
                        try await Task.detached { try cropped.save(url) }.value
                        _=try await Task.detached(priority:.userInitiated) {
                            try worker.run(runtime:runtime,tile:url,reference:reference,directory:tileFolder,instruction:record.instruction)
                        }.value
                        try Task.checkCancellation()
                    }
                    let generated=try await Task.detached { try cached ?? Raster.load(output) }.value
                    if !job.completed.contains(tile.id) { job.completed.append(tile.id) }
                    try writeRecord(job,folder:folder)
                    currentTile=NSImage(cgImage:try generated.cgImage(),size:.zero)
                    images.append(generated);completed=images.count;progress=Double(completed)/Double(total)*0.9
                }
                try Task.checkCancellation();status="Balancing lighting and tones, composing tiles…"
                let strength=job.strength
                let result=try await Task.detached(priority:.userInitiated) { try Composer.compose(source:source,plan:grid,generated:images,strength:strength) }.value
                try Task.checkCancellation()
                let final=folder.appendingPathComponent("TileForge-result.png")
                try await Task.detached { try result.image.save(final) }.value
                try Task.checkCancellation()
                after=NSImage(contentsOf:final);resultURL=final;resultWidth=result.image.width;resultHeight=result.image.height;overlapError=result.overlapError;progress=1
                job.status="completed";job.overlapError=result.overlapError;try writeRecord(job,folder:folder)
                status=result.overlapError>0.045 ? "Image ready · Inspect the joins closely." : "Image ready · You can export now."
            } catch is CancellationError { job.status="canceled";try? writeRecord(job,folder:folder);status="Stopped. Completed tiles were saved." }
            catch { job.status="failed";try? writeRecord(job,folder:folder);errorMessage=error.localizedDescription;status="Job stopped. You can resume using completed tiles." }
            busy=false;self.worker=nil
        }
    }
    func shutdown() { cancel();accountConnection?.close() }
    func cancel() { task?.cancel();worker?.cancel();status="Stopping…" }
    func export() {
        guard let resultURL else { return }
        let p=NSSavePanel();p.allowedContentTypes=[.png,.tiff];p.nameFieldStringValue="TileForge-\(resultWidth)x\(resultHeight).png"
        guard p.runModal() == .OK,let url=p.url else { return }
        do { if ["tif","tiff"].contains(url.pathExtension.lowercased()) { try Raster.load(resultURL).save(url) } else { if FileManager.default.fileExists(atPath:url.path) { try Data(contentsOf:resultURL).write(to:url,options:.atomic) } else { try FileManager.default.copyItem(at:resultURL,to:url) } };status="Saved: \(url.lastPathComponent)" } catch { errorMessage=error.localizedDescription }
    }
    func revealJob() { if let jobURL { NSWorkspace.shared.open(jobURL) } else { try? FileManager.default.createDirectory(at:root,withIntermediateDirectories:true);NSWorkspace.shared.open(root) } }
}
