import Foundation
public enum GeneratedOutput {
    public static func path(from text:String, root:URL) throws -> URL {
        let cleaned=text.trimmingCharacters(in:.whitespacesAndNewlines).trimmingCharacters(in:CharacterSet(charactersIn:"`\""))
        let url=URL(fileURLWithPath:cleaned).standardizedFileURL.resolvingSymlinksInPath()
        let prefix=root.standardizedFileURL.resolvingSymlinksInPath().path+"/"
        guard cleaned.hasPrefix("/"),url.path.hasPrefix(prefix),["png","jpg","jpeg","webp"].contains(url.pathExtension.lowercased()) else { throw ForgeError.message("Codex did not return a valid image. The image tool may be unavailable in this session.") }
        return url
    }
    public static func validateEvent(_ event:[String:Any]) throws {
        if event["type"] as? String == "turn.failed" || event["type"] as? String == "error" { throw ForgeError.message("Codex generation failed; check your account limits and connection.") }
    }
}
