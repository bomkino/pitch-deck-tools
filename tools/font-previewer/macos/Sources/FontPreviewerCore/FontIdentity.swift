import Foundation

public enum FontIdentity {
    public static func key(for record: FontFaceRecord, projectURL: URL? = nil) -> String {
        key(sourcePath: record.sourcePath, faceIndex: record.faceIndex, projectURL: projectURL)
    }

    public static func key(sourcePath: String, faceIndex: Int, projectURL: URL? = nil) -> String {
        let canonical: String
        if sourcePath.hasPrefix("/") {
            canonical = canonicalPath(URL(fileURLWithPath: sourcePath))
        } else if let projectURL {
            canonical = canonicalPath(
                projectURL.deletingLastPathComponent().appendingPathComponent(sourcePath)
            )
        } else {
            canonical = "relative:" + normalizedRelativePath(sourcePath)
        }
        return "\(canonical)#\(faceIndex)"
    }

    public static func removingDuplicates(
        _ records: [FontFaceRecord],
        projectURL: URL? = nil
    ) -> [FontFaceRecord] {
        var seen: Set<String> = []
        return records.filter { record in
            seen.insert(key(for: record, projectURL: projectURL)).inserted
        }
    }

    private static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL
            .resolvingSymlinksInPath()
            .path
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }

    private static func normalizedRelativePath(_ path: String) -> String {
        var components: [String] = []
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            switch component {
            case ".": continue
            case "..":
                if components.last != ".." && !components.isEmpty { components.removeLast() }
                else { components.append("..") }
            default: components.append(String(component))
            }
        }
        return components.joined(separator: "/")
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }
}
