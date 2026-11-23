import Foundation
public enum Alignment {
    /// Bounded translation search on a reduced image. A match must improve before applying it.
    public static func correct(_ generated:Raster,reference:Raster) throws -> Raster {
        guard generated.width==reference.width,generated.height==reference.height else { throw ForgeError.message("Alignment dimensions do not match.") }
        let w=reference.width,h=reference.height,sw=min(reference.width,96),sh=min(reference.height,96)
        guard sw>=20,sh>=20 else {return generated}
        let ref=reference.resized(width:sw,height:sh),gen=generated.resized(width:sw,height:sh)
        func normalized(_ image:Raster)->[Float] {
            var a=[Float](repeating:0,count:sw*sh)
            for i in 0..<a.count {a[i]=image.pixels[i*4]*0.2126+image.pixels[i*4+1]*0.7152+image.pixels[i*4+2]*0.0722}
            let mean=a.reduce(0,+)/Float(a.count)
            var variance:Float=0;for v in a {variance += (v-mean)*(v-mean)}
            let sd=max(0.01,sqrt(variance/Float(a.count)))
            return a.map {($0-mean)/sd}
        }
        let a=normalized(ref),b=normalized(gen),rx=max(1,sw/12),ry=max(1,sh/12)
        let mx=rx+1,my=ry+1
        func score(_ dx:Int,_ dy:Int)->Float {
            var s:Float=0
            for y in stride(from:my,to:sh-my,by:2) {for x in stride(from:mx,to:sw-mx,by:2) {
                let d=a[y*sw+x]-b[(y+dy)*sw+x+dx];s += d*d
            }}
            return s
        }
        let baseline=score(0,0);var bestScore=baseline,best=(0,0)
        guard baseline>0.001 else {return generated}
        for dy in -ry...ry {for dx in -rx...rx {let s=score(dx,dy);if s<bestScore {bestScore=s;best=(dx,dy)}}}
        guard bestScore<baseline*0.75 else {return generated}
        let dx=Int((Float(best.0)*Float(w)/Float(sw)).rounded()),dy=Int((Float(best.1)*Float(h)/Float(sh)).rounded())
        var out=generated
        for y in 0..<h {for x in 0..<w {
            let sx=max(0,min(w-1,x+dx)),sy=max(0,min(h-1,y+dy))
            for c in 0..<4 {out.pixels[(y*w+x)*4+c]=generated.pixels[(sy*w+sx)*4+c]}
        }}
        return out
    }
}
