import XCTest
import ImageIO
@testable import Lofi

final class ShellHarborTests: XCTestCase {
    func testApprovedAnimationsKeepTheirDimensionsDurationAndLoop() throws {
        let bundle = Bundle(for: FocusStore.self)
        for (rank, seconds) in [(1, 12), (2, 16), (3, 16), (4, 16), (5, 24)] {
            let url = try XCTUnwrap(bundle.url(forResource: FocusWorld.shellHarbor.resource(for: rank), withExtension: "gif"))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary))
            XCTAssertEqual(CGImageSourceGetCount(source), seconds * 25)
            let metadata = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
            let gif = try XCTUnwrap(metadata[kCGImagePropertyGIFDictionary] as? [CFString: Any])
            XCTAssertEqual(gif[kCGImagePropertyGIFLoopCount] as? Int, 0)
            var duration = 0.0
            for index in 0..<CGImageSourceGetCount(source) {
                let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
                XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 642)
                XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 882)
                let frame = try XCTUnwrap(properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])
                duration += try XCTUnwrap((frame[kCGImagePropertyGIFUnclampedDelayTime] ?? frame[kCGImagePropertyGIFDelayTime]) as? Double)
            }
            XCTAssertEqual(duration, Double(seconds), accuracy: 0.001)
            XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source, CGImageSourceGetCount(source) - 1, nil))
        }
    }

    @MainActor func testGrowthPersistenceAndStorylessResults() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        store.setConfirmation(.everySession)
        XCTAssertTrue(store.useWorld(.shellHarbor))
        let start = Date(timeIntervalSince1970: 1000)
        for rank in 2...5 {
            store.start(at: start)
            XCTAssertFalse(store.useWorld(.rooftop))
            store.requestFinish(at: start.addingTimeInterval(1500))
            store.commit(deducting: 0, at: start.addingTimeInterval(1500))
            XCTAssertEqual(store.rank, rank)
            XCTAssertEqual(store.result?.world, .shellHarbor)
            XCTAssertNil(store.result?.world.story)
        }
        XCTAssertNil(store.collectionEntries.first { $0.world == .shellHarbor }?.story)
        XCTAssertEqual(store.data.progress(for: .rooftop).rank, 1)
        XCTAssertEqual(store.data.progress(for: .shrine).rank, 1)
        store.showRank(2)
        let restored = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertEqual(restored.activeWorld, .shellHarbor)
        XCTAssertEqual(restored.rank, 5)
        XCTAssertEqual(restored.displayedRank, 2)
        XCTAssertEqual(restored.data.records.count, 4)
    }
}
