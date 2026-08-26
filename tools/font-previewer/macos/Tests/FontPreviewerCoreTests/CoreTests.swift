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

    func testCasingPreservesOuterPunctuation() {
        XCTAssertEqual(
            SpecimenTextTransform.apply(.title, to: "“hello, world.”"),
            "“Hello, World.”"
        )
        XCTAssertEqual(
            SpecimenTextTransform.apply(.uppercase, to: "₹4.8m projected"),
            "₹4.8M PROJECTED"
        )
    }

    func testFilterSearchesMetadataTagsAndNotes() {
        var record = fixture(name: "Recoleta", style: "Medium")
        record.tags = ["warm", "editorial"]
        record.notes = "Good for intimate family drama"

        XCTAssertTrue(StudyFilter(query: "recoleta").matches(record))
        XCTAssertTrue(StudyFilter(query: "EDITORIAL").matches(record))
        XCTAssertTrue(StudyFilter(query: "family drama").matches(record))
        XCTAssertFalse(StudyFilter(query: "grotesk").matches(record))
    }

    func testFilterRespectsStatus() {
        let keep = fixture(name: "Keep", status: .keep)
        let maybe = fixture(name: "Maybe", status: .maybe)
        let filter = StudyFilter(statuses: [.keep])
        XCTAssertEqual(filter.apply(to: [keep, maybe]).map { $0.id }, [keep.id])
    }

    func testMovePreservesRecordIdentity() {
        var records = [fixture(name: "A"), fixture(name: "B"), fixture(name: "C")]
        let movingID = records[0].id
        let destinationID = records[2].id
        StudyLogic.move(recordID: movingID, before: destinationID, in: &records)
        XCTAssertEqual(records.map { $0.familyName }, ["B", "A", "C"])
        XCTAssertEqual(records[1].id, movingID)
    }

    func testDuplicateIdentityUsesPathAndFaceIndexNotPostScriptName() {
        let path = "/tmp/Test.ttc"
        var first = fixture(name: "First", sourcePath: path, faceIndex: 0)
        var second = fixture(name: "Second", sourcePath: path, faceIndex: 1)
        first.postScriptName = "Collision"
        second.postScriptName = "Collision"

        XCTAssertNotEqual(FontIdentity.key(for: first), FontIdentity.key(for: second))
        XCTAssertEqual(FontIdentity.removingDuplicates([first, first, second]).count, 2)
    }

    func testProjectRoundTripPreservesSemanticContent() throws {
        let study = FontStudy(
            title: "Deck Type Study",
            sampleText: "Your hundredth read. Our first.",
            samplePreset: .custom,
            specimenKind: .display,
            background: .split,
            layout: .fourUp,
            records: [fixture(name: "Recoleta")]
        )
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(study))
        XCTAssertEqual(StudySemanticSnapshot(decoded), StudySemanticSnapshot(study))
    }

    func testProjectRoundTripPreservesFractionalDates() throws {
        let date = Date(timeIntervalSince1970: 1_782_345_678.123)
        let study = FontStudy(createdAt: date, updatedAt: date)
        let decoded = try ProjectCodec.decode(ProjectCodec.encode(study))
        XCTAssertEqual(decoded.createdAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.updatedAt.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 0.001)
    }

    func testRejectsFutureSchema() throws {
        var study = FontStudy()
        study.schemaVersion = FontStudy.currentSchemaVersion + 1
        XCTAssertThrowsError(try ProjectCodec.decode(ProjectCodec.encode(study))) { error in
            XCTAssertEqual(error as? ProjectCodecError, .unsupportedSchema(study.schemaVersion))
        }
    }

    func testRelativePathsResolveAgainstProject() {
        let project = URL(fileURLWithPath: "/Users/test/Work/Study.pitchfontstudy")
        let source = URL(fileURLWithPath: "/Users/test/Work/Fonts/Family.otf")
        let stored = StudyPathResolver.storedPath(for: source, projectURL: project)
        XCTAssertEqual(stored, "Fonts/Family.otf")
        XCTAssertEqual(
            StudyPathResolver.resolvedURL(for: stored, projectURL: project).path,
            source.path
        )
    }

    func testAbsolutePathRemainsAbsoluteWhenNoUsefulCommonRoot() {
        let project = URL(fileURLWithPath: "/Users/test/Study.pitchfontstudy")
        let source = URL(fileURLWithPath: "/Volumes/Archive/Family.otf")
        XCTAssertEqual(
            StudyPathResolver.storedPath(for: source, projectURL: project),
            source.path
        )
    }

    func testFourUpPaginationNeverLosesIDs() {
        let records = (0..<9).map { fixture(name: "Font \($0)") }
        let pages = StudyExportPlanner.pages(for: records, layout: .fourUp)
        XCTAssertEqual(pages.map { $0.records.count }, [4, 4, 1])
        XCTAssertEqual(pages.flatMap { $0.records }.map { $0.id }, records.map { $0.id })
    }

    func testSlugAndExtensionlessCollisionNaming() throws {
        XCTAssertEqual(StudyExportPlanner.slug("A Very Motherly Christmas!"), "a-very-motherly-christmas")
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

    func testPresetKindsMatchDeckUsage() {
        XCTAssertEqual(PresetLibrary.kind(for: .titleSlide), .display)
        XCTAssertEqual(PresetLibrary.kind(for: .logline), .paragraph)
        XCTAssertEqual(PresetLibrary.kind(for: .dataLabel), .data)
        XCTAssertEqual(PresetLibrary.kind(for: .legal), .micro)
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
