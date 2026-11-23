import XCTest
@testable import TileCore
final class RuntimeTests: XCTestCase {
    func testOnlyGeneratedImagePathsAccepted() throws {
        let root=URL(fileURLWithPath:"/tmp/forge/generated_images")
        XCTAssertEqual(try GeneratedOutput.path(from:"/tmp/forge/generated_images/job/a.png\n",root:root).lastPathComponent,"a.png")
        XCTAssertThrowsError(try GeneratedOutput.path(from:"/etc/passwd",root:root))
        XCTAssertThrowsError(try GeneratedOutput.path(from:"/tmp/forge/generated_images/../secret.png",root:root))
        XCTAssertThrowsError(try GeneratedOutput.path(from:"UNAVAILABLE",root:root))
    }
    func testPromptIsNotConsumedAsAnImageFilename() {
        let args=GenerationWorker.arguments(tile:URL(fileURLWithPath:"/tmp/a b.png"),reference:URL(fileURLWithPath:"/tmp/ref.png"),answer:URL(fileURLWithPath:"/tmp/reply.txt"),instruction:"Keep texture")
        XCTAssertEqual(args[args.count-2],"--")
        XCTAssertTrue(args.last!.contains("Keep texture"))
        XCTAssertTrue(args.contains("/tmp/a b.png"))
    }
    func testWorkerRejectsFailedTurnEvenWhenRuntimeExitsZero() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:dir)}
        let fake=dir.appendingPathComponent("fake-codex")
        try Data("#!/bin/sh\nprintf '%s\\n' '{\"type\":\"turn.failed\",\"error\":{\"message\":\"quota\"}}'\nexit 0\n".utf8).write(to:fake)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:fake.path)
        try Raster(width:2,height:2,color:[1,0,0,1]).save(dir.appendingPathComponent("b.png"))
        XCTAssertThrowsError(try GenerationWorker().run(runtime:fake,tile:dir.appendingPathComponent("a.png"),reference:dir.appendingPathComponent("b.png"),directory:dir,instruction:"test")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Codex generation failed"),error.localizedDescription)
        }
    }
    func testWorkerMakesReferenceAvailableInTileDirectory() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        let tileDir=dir.appendingPathComponent("tile-08",isDirectory:true)
        try FileManager.default.createDirectory(at:tileDir,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:dir)}
        let reference=dir.appendingPathComponent("reference.png")
        try Raster(width:4,height:4,color:[1,0,0,1]).save(reference)
        let tile=tileDir.appendingPathComponent("input.png")
        try Raster(width:2,height:2,color:[0,1,0,1]).save(tile)
        let fake=dir.appendingPathComponent("fake-codex")
        try Data("#!/bin/sh\nif [ -f reference.png ]; then touch reference-found; fi\nprintf '%s\\n' '{\"type\":\"turn.failed\",\"error\":{\"message\":\"probe\"}}'\n".utf8).write(to:fake)
        try FileManager.default.setAttributes([.posixPermissions:0o755],ofItemAtPath:fake.path)
        XCTAssertThrowsError(try GenerationWorker().run(runtime:fake,tile:tile,reference:reference,directory:tileDir,instruction:"test"))
        XCTAssertTrue(FileManager.default.fileExists(atPath:tileDir.appendingPathComponent("reference-found").path))
        XCTAssertNotNil(TileCache.load(tileDir.appendingPathComponent("reference.png")))
    }
    func testCorruptTileIsNotReused() throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        defer {try? FileManager.default.removeItem(at:url)}
        try Data("truncated".utf8).write(to:url)
        XCTAssertNil(TileCache.load(url))
        try Raster(width:4,height:4,color:[1,0,0,1]).save(url)
        XCTAssertNotNil(TileCache.load(url))
    }
    func testFailedTurnNeverAccepted() {
        XCTAssertThrowsError(try GeneratedOutput.validateEvent(["type":"turn.failed","error":["message":"limit"]]))
    }
    func testPNGOrientationRoundTrip() throws {
        var r=Raster(width:3,height:2,color:[0,0,0,1]);r.pixels[0]=1;r.pixels[(1*3+2)*4+2]=1
        let u=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".png")
        defer { try? FileManager.default.removeItem(at:u) };try r.save(u)
        let loaded=try Raster.load(u)
        XCTAssertEqual(loaded.pixels[0],1,accuracy:0.01)
        XCTAssertEqual(loaded.pixels[(1*3+2)*4+2],1,accuracy:0.01)
    }
}
