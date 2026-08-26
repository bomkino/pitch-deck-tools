import AppKit
import CoreText
import Foundation
import FontPreviewerCore

struct FontImportResult {
    var records: [FontFaceRecord]
    var runtimes: [UUID: RuntimeFontFace]
    var failures: [FontImportFailure]
}

struct FontImportFailure: Identifiable, Hashable {
    let id = UUID()
    var url: URL
    var reason: String
}

final class RuntimeFontFace {
    let sourceURL: URL
    let faceIndex: Int
    let descriptor: CTFontDescriptor

    init(sourceURL: URL, faceIndex: Int, descriptor: CTFontDescriptor) {
        self.sourceURL = sourceURL
        self.faceIndex = faceIndex
        self.descriptor = descriptor
    }

    func makeFont(size: CGFloat, variations: [UInt32: Double]) -> CTFont {
        let base = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        guard !variations.isEmpty else { return base }

        let dictionary = NSMutableDictionary()
        for (identifier, value) in variations {
            dictionary[NSNumber(value: identifier)] = NSNumber(value: value)
        }
        return CTFontCreateCopyWithVariations(base, dictionary) ?? base
    }

    func missingScalars(in text: String, variations: [UInt32: Double]) -> [Unicode.Scalar] {
        let font = makeFont(size: 48, variations: variations)
        let characterSet = CTFontCopyCharacterSet(font) as CharacterSet
        var seen: Set<UInt32> = []
        var missing: [Unicode.Scalar] = []
        for scalar in text.unicodeScalars where !scalar.properties.isWhitespace {
            guard seen.insert(scalar.value).inserted else { continue }
            if !characterSet.contains(scalar) { missing.append(scalar) }
        }
        return missing
    }
}

enum FontCatalog {
    static let supportedExtensions: Set<String> = [
        "otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"
    ]

    static func fontURLs(from selections: [URL]) -> [URL] {
        var output: [URL] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey]

        for selection in selections {
            let values = try? selection.resourceValues(forKeys: keys)
            if values?.isDirectory == true {
                guard let enumerator = FileManager.default.enumerator(
                    at: selection,
                    includingPropertiesForKeys: Array(keys),
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }
                for case let child as URL in enumerator {
                    guard supportedExtensions.contains(child.pathExtension.lowercased()) else { continue }
                    let childValues = try? child.resourceValues(forKeys: keys)
                    if childValues?.isRegularFile == true { output.append(child) }
                }
            } else if supportedExtensions.contains(selection.pathExtension.lowercased()) {
                output.append(selection)
            }
        }

        var seen: Set<String> = []
        return output
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .filter { seen.insert($0.path.lowercased()).inserted }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    static func importFaces(from selections: [URL], projectURL: URL?) -> FontImportResult {
        let urls = fontURLs(from: selections)
        var records: [FontFaceRecord] = []
        var runtimes: [UUID: RuntimeFontFace] = [:]
        var failures: [FontImportFailure] = []

        for url in urls {
            guard let rawDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) else {
                failures.append(FontImportFailure(url: url, reason: "CoreText could not read this file."))
                continue
            }
            let descriptors = rawDescriptors as NSArray
            guard descriptors.count > 0 else {
                failures.append(FontImportFailure(url: url, reason: "No font faces were found."))
                continue
            }

            for offset in 0..<descriptors.count {
                guard let descriptor = descriptors[offset] as? CTFontDescriptor else { continue }
                let base = CTFontCreateWithFontDescriptor(descriptor, 64, nil)
                let descriptorIndex = numberAttribute(descriptor, key: kCTFontIndexAttribute)?.intValue
                let faceIndex = descriptorIndex ?? offset
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let family = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontFamilyNameAttribute),
                    fallback: CTFontCopyFamilyName(base) as String
                )
                let style = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontStyleNameAttribute),
                    fallback: CTFontCopyStyleName(base) as String
                )
                let postScript = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontNameAttribute),
                    fallback: CTFontCopyPostScriptName(base) as String
                )
                let axes = variationAxes(for: base)
                var defaults: [UInt32: Double] = [:]
                for axis in axes { defaults[axis.identifier] = axis.defaultValue }

                let record = FontFaceRecord(
                    sourcePath: StudyPathResolver.storedPath(for: url, projectURL: projectURL),
                    faceIndex: faceIndex,
                    fileName: url.lastPathComponent,
                    familyName: family,
                    styleName: style,
                    postScriptName: postScript,
                    format: url.pathExtension.uppercased(),
                    fileSize: Int64(values?.fileSize ?? 0),
                    axes: axes,
                    axisValues: defaults,
                    sourceModifiedAt: values?.contentModificationDate
                )
                records.append(record)
                runtimes[record.id] = RuntimeFontFace(
                    sourceURL: url,
                    faceIndex: faceIndex,
                    descriptor: descriptor
                )
            }
        }

        return FontImportResult(records: records, runtimes: runtimes, failures: failures)
    }

    static func reload(record: FontFaceRecord, projectURL: URL?) -> (FontFaceRecord, RuntimeFontFace)? {
        let url = StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL)
        let imported = importFaces(from: [url], projectURL: projectURL)
        guard let match = imported.records.first(where: { $0.faceIndex == record.faceIndex }),
              let runtime = imported.runtimes[match.id]
        else { return nil }

        var merged = match
        merged.id = record.id
        merged.casing = record.casing
        merged.status = record.status
        merged.tags = record.tags
        merged.notes = record.notes
        for axis in merged.axes {
            if let oldValue = record.axisValues[axis.identifier] {
                merged.axisValues[axis.identifier] = min(axis.maximum, max(axis.minimum, oldValue))
            }
        }
        return (
            merged,
            RuntimeFontFace(sourceURL: runtime.sourceURL, faceIndex: runtime.faceIndex, descriptor: runtime.descriptor)
        )
    }

    private static func variationAxes(for font: CTFont) -> [FontAxis] {
        guard let raw = CTFontCopyVariationAxes(font) else { return [] }
        let array = raw as NSArray
        var axes: [FontAxis] = []

        for case let dictionary as NSDictionary in array {
            guard let identifier = (dictionary[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.uint32Value,
                  let minimum = (dictionary[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue,
                  let maximum = (dictionary[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue,
                  let defaultValue = (dictionary[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue
            else { continue }

            let name = (dictionary[kCTFontVariationAxisNameKey] as? String) ?? axisTag(identifier)
            axes.append(FontAxis(
                identifier: identifier,
                tag: axisTag(identifier),
                name: name,
                minimum: minimum,
                maximum: maximum,
                defaultValue: defaultValue
            ))
        }
        return axes.sorted { $0.tag.localizedStandardCompare($1.tag) == .orderedAscending }
    }

    private static func axisTag(_ identifier: UInt32) -> String {
        let bytes: [UInt8] = [
            UInt8((identifier >> 24) & 0xff),
            UInt8((identifier >> 16) & 0xff),
            UInt8((identifier >> 8) & 0xff),
            UInt8(identifier & 0xff),
        ]
        guard bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }),
              let tag = String(bytes: bytes, encoding: .ascii)
        else { return String(identifier) }
        return tag
    }

    private static func stringAttribute(_ descriptor: CTFontDescriptor, key: CFString) -> String? {
        CTFontDescriptorCopyAttribute(descriptor, key) as? String
    }

    private static func numberAttribute(_ descriptor: CTFontDescriptor, key: CFString) -> NSNumber? {
        CTFontDescriptorCopyAttribute(descriptor, key) as? NSNumber
    }

    private static func nonEmpty(_ candidate: String?, fallback: String) -> String {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
