import AppKit
import CoreText
import Foundation
import FontPreviewerCore

public struct FontImportFailure: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var url: URL
    public var reason: String

    public init(url: URL, reason: String) {
        self.url = url
        self.reason = reason
    }
}

public struct FontImportResult: @unchecked Sendable {
    public var records: [FontFaceRecord]
    public var runtimes: [UUID: RuntimeFontFace]
    public var failures: [FontImportFailure]
    public var scannedFileCount: Int

    public init(
        records: [FontFaceRecord],
        runtimes: [UUID: RuntimeFontFace],
        failures: [FontImportFailure],
        scannedFileCount: Int
    ) {
        self.records = records
        self.runtimes = runtimes
        self.failures = failures
        self.scannedFileCount = scannedFileCount
    }
}

public final class RuntimeFontFace: @unchecked Sendable {
    public let sourceURL: URL
    public let faceIndex: Int
    public let descriptor: CTFontDescriptor

    public init(sourceURL: URL, faceIndex: Int, descriptor: CTFontDescriptor) {
        self.sourceURL = sourceURL
        self.faceIndex = faceIndex
        self.descriptor = descriptor
    }

    public func makeFont(
        size: CGFloat,
        variations: [UInt32: Double],
        featureSelections: [Int: Int] = [:]
    ) -> CTFont {
        // Build one descriptor for both the live preview and every export path. CoreText's
        // descriptor-copy helpers preserve the source face while applying one explicit
        // feature or variation at a time; sorting keeps the result deterministic.
        var workingDescriptor = descriptor
        for (type, selector) in featureSelections.sorted(by: { $0.key < $1.key }) {
            workingDescriptor = CTFontDescriptorCreateCopyWithFeature(
                workingDescriptor,
                NSNumber(value: type),
                NSNumber(value: selector)
            )
        }
        for (identifier, value) in variations.sorted(by: { $0.key < $1.key }) {
            workingDescriptor = CTFontDescriptorCreateCopyWithVariation(
                workingDescriptor,
                NSNumber(value: identifier),
                CGFloat(value)
            )
        }
        return CTFontCreateWithFontDescriptor(workingDescriptor, size, nil)
    }

    public func missingScalars(
        in text: String,
        variations: [UInt32: Double],
        featureSelections: [Int: Int] = [:]
    ) -> [Unicode.Scalar] {
        let font = makeFont(size: 48, variations: variations, featureSelections: featureSelections)
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

public enum FontCatalog {
    public static let supportedExtensions: Set<String> = [
        "otf", "ttf", "ttc", "otc", "dfont", "woff", "woff2"
    ]

    public static func fontURLs(from selections: [URL], maximumFiles: Int = 10_000) -> [URL] {
        var output: [URL] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .isPackageKey]

        selectionLoop: for selection in selections {
            if Task.isCancelled { break }
            let values = try? selection.resourceValues(forKeys: keys)
            if values?.isDirectory == true {
                // Recursion is explicit so very large trees can be cancelled and capped without
                // FileManager eagerly walking everything.
                var directories: [URL] = [selection]
                while let directory = directories.popLast() {
                    if Task.isCancelled { break selectionLoop }
                    guard let children = try? FileManager.default.contentsOfDirectory(
                        at: directory,
                        includingPropertiesForKeys: Array(keys),
                        options: [.skipsHiddenFiles]
                    ) else { continue }
                    for child in children {
                        if output.count >= maximumFiles { break selectionLoop }
                        let childValues = try? child.resourceValues(forKeys: keys)
                        if childValues?.isPackage == true { continue }
                        if childValues?.isDirectory == true {
                            directories.append(child)
                        } else if childValues?.isRegularFile == true,
                                  supportedExtensions.contains(child.pathExtension.lowercased()) {
                            output.append(child)
                        }
                    }
                }
            } else if supportedExtensions.contains(selection.pathExtension.lowercased()) {
                output.append(selection)
            }
        }

        var seen: Set<String> = []
        return output
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .filter { seen.insert($0.path.precomposedStringWithCanonicalMapping.lowercased()).inserted }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    public static func importFaces(
        from selections: [URL],
        projectURL: URL?,
        maximumFiles: Int = 10_000
    ) -> FontImportResult {
        let urls = fontURLs(from: selections, maximumFiles: maximumFiles)
        var records: [FontFaceRecord] = []
        var runtimes: [UUID: RuntimeFontFace] = [:]
        var failures: [FontImportFailure] = []

        for url in urls {
            if Task.isCancelled { break }
            guard CTFontManagerIsSupportedFont(url as CFURL) else {
                failures.append(.init(url: url, reason: "CoreText does not support this font payload."))
                continue
            }
            guard let rawDescriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) else {
                failures.append(.init(url: url, reason: "CoreText could not read this file."))
                continue
            }
            let descriptorCount = CFArrayGetCount(rawDescriptors)
            guard descriptorCount > 0 else {
                failures.append(.init(url: url, reason: "No font faces were found."))
                continue
            }

            // CTFontManagerCreateFontDescriptorsFromURL promises one CTFontDescriptor for
            // every face in the payload. The public API exposes no collection-index attribute,
            // so its stable array position is the face index we persist and later relink.
            for offset in 0..<descriptorCount {
                if Task.isCancelled { break }
                guard let pointer = CFArrayGetValueAtIndex(rawDescriptors, offset) else { continue }
                let descriptor = Unmanaged<CTFontDescriptor>.fromOpaque(pointer).takeUnretainedValue()
                let base = CTFontCreateWithFontDescriptor(descriptor, 64, nil)
                let faceIndex = offset
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                let family = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontFamilyNameAttribute),
                    fallback: CTFontCopyFamilyName(base) as String
                )
                let style = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontStyleNameAttribute),
                    fallback: (CTFontCopyName(base, kCTFontStyleNameKey) as String?) ?? "Regular"
                )
                let postScript = nonEmpty(
                    stringAttribute(descriptor, key: kCTFontNameAttribute),
                    fallback: CTFontCopyPostScriptName(base) as String
                )
                let axes = variationAxes(for: base)
                let features = featureGroups(for: base)
                let defaults = Dictionary(uniqueKeysWithValues: axes.map { ($0.identifier, $0.defaultValue) })
                let featureDefaults = Dictionary(uniqueKeysWithValues: features.compactMap { group in
                    group.options.first(where: \.isDefault).map { (group.typeIdentifier, $0.selectorIdentifier) }
                })

                let record = FontFaceRecord(
                    sourcePath: StudyPathResolver.storedPath(for: url, projectURL: projectURL),
                    faceIndex: faceIndex,
                    fileName: url.lastPathComponent,
                    familyName: family,
                    styleName: style,
                    postScriptName: postScript,
                    format: url.pathExtension.uppercased(),
                    fileSize: Int64(values?.fileSize ?? 0),
                    metrics: metrics(for: base, descriptor: descriptor),
                    coverage: coverage(for: base),
                    axes: axes,
                    axisValues: defaults,
                    featureGroups: features,
                    featureSelections: featureDefaults,
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

        return FontImportResult(
            records: records,
            runtimes: runtimes,
            failures: failures,
            scannedFileCount: urls.count
        )
    }

    public static func reload(
        record: FontFaceRecord,
        projectURL: URL?
    ) -> (FontFaceRecord, RuntimeFontFace)? {
        let url = StudyPathResolver.resolvedURL(for: record.sourcePath, projectURL: projectURL)
        let imported = importFaces(from: [url], projectURL: projectURL, maximumFiles: 1)
        guard let match = imported.records.first(where: { $0.faceIndex == record.faceIndex }),
              let runtime = imported.runtimes[match.id]
        else { return nil }

        var merged = match
        merged.id = record.id
        merged.casing = record.casing
        merged.status = record.status
        merged.role = record.role
        merged.tags = record.tags
        merged.notes = record.notes
        for axis in merged.axes {
            if let oldValue = record.axisValues[axis.identifier] {
                merged.axisValues[axis.identifier] = min(axis.maximum, max(axis.minimum, oldValue))
            }
        }
        for group in merged.featureGroups {
            if let oldValue = record.featureSelections[group.typeIdentifier],
               group.options.contains(where: { $0.selectorIdentifier == oldValue }) {
                merged.featureSelections[group.typeIdentifier] = oldValue
            }
        }
        return (
            merged,
            RuntimeFontFace(sourceURL: runtime.sourceURL, faceIndex: runtime.faceIndex, descriptor: runtime.descriptor)
        )
    }

    public static func firstSystemFontURL() -> URL? {
        let roots = [
            URL(fileURLWithPath: "/System/Library/Fonts", isDirectory: true),
            URL(fileURLWithPath: "/Library/Fonts", isDirectory: true),
        ]
        return fontURLs(from: roots, maximumFiles: 500).first(where: { CTFontManagerIsSupportedFont($0 as CFURL) })
    }

    private static func variationAxes(for font: CTFont) -> [FontAxis] {
        guard let raw = CTFontCopyVariationAxes(font) else { return [] }
        var axes: [FontAxis] = []
        for case let dictionary as NSDictionary in raw as NSArray {
            guard let identifier = (dictionary[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.uint32Value,
                  let minimum = (dictionary[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue,
                  let maximum = (dictionary[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue,
                  let defaultValue = (dictionary[kCTFontVariationAxisDefaultValueKey] as? NSNumber)?.doubleValue
            else { continue }
            let name = (dictionary[kCTFontVariationAxisNameKey] as? String) ?? axisTag(identifier)
            axes.append(.init(
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

    private static func featureGroups(for font: CTFont) -> [FontFeatureGroup] {
        guard let raw = CTFontCopyFeatures(font) else { return [] }
        var groups: [FontFeatureGroup] = []
        for case let dictionary as NSDictionary in raw as NSArray {
            guard let type = (dictionary[kCTFontFeatureTypeIdentifierKey] as? NSNumber)?.intValue else { continue }
            let name = (dictionary[kCTFontFeatureTypeNameKey] as? String) ?? "Feature \(type)"
            let exclusive = (dictionary[kCTFontFeatureTypeExclusiveKey] as? NSNumber)?.boolValue ?? false
            let rawSelectors = dictionary[kCTFontFeatureTypeSelectorsKey] as? NSArray ?? []
            let options: [FontFeatureOption] = rawSelectors.compactMap { rawSelector in
                guard let selector = rawSelector as? NSDictionary,
                      let identifier = (selector[kCTFontFeatureSelectorIdentifierKey] as? NSNumber)?.intValue
                else { return nil }
                return FontFeatureOption(
                    typeIdentifier: type,
                    selectorIdentifier: identifier,
                    name: (selector[kCTFontFeatureSelectorNameKey] as? String) ?? "Option \(identifier)",
                    isDefault: (selector[kCTFontFeatureSelectorDefaultKey] as? NSNumber)?.boolValue ?? false
                )
            }
            guard !options.isEmpty else { continue }
            groups.append(.init(typeIdentifier: type, name: name, isExclusive: exclusive, options: options))
        }
        return groups.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func metrics(for font: CTFont, descriptor: CTFontDescriptor) -> FontMetricsSnapshot {
        let rawTraits = CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute) as? NSDictionary
        let symbolic = CTFontGetSymbolicTraits(font)
        var names: [String] = []
        if symbolic.contains(.traitBold) { names.append("Bold") }
        if symbolic.contains(.traitItalic) { names.append("Italic") }
        if symbolic.contains(.traitExpanded) { names.append("Expanded") }
        if symbolic.contains(.traitCondensed) { names.append("Condensed") }
        if symbolic.contains(.traitMonoSpace) { names.append("Monospaced") }

        return .init(
            unitsPerEm: Int(CTFontGetUnitsPerEm(font)),
            glyphCount: Int(CTFontGetGlyphCount(font)),
            ascent: Double(CTFontGetAscent(font)),
            descent: Double(CTFontGetDescent(font)),
            leading: Double(CTFontGetLeading(font)),
            capHeight: Double(CTFontGetCapHeight(font)),
            xHeight: Double(CTFontGetXHeight(font)),
            slantAngle: Double(CTFontGetSlantAngle(font)),
            weightTrait: (rawTraits?[kCTFontWeightTrait] as? NSNumber)?.doubleValue ?? 0,
            widthTrait: (rawTraits?[kCTFontWidthTrait] as? NSNumber)?.doubleValue ?? 0,
            symbolicTraits: names
        )
    }

    private static func coverage(for font: CTFont) -> FontCoverageSnapshot {
        let characterSet = CTFontCopyCharacterSet(font) as CharacterSet
        var ratios: [String: Double] = [:]
        var supportedProbeScalars: Set<UInt32> = []
        for probe in PresetLibrary.coverageProbes {
            let scalars = probe.text.unicodeScalars.filter {
                !CharacterSet.whitespacesAndNewlines.contains($0)
                    && !CharacterSet.punctuationCharacters.contains($0)
            }
            guard !scalars.isEmpty else { continue }
            let supported = scalars.filter { characterSet.contains($0) }
            ratios[probe.name] = Double(supported.count) / Double(scalars.count)
            supported.forEach { supportedProbeScalars.insert($0.value) }
        }
        return .init(supportedScalarCount: supportedProbeScalars.count, scriptRatios: ratios)
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

    private static func nonEmpty(_ candidate: String?, fallback: String) -> String {
        let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? fallback : trimmed
    }
}
