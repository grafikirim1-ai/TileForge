import XCTest
@testable import TileCore
final class AlignmentTests:XCTestCase {
    func testTranslationCorrectionPreservesFeaturePositions() throws {
        var source=Raster(width:128,height:128,color:[0.15,0.15,0.15,1])
        for y in 15..<110 {for x in 15..<110 {
            let value:Float = ((x/11+y/13)%2==0) ? 0.8 : 0.25
            for c in 0..<3 {source.pixels[(y*128+x)*4+c]=value}
        }}
        var shifted=source
        for y in 0..<128 {for x in 0..<128 {for c in 0..<4 {shifted.pixels[(y*128+x)*4+c]=source.pixels[(y*128+max(0,x-6))*4+c]}}}
        let aligned=try Alignment.correct(shifted,reference:source)
        var before:Float=0,after:Float=0
        for y in 20..<105 {for x in 20..<105 {let i=(y*128+x)*4;before += abs(shifted.pixels[i]-source.pixels[i]);after += abs(aligned.pixels[i]-source.pixels[i])}}
        XCTAssertLessThan(after,before*0.4)
    }
    func testFlatImagesRemainUnshifted() throws {
        let source=Raster(width:40,height:30,color:[0.4,0.4,0.4,1])
        XCTAssertEqual(try Alignment.correct(source,reference:source).pixels,source.pixels)
    }
}
