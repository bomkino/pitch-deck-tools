import Darwin
import Foundation

public final class FontSourceWatcher {
    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private let queue = DispatchQueue(label: "dog.pitch.font-previewer.source-watch", qos: .utility)

    public init() {}

    deinit { stop() }

    public func replace(urls: [URL], onChange: @escaping @Sendable (URL) -> Void) {
        stop()
        var seen: Set<String> = []

        for url in urls {
            let standardized = url.standardizedFileURL.resolvingSymlinksInPath()
            let path = standardized.path
            guard seen.insert(path).inserted else { continue }
            let descriptor = open(path, O_EVTONLY)
            guard descriptor >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: descriptor,
                eventMask: [.write, .rename, .delete, .attrib, .extend],
                queue: queue
            )
            source.setEventHandler { onChange(standardized) }
            source.setCancelHandler { close(descriptor) }
            sources[path] = source
            source.resume()
        }
    }

    public func stop() {
        for source in sources.values { source.cancel() }
        sources.removeAll()
    }
}
