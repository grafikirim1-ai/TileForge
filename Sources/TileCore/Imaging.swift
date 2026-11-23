import Foundation
import Darwin
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum ForgeError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let s) = self { return s }; return nil }
}
public struct PixelRect: Codable, Sendable {
    public let x, y, width, height: Int
    public var maxX: Int { x + width }; public var maxY: Int { y + height }
}
public struct Tile: Codable, Identifiable, Sendable {
    public let id: Int, core: PixelRect, region: PixelRect
}
public struct GridPlan: Codable, Sendable {
    public let width, height, columns, rows: Int
    public let tiles: [Tile]
    public init(width: Int, height: Int, columns: Int, rows: Int) throws {
        guard width > 0, height > 0, width <= 24000, height <= 24000,
              width * height <= 48_000_000, (1...8).contains(columns), (1...8).contains(rows),
              columns <= width, rows <= height else { throw ForgeError.message("Invalid grid or image too large (maximum 48 MP).") }
        self.width=width; self.height=height; self.columns=columns; self.rows=rows
        var tiles: [Tile] = []
        let mx = max(2, width / columns / 4), my = max(2, height / rows / 4)
        for row in 0..<rows { for col in 0..<columns {
            let x = col*width/columns, y = row*height/rows
            let ex = (col+1)*width/columns, ey = (row+1)*height/rows
            let rx = max(0,x-mx), ry = max(0,y-my)
            tiles.append(Tile(id:row*columns+col,core:PixelRect(x:x,y:y,width:ex-x,height:ey-y),region:PixelRect(x:rx,y:ry,width:min(width,ex+mx)-rx,height:min(height,ey+my)-ry)))
        } }
        self.tiles=tiles
    }
}
public struct Raster: Sendable {
    public let width, height: Int
    public var pixels: [Float] // premultiplied RGBA, sRGB, top-down
    public init(width: Int, height: Int, color: [Float]) {
        self.width=width; self.height=height
        self.pixels=Array(repeating: color, count: width*height).flatMap { $0 }
    }
    public init(width: Int, height: Int, pixels: [Float]) { self.width=width; self.height=height; self.pixels=pixels }
    public init(cgImage: CGImage) throws {
        width=cgImage.width; height=cgImage.height; pixels=[]
        var bytes = [UInt8](repeating:0,count:width*height*4)
        let ok = bytes.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data:buf.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cgImage,in:CGRect(x:0,y:0,width:width,height:height)); return true
        }
        guard ok else { throw ForgeError.message("Could not load the image into memory.") }
        pixels=bytes.map { Float($0)/255 }
    }
    public static func load(_ url: URL, maxEdge: Int? = nil) throws -> Raster {
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil) else { throw ForgeError.message("Could not read the image.") }
        let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any]
        let w=props?[kCGImagePropertyPixelWidth] as? Int ?? 0, h=props?[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard w>0,h>0,w<=40000,h<=40000 else { throw ForgeError.message("Unsupported image dimensions.") }
        let edge = maxEdge ?? max(w,h)
        guard maxEdge != nil || w*h<=48_000_000 else { throw ForgeError.message("Source image exceeds the 48 MP limit.") }
        let opts: [CFString:Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:edge,kCGImageSourceShouldCacheImmediately:true]
        guard let cg=CGImageSourceCreateThumbnailAtIndex(source,0,opts as CFDictionary) else { throw ForgeError.message("Could not decode the image.") }
        return try Raster(cgImage:cg)
    }
    public func cgImage() throws -> CGImage {
        let data=Data(pixels.map { UInt8(max(0,min(255,($0*255).rounded()))) })
        guard let provider=CGDataProvider(data:data as CFData), let cg=CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else { throw ForgeError.message("Could not create the image.") }
        return cg
    }
    public func save(_ url: URL) throws {
        let type = url.pathExtension.lowercased() == "tiff" || url.pathExtension.lowercased() == "tif" ? UTType.tiff.identifier : UTType.png.identifier
        let temporary=url.deletingLastPathComponent().appendingPathComponent(".tileforge-\(UUID().uuidString).\(url.pathExtension)")
        defer {try? FileManager.default.removeItem(at:temporary)}
        guard let dest=CGImageDestinationCreateWithURL(temporary as CFURL,type as CFString,1,nil) else { throw ForgeError.message("Could not write the file.") }
        CGImageDestinationAddImage(dest,try cgImage(),[kCGImagePropertyDPIWidth:300,kCGImagePropertyDPIHeight:300] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw ForgeError.message("Export failed.") }
        guard rename(temporary.path,url.path)==0 else {throw ForgeError.message("Could not save the image file.")}
    }
    public func cropped(_ r: PixelRect) -> Raster {
        var out=[Float](repeating:0,count:r.width*r.height*4)
        for y in 0..<r.height { let a=((r.y+y)*width+r.x)*4, b=y*r.width*4; out.replaceSubrange(b..<b+r.width*4,with:pixels[a..<a+r.width*4]) }
        return Raster(width:r.width,height:r.height,pixels:out)
    }
    public func resized(width w:Int,height h:Int) -> Raster {
        if w==width && h==height { return self }
        var out=[Float](repeating:0,count:w*h*4)
        for y in 0..<h { let sy=max(0,min(Float(height-1),(Float(y)+0.5)*Float(height)/Float(h)-0.5)), y0=Int(sy), y1=min(height-1,y0+1), fy=sy-Float(y0)
            for x in 0..<w { let sx=max(0,min(Float(width-1),(Float(x)+0.5)*Float(width)/Float(w)-0.5)), x0=Int(sx), x1=min(width-1,x0+1), fx=sx-Float(x0)
                for c in 0..<4 { let a=pixels[(y0*width+x0)*4+c]*(1-fx)+pixels[(y0*width+x1)*4+c]*fx, b=pixels[(y1*width+x0)*4+c]*(1-fx)+pixels[(y1*width+x1)*4+c]*fx; out[(y*w+x)*4+c]=a*(1-fy)+b*fy }
            }
        }
        return Raster(width:w,height:h,pixels:out)
    }
    public func blurred(radius: Int) -> Raster {
        let r=max(1,radius)
        var tmp=[Float](repeating:0,count:pixels.count), out=tmp
        for y in 0..<height { for c in 0..<4 {
            var sum:Float=0
            for k in -r...r { sum += pixels[(y*width+max(0,min(width-1,k)))*4+c] }
            for x in 0..<width { tmp[(y*width+x)*4+c]=sum/Float(2*r+1); sum += pixels[(y*width+min(width-1,x+r+1))*4+c]-pixels[(y*width+max(0,x-r))*4+c] }
        } }
        for x in 0..<width { for c in 0..<4 {
            var sum:Float=0
            for k in -r...r { sum += tmp[(max(0,min(height-1,k))*width+x)*4+c] }
            for y in 0..<height { out[(y*width+x)*4+c]=sum/Float(2*r+1); sum += tmp[(min(height-1,y+r+1)*width+x)*4+c]-tmp[(max(0,y-r)*width+x)*4+c] }
        } }
        return Raster(width:width,height:height,pixels:out)
    }
}
public struct CompositionResult: Sendable { public let image: Raster; public let overlapError: Float }
public enum Composer {
    public static func compose(source:Raster,plan:GridPlan,generated:[Raster],strength:Float=0.8) throws -> CompositionResult {
        guard generated.count==plan.tiles.count,source.width==plan.width,source.height==plan.height else { throw ForgeError.message("Missing or incompatible tiles; composition stopped.") }
        var out=[Float](repeating:0,count:source.pixels.count), weights=[Float](repeating:0,count:source.width*source.height)
        var mismatch:Float=0, samples:Float=0
        for (tile,raw) in zip(plan.tiles,generated) {
            let r=tile.region, ref=source.cropped(r)
            let g=try Alignment.correct(raw.resized(width:r.width,height:r.height),reference:ref)
            let radius=max(2,min(r.width,r.height)/24)
            let lowG=g.blurred(radius:radius), lowR=ref.blurred(radius:radius)
            for y in 0..<r.height { for x in 0..<r.width {
                let gx=r.x+x, gy=r.y+y, dest=gy*source.width+gx, src=(y*r.width+x)*4
                func ramp(_ p:Int,_ a:Int,_ b:Int,_ lo:Int,_ hi:Int)->Float {
                    if p<a && a>lo { let v=Float(p-lo+1)/Float(a-lo+1); return 0.5-0.5*cos(.pi*v) }
                    if p>=b && hi>b { let v=Float(hi-p)/Float(hi-b+1); return 0.5-0.5*cos(.pi*v) }
                    return 1
                }
                let weight=ramp(gx,tile.core.x,tile.core.maxX,r.x,r.maxX)*ramp(gy,tile.core.y,tile.core.maxY,r.y,r.maxY)
                let alpha=ref.pixels[src+3]
                for c in 0..<3 {
                    // Preserve the source's broad illumination; transfer high-frequency generated detail.
                    let value=max(0,min(alpha,lowR.pixels[src+c]+(g.pixels[src+c]-lowG.pixels[src+c])*strength+(ref.pixels[src+c]-lowR.pixels[src+c])*(1-strength)))
                    if weights[dest]>0 { mismatch += abs(out[dest*4+c]/weights[dest]-value); samples += 1 }
                    out[dest*4+c] += value*weight
                }
                out[dest*4+3] += alpha*weight; weights[dest] += weight
            } }
        }
        for i in 0..<weights.count { guard weights[i]>0 else { throw ForgeError.message("Composition contains an uncovered area.") }; for c in 0..<4 { out[i*4+c] /= weights[i] } }
        return CompositionResult(image:Raster(width:source.width,height:source.height,pixels:out),overlapError:samples>0 ? mismatch/samples : 0)
    }
}
