import XCTest
@testable import TileForge
import TileCore

final class ResumeTests: XCTestCase {
    @MainActor func testStartKeepsInterruptedJobInsteadOfCreatingNewOne() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:dir)}
        let source=dir.appendingPathComponent("source.png")
        try Raster(width:4,height:4,color:[1,0,0,1]).save(source)
        let record=JobRecord(id:dir.lastPathComponent,created:Date(),columns:2,rows:2,scale:1,instruction:"test",strength:1,width:4,height:4,completed:[0],status:"failed",overlapError:nil)
        try JSONEncoder().encode(record).write(to:dir.appendingPathComponent("job.json"))
        let model=ForgeModel()
        XCTAssertTrue(model.loadSource(source))
        model.signedIn=true;model.jobURL=dir
        model.start()
        XCTAssertEqual(model.jobURL,dir)
        XCTAssertEqual(model.scale,1)
        model.cancel()
    }
}
