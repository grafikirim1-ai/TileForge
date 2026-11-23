import XCTest
@testable import TileCore
final class CoreTests: XCTestCase {
    func testOddGridHasExactCoverageAndContext() throws {
        let p = try GridPlan(width: 101, height: 79, columns: 3, rows: 2)
        XCTAssertEqual(p.tiles.count, 6)
        var coverage = Array(repeating: 0, count: 101 * 79)
        for t in p.tiles {
            XCTAssertGreaterThanOrEqual(t.core.x, t.region.x)
            XCTAssertLessThanOrEqual(t.region.maxX, 101)
            for y in t.core.y..<t.core.maxY { for x in t.core.x..<t.core.maxX { coverage[y*101+x] += 1 } }
        }
        XCTAssertTrue(coverage.allSatisfy { $0 == 1 })
        XCTAssertGreaterThan(p.tiles[0].region.width, p.tiles[0].core.width)
    }
    func testInvalidGridRejected() {
        XCTAssertThrowsError(try GridPlan(width: 2, height: 2, columns: 4, rows: 2))
        XCTAssertThrowsError(try GridPlan(width: 20000, height: 20000, columns: 2, rows: 2))
    }
    func testConstantReconstructionAndExposureCorrection() throws {
        let source = Raster(width: 48, height: 40, color: [0.3,0.4,0.5,1])
        let plan = try GridPlan(width: 48, height: 40, columns: 2, rows: 2)
        let parts = plan.tiles.map { t in Raster(width: t.region.width, height: t.region.height, color: [0.7,0.2,0.8,1]) }
        let result = try Composer.compose(source: source, plan: plan, generated: parts)
        for i in stride(from: 0, to: result.image.pixels.count, by: 4) {
            XCTAssertEqual(result.image.pixels[i], 0.3, accuracy: 0.001)
            XCTAssertEqual(result.image.pixels[i+1], 0.4, accuracy: 0.001)
            XCTAssertEqual(result.image.pixels[i+3], 1, accuracy: 0.001)
        }
    }
    func testMissingTilesRejected() throws {
        let source = Raster(width: 20, height: 20, color: [0,0,0,1])
        XCTAssertThrowsError(try Composer.compose(source: source, plan: GridPlan(width:20,height:20,columns:2,rows:2), generated: []))
    }
    func testTransparentSourceRemainsTransparent() throws {
        let source = Raster(width: 20, height: 20, color: [0,0,0,0])
        let p = try GridPlan(width:20,height:20,columns:2,rows:2)
        let result = try Composer.compose(source:source,plan:p,generated:p.tiles.map { Raster(width:$0.region.width,height:$0.region.height,color:[1,1,1,1]) })
        XCTAssertTrue(stride(from:3,to:result.image.pixels.count,by:4).allSatisfy { result.image.pixels[$0] == 0 })
    }
}
