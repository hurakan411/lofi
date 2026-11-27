import XCTest
import ImageIO
import AVFoundation
@testable import Lofi

final class EmberWorkshopTests: XCTestCase {
    func testApprovedAssetsPreserveSizesTimingAndLoop() throws {
        let bundle = Bundle(for: FocusStore.self)
        let cases = [(1,512,768,250,10.0),(2,512,768,250,10.0),
                     (3,600,656,300,12.0),(4,600,656,300,12.0),(5,512,768,1440,72.0)]
        for (rank, width, height, count, duration) in cases {
            let url = try XCTUnwrap(bundle.url(forResource: FocusWorld.emberWorkshop.resource(for: rank), withExtension: "gif"))
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary))
            XCTAssertEqual(CGImageSourceGetCount(source), count)
            let properties = try XCTUnwrap(CGImageSourceCopyProperties(source, nil) as? [CFString: Any])
            XCTAssertEqual((properties[kCGImagePropertyGIFDictionary] as? [CFString: Any])?[kCGImagePropertyGIFLoopCount] as? Int, 0)
            var seconds = 0.0
            for index in 0..<count {
                let props = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any])
                XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, width)
                XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, height)
                let gif = try XCTUnwrap(props[kCGImagePropertyGIFDictionary] as? [CFString: Any])
                seconds += try XCTUnwrap((gif[kCGImagePropertyGIFUnclampedDelayTime] ?? gif[kCGImagePropertyGIFDelayTime]) as? Double)
            }
            XCTAssertEqual(seconds, duration, accuracy: 0.001)
            XCTAssertEqual(FocusWorld.emberWorkshop.artworkSize(for: rank), CGSize(width: width, height: height))
            XCTAssertNotNil(CGImageSourceCreateImageAtIndex(source, count-1, nil))
        }
    }

    @MainActor func testIndependentGrowthAudioGatingAndPersistence() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertTrue(store.useWorld(.emberWorkshop))
        store.setConfirmation(.everySession)
        let start = Date(timeIntervalSince1970: 1000)
        let sequence: [SoundKind] = [.embers, .bellows, .hammer, .grinder, .clockwork]
        for rank in 1...5 {
            for (index, sound) in sequence.enumerated() {
                XCTAssertEqual(store.isSoundUnlocked(sound), index < rank)
            }
            guard rank < 5 else { break }
            store.start(at: start)
            XCTAssertFalse(store.useWorld(.shellHarbor))
            store.requestFinish(at: start.addingTimeInterval(1500))
            store.commit(deducting: 0, at: start.addingTimeInterval(1500))
            XCTAssertEqual(store.result?.world, .emberWorkshop)
            XCTAssertNil(store.result?.world.story)
        }
        XCTAssertNil(store.collectionEntries.first { $0.world == .emberWorkshop }?.story)
        for world in [FocusWorld.rooftop, .shrine, .shellHarbor] {
            XCTAssertEqual(store.data.progress(for: world).rank, 1)
        }
        store.setVolume(0.27, for: .clockwork)
        store.showRank(3)
        let restored = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertEqual(restored.activeWorld, .emberWorkshop)
        XCTAssertEqual(restored.rank, 5)
        XCTAssertEqual(restored.displayedRank, 3)
        restored.showRank(5)
        XCTAssertEqual(restored.soundVolume(.clockwork), 0.27)
        XCTAssertEqual(restored.data.records.count, 4)
    }

    @MainActor func testBackgroundPlaybackPreferenceStopsAndResumesAudio() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FocusStore(persistenceURL: url, startTimer: false)
        XCTAssertTrue(store.backgroundPlaybackEnabled)
        store.setBackgroundPlaybackEnabled(false)
        XCTAssertFalse(store.audio.playingSounds.isEmpty)
        store.setAppInBackground(true)
        XCTAssertTrue(store.audio.playingSounds.isEmpty)
        store.audio.playChime()
        XCTAssertFalse(store.audio.isAudioPlaying)
        store.syncAudio()
        XCTAssertTrue(store.audio.playingSounds.isEmpty)
        store.setAppInBackground(false)
        XCTAssertFalse(store.audio.playingSounds.isEmpty)
        store.previewCollectionAudio(rank: 1, world: .shrine)
        store.setAppInBackground(true)
        XCTAssertTrue(store.audio.playingSounds.isEmpty)
        store.setBackgroundPlaybackEnabled(true)
        XCTAssertFalse(store.audio.playingSounds.isEmpty)
        XCTAssertEqual(store.audioWorld, .shrine)
        store.setBackgroundPlaybackEnabled(false)
        XCTAssertFalse(FocusStore(persistenceURL: url, startTimer: false).backgroundPlaybackEnabled)
        store.audio.stopAll()
    }

    @MainActor func testCollectionAudioReplacesWorkPlayback() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = FocusStore(persistenceURL: url, startTimer: false, debugUnlockAllRanks: true)
        XCTAssertTrue(store.useWorld(.emberWorkshop, rank: 5))
        XCTAssertTrue(store.audio.playingSounds.contains(.clockwork))
        store.previewCollectionAudio(rank: 1, world: .shrine)
        XCTAssertFalse(store.audio.playingSounds.contains(.clockwork))
        XCTAssertTrue(store.audio.playingSounds.isSubset(of: Set(FocusWorld.shrine.sounds)))
        store.syncAudio()
        XCTAssertFalse(store.audio.playingSounds.contains(.clockwork))
        store.silenceCollectionAudio()
        store.syncAudio()
        XCTAssertTrue(store.audio.playingSounds.isEmpty)
        store.endCollectionAudioPreview()
        XCTAssertTrue(store.audio.playingSounds.contains(.clockwork))
        XCTAssertNil(store.collectionAudioWorld)
        store.audio.stopAll()
    }

    @MainActor func testAllWorkshopAudioResourcesAndPlayback() throws {
        let bundle = Bundle(for: FocusStore.self)
        for sound in FocusWorld.emberWorkshop.sounds {
            let url = try XCTUnwrap(bundle.url(forResource: sound.rawValue, withExtension: "wav"))
            let player = try AVAudioPlayer(contentsOf: url)
            XCTAssertGreaterThan(player.duration, 4)
        }
        let audio = SoundscapePlayer()
        for rank in 1...5 {
            XCTAssertNoThrow(try audio.update(mix: SoundMix(), rank: rank, world: .emberWorkshop))
        }
        var silent = SoundMix()
        for sound in SoundKind.allCases { silent.enabled[sound.rawValue] = false }
        try audio.update(mix: silent, rank: 5, world: .emberWorkshop)
        XCTAssertFalse(audio.isAudioPlaying)
    }
}
