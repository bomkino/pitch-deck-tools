import XCTest
@testable import FontPreviewerCore

final class CoreTests: XCTestCase {
    func testAPTitleCaseKeepsMinorWordsLowercaseAwayFromEdges() {
        XCTAssertEqual(
            SpecimenTextTransform.apply(.apTitle, to: "the shape of a story in motion"),
            "The Shape of a Story in Motion"
        )
        XCTAssertEqual(
            SpecimenTextTransform.apply(.apTitle, to: "from here to"),
            "From Here To"
        )
    }

    func testTitleCaseHandlesHyphensApostrophesAndPunctuation() {
        XCTAssertEqual(
            SpecimenTextTransform.apply(.title, to: "“mother-in-law's second act.”"),
            "“Mother-In-Law's Second Act.”"
        )
        XCTAssertEqual(
            SpecimenTextTransform.apply(.uppercase, to: "₹4.8m projected"),
            "₹4.8M PROJECTED"
        )
    }

    func testFilterSearchesMetadataTagsNotesAxesAndScripts() {
        var record = fixture(name: "Recoleta", style: "Medium")
        record.tags = ["warm", "editorial"]
        record.notes = "Good for intimate family drama"
        record.axes = [.init(identifier: 1, tag: "wght", name: "Weight", minimum: 100, maximum: 900, defaultValue: 400)]
        record.coverage = .init(scriptRatios: ["Latin": 1, "Greek": 0.8])

        XCTAssertTrue(StudyFilter(query: "recoleta").matches(record))
        XCTAssertTrue(StudyFilter(query: "tag:EDITORIAL").matches(record))
        XCTAssertTrue(StudyFilter(query: "family drama").matches(record))
        XCTAssertTrue(StudyFilter(query: "variable:true script:greek").matches(record))
        XCTAssertFalse(StudyFilter(query: "format:ttf").matches(record))
    }

    func testFilterRespectsStatusRoleFormatAndMissingSource() {
        var keep = fixture(name: "Keep", status: .keep)
        keep.role = .display
        keep.format = "OTF"
        var maybe = fixture(name: "Maybe", status: .maybe)
        maybe.role = .body
        maybe.format = "TTF"

        let filter = StudyFilter(
            statuses: [.keep],
            roles: [.display],
            formats: ["otf"],
            missingSourceOnly: true
        )
        XCTAssertEqual(
            filter.apply(to: [keep, maybe], sourceExists: { _ in false }).map(\.id),
            [keep.id]
        )
    }

    func testSortKeepsManualOrderAndSupportsStatusRanking() {
        let reject = fixture(name: "A", status: .reject)
        let keep = fixture(name: "Z", status: .keep)
        let maybe = fixture(name: "B", status: .maybe)
        XCTAssertEqual(StudyFilter(sort: .manual).apply(to: [reject, keep, maybe]).map(\.id), [reject.id, keep.id, maybe.id])
        XCTAssertEqual(StudyFilter(sort: .status).apply(to: [reject, keep, maybe]).map(\.id), [keep.id, maybe.id, reject.id])
    }

    func testMovePreservesRecordIdentity() {
        var records = [fixture(name: "A"), fixture(name: "B"), fixture(name: "C")]
        let movingID = records[0].id
        StudyLogic.move(recordID: movingID, before: records[2].id, in: &records)
        XCTAssertEqual(records.map(\.familyName), ["B", "A", "C"])
        StudyLogic.move(recordID: movingID, offset: 1, in: &records)
        XCTAssertEqual(records.map(\.familyName), ["B", "C", "A"])
    }

    func testDuplicateIdentityUsesResolvedPathAndFaceIndexNotPostScriptName() {
        let project = URL(fileURLWithPath: "/Users/test/Work/Study.pitchfontstudy")
        var first = fixture(name: "First", sourcePath: "Fonts/Test.ttc", faceIndex: 0)
        var duplicate = first
        duplicate.id = UUID()
        duplicate.sourcePath = "/Users/test/Work/Fonts/Test.ttc"
        var second = fixture(name: "Second", sourcePath: "Fonts/Test.ttc", faceIndex: 1)
        first.postScriptName = "Collision"
        duplicate.postScriptName = "Collision"
        second.postScriptName = "Collision"

        XCTAssertEqual(FontIdentity.key(for: first, projectURL: project), FontIdentity.key(for: duplicate, projectURL: project))
        XCTAssertNotEqual(FontIdentity.key(for: first, projectURL: project), FontIdentity.key(for: second, projectURL: project))
        XCTAssertEqual(FontIdentity.removingDuplicates([first, duplicate, second], projectURL: project).count, 2)
    }

    func testProjectRoundTripPreservesSemanticContentAndFractionalDates() throws {
        let date = Date(timeIntervalSince1970: 1_782_345_678.123)
        var record = fixture(name: "Recoleta")
        record.role = .display
        record.featureSelections = [1: 2]
        let study = FontStudy(
            title: "Deck Type Study",
            sampleText: "Your hundredth read. Our first.",
            samplePreset: .custom,
            specimenKind: .display,
            background: .split,
            layout: .compare,
            alignment: .center,
            tracking: -0.02,
            lineHeight: 1.15,
            showMetadata: false,
            showGuides: true,
            comparisonIDs: [record.id],
            pairingHeadingID: record.id,
            records: [record],
            createdAt: date,
            updatedAt: date
        )
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(study))
        XCTAssertEqual(StudySemanticSnapshot(decoded), StudySemanticSnapshot(study))
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testSchemaTwoProjectMigratesWithNewDefaults() throws {
        let old = """
        {
          "schemaVersion": 2,
          "id": "00000000-0000-0000-0000-000000000001",
          "title": "Old study",
          "sampleText": "Old text",
          "samplePreset": "custom",
          "specimenKind": "display",
          "background": "dark",
          "layout": "fourUp",
          "records": [{
            "id": "00000000-0000-0000-0000-000000000002",
            "sourcePath": "/tmp/Test.otf",
            "faceIndex": 0,
            "fileName": "Test.otf",
            "familyName": "Test",
            "styleName": "Regular",
            "postScriptName": "Test-Regular",
            "format": "OTF",
            "axes": [],
            "axisValues": {},
            "casing": "exact",
            "status": "maybe",
            "tags": [],
            "notes": ""
          }],
          "createdAt": "2026-08-26T00:00:00Z",
          "updatedAt": "2026-08-26T00:00:00Z"
        }
        """
        let decoded = try ProjectCodec.decode(Data(old.utf8))
        XCTAssertEqual(decoded.schemaVersion, 3)
        XCTAssertEqual(decoded.layout, .compare)
        XCTAssertEqual(decoded.records[0].role, .unassigned)
        XCTAssertEqual(decoded.alignment, .leading)
        XCTAssertTrue(decoded.showMetadata)
    }

    func testRejectsFutureSchemaAndEmptySource() throws {
        var study = FontStudy()
        study.schemaVersion = FontStudy.currentSchemaVersion + 1
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(study))) { error in
            XCTAssertEqual(error as? ProjectCodecError, .unsupportedSchema(study.schemaVersion))
        }

        var empty = FontStudy(records: [fixture(name: "Broken", sourcePath: "")])
        empty.schemaVersion = FontStudy.currentSchemaVersion
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(empty))) { error in
            XCTAssertEqual(error as? ProjectCodecError, .emptySourcePath)
        }
    }

    func testRelativePathsResolveAndRelinkWithoutLosingReviewData() {
        let project = URL(fileURLWithPath: "/Users/test/Work/Study.pitchfontstudy")
        let source = URL(fileURLWithPath: "/Users/test/Work/Fonts/Family.otf")
        let stored = StudyPathResolver.storedPath(for: source, projectURL: project)
        XCTAssertEqual(stored, "Fonts/Family.otf")
        XCTAssertEqual(StudyPathResolver.resolvedURL(for: stored, projectURL: project).path, source.path)

        var record = fixture(name: "Old")
        record.status = .keep
        record.notes = "Strong title face"
        let replacement = StudyPathResolver.replacingSource(in: record, with: source, projectURL: project)
        XCTAssertEqual(replacement.status, .keep)
        XCTAssertEqual(replacement.notes, "Strong title face")
        XCTAssertEqual(replacement.sourcePath, "Fonts/Family.otf")
    }

    func testPaginationAndCanvasPresets() {
        let records = (0..<9).map { fixture(name: "Font \($0)") }
        XCTAssertEqual(StudyExportPlanner.pages(for: records, mode: .compare).map { $0.records.count }, [4, 4, 1])
        XCTAssertEqual(StudyExportPlanner.pages(for: records, mode: .metrics).count, 9)
        XCTAssertEqual(CanvasPreset.cinema.width, 2_576)
        XCTAssertEqual(CanvasPreset.cinema.height, 1_080)
        XCTAssertEqual(CanvasPreset.retinaCinema.width, 5_152)
    }

    func testSlugAndExtensionlessCollisionNaming() throws {
        XCTAssertEqual(StudyExportPlanner.slug("Crème & Light!"), "creme-light")
        XCTAssertEqual(
            StudyExportPlanner.boardFileName(studyTitle: "Type Test", pageIndex: 7, extension: "PNG"),
            "type-test-007.png"
        )

        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let desired = root.appendingPathComponent("manifest")
        FileManager.default.createFile(atPath: desired.path, contents: Data())
        XCTAssertEqual(StudyExportPlanner.uniqueURL(for: desired).lastPathComponent, "manifest-2")
    }

    func testHandoffOmitsAbsolutePathsByDefaultAndIncludesUsefulDetails() throws {
        var record = fixture(name: "Signal")
        record.status = .keep
        record.role = .display
        record.tags = ["Cinematic", "cinematic", "warm"]
        record.axes = [.init(identifier: 1, tag: "wght", name: "Weight", minimum: 100, maximum: 900, defaultValue: 400)]
        record.axisValues = [1: 650]
        record.featureGroups = [
            .init(typeIdentifier: 3, name: "Ligatures", isExclusive: false, options: [
                .init(typeIdentifier: 3, selectorIdentifier: 1, name: "Common ligatures")
            ])
        ]
        record.featureSelections = [3: 1]
        let study = FontStudy(title: "Signal Study", records: [record])

        let privateManifest = HandoffBuilder.manifest(
            study: study,
            records: [record],
            projectURL: nil,
            includeAbsoluteSourcePaths: false
        )
        XCTAssertNil(privateManifest.fonts[0].sourcePath)
        XCTAssertEqual(privateManifest.fonts[0].tags, ["cinematic", "warm"])
        XCTAssertEqual(privateManifest.fonts[0].axes[0].value, 650)
        XCTAssertEqual(privateManifest.fonts[0].enabledFeatures, ["Ligatures: Common ligatures"])
        XCTAssertFalse(HandoffBuilder.markdown(privateManifest).contains("/tmp/Signal.otf"))

        let explicitManifest = HandoffBuilder.manifest(
            study: study,
            records: [record],
            projectURL: nil,
            includeAbsoluteSourcePaths: true
        )
        XCTAssertEqual(explicitManifest.fonts[0].sourcePath, "/tmp/Signal.otf")
        XCTAssertGreaterThan(try HandoffBuilder.encodeJSON(explicitManifest).count, 100)
    }

    func testPresetLibraryIsDeckSpecificButClientNeutral() {
        XCTAssertEqual(PresetLibrary.kind(for: .titleSlide), .display)
        XCTAssertEqual(PresetLibrary.kind(for: .paragraph), .paragraph)
        XCTAssertEqual(PresetLibrary.kind(for: .numerals), .data)
        XCTAssertEqual(PresetLibrary.kind(for: .legal), .micro)
        XCTAssertFalse(PresetLibrary.text(for: .titleSlide).contains("Motherly"))
        XCTAssertGreaterThanOrEqual(PresetLibrary.coverageProbes.count, 8)
    }

    func testComparisonAndPairingFallbacks() {
        var display = fixture(name: "Display", status: .keep)
        display.role = .display
        var body = fixture(name: "Body", status: .maybe)
        body.role = .body
        let rejected = fixture(name: "Rejected", status: .reject)
        let study = FontStudy(comparisonIDs: [body.id, display.id], records: [display, body, rejected])
        XCTAssertEqual(StudyLogic.comparisonRecords(in: study).map(\.id), [body.id, display.id])
        let pair = StudyLogic.pairingRecords(in: study)
        XCTAssertEqual(pair.heading?.id, display.id)
        XCTAssertEqual(pair.body?.id, body.id)
    }

    private func fixture(
        name: String,
        style: String = "Regular",
        sourcePath: String? = nil,
        faceIndex: Int = 0,
        status: ReviewStatus = .maybe
    ) -> FontFaceRecord {
        FontFaceRecord(
            sourcePath: sourcePath ?? "/tmp/\(name).otf",
            faceIndex: faceIndex,
            fileName: "\(name).otf",
            familyName: name,
            styleName: style,
            postScriptName: "\(name)-\(style)",
            format: "OTF",
            status: status
        )
    }
}
