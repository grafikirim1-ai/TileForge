import Foundation
import TileCore
@main struct Check {
    @MainActor static func main() async {
        do {
            let args=CommandLine.arguments
            guard args.count>=4 else { print("usage: ForgeCheck CODEX SOURCE OUTPUT_DIR [account-only]");exit(2) }
            let runtime=URL(fileURLWithPath:args[1]),input=URL(fileURLWithPath:args[2]),folder=URL(fileURLWithPath:args[3],isDirectory:true)
            let connection=AccountConnection(runtime:runtime)
            guard let (_,plan)=try await connection.account() else { throw ForgeError.message("No ChatGPT account") }
            print("ChatGPT OAuth account: connected; plan: \(plan)");connection.close()
            if args.last=="account-only" {
                async let a=connection.account()
                async let b=connection.account()
                _=try await (a,b)
                connection.close()
                _=try await connection.account();connection.close()
                print("PASS: concurrent account reads and reconnect")
                exit(0)
            }
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let original=try Raster.load(input,maxEdge:512)
            let reference=folder.appendingPathComponent("reference.png");try original.save(reference)
            let source=original.resized(width:original.width*2,height:original.height*2)
            let grid=try GridPlan(width:source.width,height:source.height,columns:2,rows:2)
            let worker=GenerationWorker();var generated:[Raster]=[]
            for tile in grid.tiles {
                let dir=folder.appendingPathComponent("tile-\(tile.id)",isDirectory:true);try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
                let tileURL=dir.appendingPathComponent("input.png");try source.cropped(tile.region).save(tileURL)
                let output=dir.appendingPathComponent("generated.png")
                if !FileManager.default.fileExists(atPath:output.path) {
                    print("Generating \(tile.id+1)/4");fflush(stdout)
                    _=try await Task.detached {try worker.run(runtime:runtime,tile:tileURL,reference:reference,directory:dir,instruction:"Preserve composition exactly; improve subtle surface texture.")}.value
                }
                generated.append(try Raster.load(output))
            }
            let result=try Composer.compose(source:source,plan:grid,generated:generated)
            try result.image.save(folder.appendingPathComponent("result.png"))
            let report:[String:Any]=["tiles":4,"width":result.image.width,"height":result.image.height,"overlapError":result.overlapError,"status":"completed","apiKeyUsed":false]
            try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("report.json"))
            print("PASS: 2x2 generation, composition, PNG output. Overlap error: \(result.overlapError)")
        } catch { print("FAIL: \(error.localizedDescription)");exit(1) }
    }
}
