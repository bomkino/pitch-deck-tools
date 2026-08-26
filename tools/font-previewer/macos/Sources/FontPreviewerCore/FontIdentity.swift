import Foundation

public enum FontIdentity {
    public static func key(for record: FontFaceRecord) -> String {
        key(sourcePath: record.sourcePath, faceIndex: record.faceIndex)
    }

    public static func key(sourcePath: String, faceIndex: Int) -> String {
        let standardized = URL(fileURLWithPath: sourcePath)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
            .precomposedStringWithCanonicalMapping
            .lowercased()
        return "\(standardized)#\(faceIndex)"
    }

    public static func removingDuplicates(_ records: [FontFaceRecord]) -> [FontFaceRecord] {
        var seen: Set<String> = []
        return records.filter { record in
            seen.insert(key(for: record)).inserted
        }
    }
}
