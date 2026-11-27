import XCTest
import ImageIO
import AVFoundation
@testable import Lofi

final class FocusTests: XCTestCase {
    func testSessionExcludesPausedTimeAndSurvivesEncoding() throws {
        let start = Date(timeIntervalSince1970: 1000)
        var session = FocusSession(now: start, interval: 1800)
        session.pause(at: start.addingTimeInterval(120))
        XCTAssertEqual(session.elapsed(at: start.addingTimeInterval(900)), 120)
        session = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        session.resume(at: start.addingTimeInterval(1000))
        XCTAssertEqual(session.elapsed(at: start.addingTimeInterval(1060)), 180)
    }
    func testRankThresholdsAndPreviewAreBounded() {
        XCTAssertEqual(RooftopWorld.rank(for: -10), 1)
        XCTAssertEqual(RooftopWorld.rank(for: 1499), 1)
        XCTAssertEqual(RooftopWorld.rank(for: 1500), 2)
        XCTAssertEqual(RooftopWorld.rank(for: 6000), 5)
        XCTAssertEqual(RooftopWorld.rank(for: 100000), 5)
        XCTAssertEqual(RooftopWorld.progress(for: 9000, rank: 2), 1)
        XCTAssertEqual(RooftopWorld.remaining(for: 1500, rank: 2), 1500)
    }
    func testReviewPolicy() {
        XCTAssertFalse(ConfirmationMode.light.needsReview(seconds: 3599))
        XCTAssertTrue(ConfirmationMode.light.needsReview(seconds: 3600))
        XCTAssertTrue(ConfirmationMode.everySession.needsReview(seconds: 1))
        XCTAssertFalse(ConfirmationMode.none.needsReview(seconds: 100000))
    }
    @MainActor func testCorrectionCreditsSameTimeToRecordAndGrowthExactlyOnce() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        store.setConfirmation(.everySession)
        let start = Date(timeIntervalSince1970: 1000)
        store.start(at: start)
        store.requestFinish(at: start.addingTimeInterval(1800))
        XCTAssertTrue(store.needsReview)
        store.commit(deducting: 600, at: start.addingTimeInterval(1900))
        XCTAssertEqual(store.data.records.count, 1)
        XCTAssertEqual(store.data.records[0].seconds, 1200)
        XCTAssertEqual(store.data.growthSeconds, 1200)
        XCTAssertEqual(store.rank, 1)
        store.commit(deducting: 0)
        XCTAssertEqual(store.data.records.count, 1)
        let restored = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertEqual(restored.data.growthSeconds, 1200)
        XCTAssertEqual(restored.data.records.count, 1)
    }
    @MainActor func testDiscardDoesNotGrowScene() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        store.setConfirmation(.everySession)
        let start = Date(timeIntervalSince1970: 1000)
        store.start(at: start)
        store.requestFinish(at: start.addingTimeInterval(1800))
        store.discardSession()
        XCTAssertNil(store.data.session)
        XCTAssertTrue(store.data.records.isEmpty)
        XCTAssertEqual(store.data.growthSeconds, 0)
    }
    func testApprovedShrineAnimationsAreBundledInEveryRank() throws {
        let bundle = Bundle(for: FocusStore.self)
        for rank in 1...5 {
            let url = try XCTUnwrap(bundle.url(forResource: FocusWorld.shrine.resource(for: rank), withExtension: "gif"))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary))
            let count = CGImageSourceGetCount(source)
            XCTAssertEqual(count, rank == 1 ? 240 : 2400)
            for index in [0, count - 1] {
                let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
                XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 600)
                XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1300)
            }
        }
    }
    @MainActor func testShrineSoundResourcesAndPlayback() throws {
        let bundle = Bundle(for: FocusStore.self)
        for sound in FocusWorld.shrine.sounds {
            let url = try XCTUnwrap(bundle.url(forResource: sound.rawValue, withExtension: "wav"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 0)
        }
        let audio = SoundscapePlayer()
        for rank in 1...5 { XCTAssertNoThrow(try audio.update(mix: SoundMix(), rank: rank, world: .shrine)) }
        var silent = SoundMix()
        for sound in SoundKind.allCases { silent.enabled[sound.rawValue] = false }
        XCTAssertNoThrow(try audio.update(mix: silent, rank: 1, world: .rooftop))
        XCTAssertFalse(audio.isMusicPlaying)
    }
    @MainActor func testShrineGrowthDoesNotUnlockRooftopOrFutureChapters() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        store.setConfirmation(.everySession)
        XCTAssertTrue(store.useWorld(.shrine))
        let start = Date(timeIntervalSince1970: 1000)
        store.start(at: start)
        XCTAssertFalse(store.useWorld(.rooftop))
        store.requestFinish(at: start.addingTimeInterval(1500))
        store.commit(deducting: 0, at: start.addingTimeInterval(1500))
        XCTAssertEqual(store.rank, 2)
        XCTAssertEqual(store.data.progress(for: .rooftop).rank, 1)
        XCTAssertEqual(store.data.records.last?.worldID, FocusWorld.shrine.id)
        XCTAssertEqual(store.result?.world.story, .shrine)
        XCTAssertNil(CollectionStory.shrine.chapter(at: 3, unlockedRank: store.rank))
        let restored = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertEqual(restored.activeWorld, .shrine)
        XCTAssertEqual(restored.rank, 2)
    }

    @MainActor func testRapidRankChangesLoadOnlyTheLatestSceneWithoutBlocking() throws {
        let surface = GIFSurface()
        surface.setPlaying(false)
        defer { surface.stop() }
        let began = Date()
        surface.setResource(FocusWorld.shrine.resource(for: 5))
        surface.setResource(FocusWorld.shrine.resource(for: 2))
        surface.setResource(FocusWorld.shrine.resource(for: 1))
        XCTAssertLessThan(Date().timeIntervalSince(began), 0.2, "Long GIF metadata must not block the main thread")
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in surface.layer.contents != nil }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 10), .completed)
        let contents = try XCTUnwrap(surface.layer.contents)
        let actual = contents as! CGImage
        let url = try XCTUnwrap(Bundle(for: FocusStore.self).url(forResource: "shrine-rank-1", withExtension: "gif"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let expected = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let actualBytes = try XCTUnwrap(actual.dataProvider?.data) as Data
        let expectedBytes = try XCTUnwrap(expected.dataProvider?.data) as Data
        XCTAssertEqual(actualBytes, expectedBytes, "Cancelled rank 5/2 loads must never replace the latest rank 1 request")
    }

}
