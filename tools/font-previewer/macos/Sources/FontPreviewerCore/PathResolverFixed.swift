import Foundation

public enum StudyPathResolver {
    public static func storedPath(for sourceURL: URL, projectURL: URL?) -> String {
        let source = sourceURL.standardizedFileURL.resolvingSymlinksInPath()
        guard let projectURL else { return source.path }

        let baseComponents = projectURL.deletingLastPathComponent().standardizedFileURL.pathComponents
        let sourceComponents = source.pathComponents
        var commonCount = 0
        for pair in zip(baseComponents, sourceComponents) {
            guard pair.0 == pair.1 else { break }
            commonCount += 1
        }
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
        let base = projectURL?.deletingLastPathComponent()
            ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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
        let values = try? sourceURL.resourceValues(forKeys: [.contentModificationDateKey])
        copy.sourceModifiedAt = values?.contentModificationDate
        return copy
    }
}
