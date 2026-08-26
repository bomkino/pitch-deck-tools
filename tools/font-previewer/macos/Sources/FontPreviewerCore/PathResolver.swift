import Foundation

public enum PathResolver {
    public static func storedPath(for sourceURL: URL, projectURL: URL?) -> String {
        let source = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let projectURL else { return source.path }

        let baseComponents = projectURL.deletingLastPathComponent().standardizedFileURL.pathComponents
        let sourceComponents = source.pathComponents
        let commonCount = zip(baseComponents, sourceComponents).prefix { $0 == $1 }.count
        guard commonCount >= 2 else { return source.path }

        let up = Array(repeating: "..", count: baseComponents.count - commonCount)
        let down = Array(sourceComponents.dropFirst(commonCount))
        let relative = (up + down).joined(separator: "/")
        return relative.isEmpty ? source.lastPathComponent : relative
    }

    public static func resolvedURL(for storedPath: String, projectURL: URL?) -> URL {
        if storedPath.hasPrefix("/") {
            return URL(fileURLWithPath: storedPath).standardizedFileURL
        }
        let base = projectURL?.deletingLastPathComponent() ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        return base.appendingPathComponent(storedPath).standardizedFileURL
    }

    public static func exists(storedPath: String, projectURL: URL?) -> Bool {
        FileManager.default.fileExists(atPath: resolvedURL(for: storedPath, projectURL: projectURL).path)
    }

    public static func replacingSource(
        in record: FontFaceRecord,
        with sourceURL: URL,
        projectURL: URL?
    ) -> FontFaceRecord {
        var copy = record
        copy.sourcePath = storedPath(for: sourceURL, projectURL: projectURL)
        copy.fileName = sourceURL.lastPathComponent
        copy.sourceModifiedAt = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        return copy
    }
}
