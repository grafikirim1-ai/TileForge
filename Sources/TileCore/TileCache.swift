import Foundation
public enum TileCache {
    /// Only a decodable raster is reusable; existence alone is not a completed tile.
    public static func load(_ url:URL)->Raster? { try? Raster.load(url) }
}
