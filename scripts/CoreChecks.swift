import Foundation

// Same FocusStore/FocusModels as the app, with only the hardware audio output replaced.
@MainActor final class SoundscapePlayer {
    private(set) var lastRank: Int?
    private(set) var lastMix: SoundMix?
    private(set) var lastWorld: FocusWorld?
    private(set) var stopCount = 0
    private var playbackAllowed = true
    func setPlaybackAllowed(_ allowed: Bool) {
        if playbackAllowed != allowed { playbackAllowed = allowed; if !allowed { stopAll() } }
    }
    func stopAll() { stopCount += 1; lastMix = nil; lastRank = nil; lastWorld = nil }
    func update(mix: SoundMix, rank: Int, world: FocusWorld = .rooftop) throws {
        lastWorld = world
        lastRank = rank
        lastMix = mix
    }
}
@main struct CoreChecks {
    @MainActor static func main() throws {
        var passed = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }
            passed += 1
            print("PASS: \(name)")
        }
        #if DEBUG
        let unlocked = FocusStore(persistenceURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), startTimer: false, debugUnlockAllRanks: true)
        for world in FocusWorld.allCases {
            check(unlocked.useWorld(world, rank: 5) && unlocked.rank == 1 && unlocked.displayedRank == 5, "debug rank 5 preview keeps earned progress at rank 1")
            unlocked.previewCollectionAudio(rank: 5, world: world)
            check(unlocked.audioRank == 5 && world.sounds.allSatisfy { unlocked.isSoundUnlocked($0) }, "debug rank 5 audio is unlocked")
            unlocked.endCollectionAudioPreview()
        }
        check(unlocked.collectionEntries.filter { !$0.isSample }.allSatisfy { $0.rank == 5 }, "debug collections unlock every stage")
        check(unlocked.data.records.isEmpty && FocusWorld.allCases.allSatisfy { unlocked.data.progress(for: $0).growthSeconds == 0 }, "debug unlock never fabricates work records or growth")
        #endif
        let audioRouting = FocusStore(persistenceURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), startTimer: false)
        audioRouting.syncAudio()
        let stops = audioRouting.audio.stopCount
        audioRouting.previewCollectionAudio(rank: 1, world: .shrine)
        check(audioRouting.audio.stopCount == stops + 1 && audioRouting.audio.lastWorld == .shrine, "collection stops work playback before preview")
        audioRouting.syncAudio()
        check(audioRouting.audio.lastWorld == .shrine, "background resync keeps collection audio ownership")
        audioRouting.silenceCollectionAudio()
        audioRouting.syncAudio()
        check(audioRouting.audio.lastWorld == nil, "sample collections do not fall back to work audio")
        audioRouting.endCollectionAudioPreview()
        check(audioRouting.audio.lastWorld == .rooftop && audioRouting.collectionAudioWorld == nil, "dismissal restores work playback")
        let backgroundURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let background = FocusStore(persistenceURL: backgroundURL, startTimer: false)
        check(background.backgroundPlaybackEnabled, "existing saves default to background playback on")
        background.setBackgroundPlaybackEnabled(false)
        background.previewCollectionAudio(rank: 1, world: .shrine)
        background.setAppInBackground(true)
        check(background.audio.lastWorld == nil, "background playback off stops collection audio")
        background.syncAudio()
        check(background.audio.lastWorld == nil, "resync does not restart background audio")
        background.setAppInBackground(false)
        check(background.audio.lastWorld == .shrine, "foreground resumes the open collection audio")
        background.endCollectionAudioPreview()
        background.setAppInBackground(true)
        check(background.audio.lastWorld == nil, "background playback off stops work audio")
        background.setBackgroundPlaybackEnabled(true)
        check(background.audio.lastWorld == .rooftop, "background playback on permits work audio")
        background.setBackgroundPlaybackEnabled(false)
        let backgroundRestored = FocusStore(persistenceURL: backgroundURL, startTimer: false)
        check(!backgroundRestored.backgroundPlaybackEnabled, "background preference survives reopening")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Lofi-Checks-\(UUID().uuidString)")
        let start = Date(timeIntervalSince1970: 1000)
        var session = FocusSession(now: start, interval: 1800)
        session.pause(at: start.addingTimeInterval(120))
        check(session.elapsed(at: start.addingTimeInterval(900)) == 120, "paused time excluded")
        session = try JSONDecoder().decode(FocusSession.self, from: JSONEncoder().encode(session))
        session.resume(at: start.addingTimeInterval(1000))
        check(session.elapsed(at: start.addingTimeInterval(1060)) == 180, "pause and resume survives encoding")
        check(RooftopWorld.rank(for: 1499) == 1 && RooftopWorld.rank(for: 1500) == 2 && RooftopWorld.rank(for: 6000) == 5, "growth thresholds")
        check(RooftopWorld.progress(for: 9000, rank: 2) == 1 && RooftopWorld.remaining(for: 1500, rank: 2) == 1500, "progress and remaining bounded")
        func growthResult(from: TimeInterval, to: TimeInterval) -> SessionResult {
            SessionResult(creditedSeconds: to - from, previousRank: RooftopWorld.rank(for: from),
                          newRank: RooftopWorld.rank(for: to), previousGrowthSeconds: from, growthSeconds: to)
        }
        let partial = growthResult(from: 1200, to: 1300).growthSteps
        check(partial.count == 1 && partial[0].rank == 1 && partial[0].start == 0.8
              && partial[0].end == 1300.0 / 1500, "result animation preserves existing progress and adds only credited growth")
        let boundary = growthResult(from: 1000, to: 1500)
        check(boundary.newRank == 2 && boundary.growthSteps.count == 1 && boundary.growthSteps[0].end == 1,
              "an exact rank boundary fills the old ring before selecting the next rank")
        let crossed = growthResult(from: 2000, to: 5200).growthSteps
        check(crossed.map(\.rank) == [2, 3, 4] && crossed[0].end == 1 && crossed[1].end == 1
              && crossed[2].end == 700.0 / 1500, "multiple unlocked ranks animate sequentially including the final partial stage")
        check(growthResult(from: 1200, to: 1200).growthSteps.isEmpty, "zero credited time produces no false growth animation")
        let completion = growthResult(from: 5900, to: 7000)
        check(completion.completed && completion.growthSteps.count == 1 && completion.growthSteps[0].rank == 4
              && completion.growthSteps[0].end == 1, "completion stops growth at the fifth milestone")
        check(growthResult(from: 6100, to: 6400).growthSteps.isEmpty, "work after completion does not replay growth")
        check(TimeText.preciseDuration(1938) == "32分18秒" && TimeText.preciseDuration(0) == "0秒"
              && TimeText.preciseDuration(3601) == "1時間1秒", "result duration preserves credited seconds")
        let url = root.appendingPathComponent("state.json")
        let store = FocusStore(persistenceURL: url, startTimer: false)
        let story = store.collectionEntries[0].story
        check(story?.chapter(at: 1, unlockedRank: store.rank)?.title == "もう一案"
              && (2...5).allSatisfy { story?.chapter(at: $0, unlockedRank: store.rank) == nil },
              "new collection exposes only the first story chapter, including titles")
        check((1...5).allSatisfy { unlocked in
            (1...5).allSatisfy { requested in
                (story?.chapter(at: requested, unlockedRank: unlocked) != nil) == (requested <= unlocked)
            }
        }, "each growth rank unlocks exactly its story chapters")
        check(story?.chapter(at: 0, unlockedRank: 5) == nil
              && story?.chapter(at: 6, unlockedRank: 100) == nil
              && story?.chapter(at: 1, unlockedRank: 0) == nil,
              "invalid story ranks never expose a chapter")
        #if DEBUG
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let originalData = try encoder.encode(store.data)
        check(store.collectionEntries.count == 9 && store.collectionEntries.filter(\.isSample).count == 5
              && Set(store.collectionEntries.map(\.id)).count == 9, "debug collection fixtures have unique identities alongside the real scene")
        check(CollectionEntry.debugSamples.allSatisfy { $0.story == nil },
              "other situations do not reuse the rooftop story")
        store.debugCollectionsEnabled = false
        check(store.collectionEntries.count == 4 && store.collectionEntries[0].id == RooftopWorld.id,
              "hiding fixtures preserves the real collection")
        store.debugCollectionsEnabled = true
        let dataAfterSamples = try encoder.encode(store.data)
        check(dataAfterSamples == originalData, "collection fixtures do not change saved growth records or settings")
        #else
        check(store.collectionEntries.count == 4 && !store.collectionEntries[0].isSample,
              "release contains only the real collection")
        #endif
        store.setConfirmation(.everySession)
        store.start(at: start)
        store.requestFinish(at: start.addingTimeInterval(1800))
        check(store.needsReview && store.data.records.isEmpty, "review holds credit until confirmation")
        store.commit(deducting: 600, at: start.addingTimeInterval(1900))
        check(store.data.growthSeconds == 1200 && store.data.records[0].seconds == 1200 && store.rank == 1, "corrected time credited equally to record and growth")
        check(store.result?.previousGrowthSeconds == 0 && store.result?.growthSeconds == 1200,
              "result retains exact before and after growth for the animation")
        store.commit(deducting: 0)
        check(store.data.records.count == 1, "confirmation cannot double-credit")
        let restored = FocusStore(persistenceURL: url, startTimer: false)
        check(restored.data.growthSeconds == 1200 && restored.data.records.count == 1, "saved records and growth restored")
        restored.start(at: start)
        restored.requestFinish(at: start.addingTimeInterval(1800))
        restored.discardSession()
        check(restored.data.growthSeconds == 1200 && restored.data.records.count == 1, "discard does not affect prior growth")
        restored.start(at: start)
        restored.requestFinish(at: start.addingTimeInterval(300))
        restored.commit(deducting: 0, at: start.addingTimeInterval(300))
        restored.showRank(1)
        check(restored.rank == 2 && restored.displayedRank == 1
              && restored.collectionEntries[0].story?.chapter(at: 2, unlockedRank: restored.rank) != nil
              && restored.collectionEntries[0].story?.chapter(at: 3, unlockedRank: restored.rank) == nil,
              "confirmed growth unlocks the next chapter even when viewing an earlier scene")
        restored.previewCollectionAudio(rank: 2)
        check(restored.audio.lastRank == 2 && restored.audioRank == 2 && restored.displayedRank == 1,
              "collection audio follows its preview without changing the work background")
        let originalPagesEnabled = restored.soundEnabled(.pages)
        restored.toggleSound(.pages)
        check(restored.soundEnabled(.pages) != originalPagesEnabled && restored.audio.lastRank == 2,
              "sound settings use the preview rank rather than the work background rank")
        restored.previewCollectionAudio(rank: 99)
        check(restored.audioRank == 2 && restored.audio.lastRank == 2,
              "collection audio cannot unlock sounds beyond confirmed growth")
        restored.endCollectionAudioPreview()
        let afterAudioPreview = FocusStore(persistenceURL: url, startTimer: false)
        check(restored.collectionAudioRank == nil && restored.audio.lastRank == 1
              && afterAudioPreview.displayedRank == 1 && afterAudioPreview.rank == 2
              && afterAudioPreview.soundEnabled(.pages) != originalPagesEnabled,
              "dismissing the collection restores work audio and preserves intentional mix edits")
        restored.toggleSound(.music)
        restored.previewCollectionAudio(rank: 2)
        check(restored.audio.lastMix?.enabled["music"] == false,
              "opening a collection respects an explicitly disabled BGM")
        restored.endCollectionAudioPreview()
        // Moving a muted, unlocked slider must immediately produce audible output.
        restored.previewCollectionAudio(rank: 2)
        if restored.soundEnabled(.pages) { restored.toggleSound(.pages) }
        restored.setVolume(0.67, for: .pages)
        check(restored.soundEnabled(.pages) && restored.audio.lastMix?.enabled["pages"] == true
              && restored.audio.lastMix?.volumes["pages"] == 0.67,
              "raising a muted work sound slider unmutes it and updates playback")
        restored.toggleSound(.pages)
        restored.setVolume(0, for: .pages)
        check(!restored.soundEnabled(.pages), "touching zero on a muted slider does not start playback")
        let lockedMix = restored.data.mix
        restored.setVolume(0.8, for: .rain)
        restored.setVolume(.nan, for: .pages)
        restored.setVolume(.infinity, for: .pages)
        check(restored.data.mix == lockedMix, "locked sounds and invalid volume values cannot change the mix")
        restored.setVolume(2, for: .pages)
        let volumeRestored = FocusStore(persistenceURL: url, startTimer: false)
        check(volumeRestored.soundEnabled(.pages) && volumeRestored.soundVolume(.pages) == 1,
              "slider changes are bounded and persist after reopening")
        restored.endCollectionAudioPreview()
        let activeURL = root.appendingPathComponent("active.json")
        let active = FocusStore(persistenceURL: activeURL, startTimer: false)
        active.start(at: start)
        let reopened = FocusStore(persistenceURL: activeURL, startTimer: false)
        reopened.tick(at: start.addingTimeInterval(90))
        check(reopened.elapsed == 90 && reopened.isRunning, "active stopwatch resumes after reopening")
        let frequent = FocusStore(persistenceURL: root.appendingPathComponent("frequent.json"), startTimer: false)
        frequent.setConfirmation(.frequent)
        frequent.start(at: start)
        frequent.tick(at: start.addingTimeInterval(1800))
        check(frequent.checkInRequested, "periodic check-in appears at interval")
        frequent.acknowledgeCheckIn(takeBreak: true)
        check(frequent.isPaused && !frequent.checkInRequested, "check-in can pause work")
        check(!ConfirmationMode.none.needsReview(seconds: 10000) && !ConfirmationMode.light.needsReview(seconds: 3599) && ConfirmationMode.light.needsReview(seconds: 3600), "confirmation policy")
        let custom = FocusStore(persistenceURL: root.appendingPathComponent("custom.json"), startTimer: false)
        custom.setConfirmation(.none)
        custom.start(at: start)
        custom.requestFinish(at: start.addingTimeInterval(5))
        #if DEBUG
        check(custom.needsReview, "debug always allows editing time at finish")
        custom.commitDebugTime(seconds: .infinity)
        custom.commitDebugTime(seconds: -1)
        check(custom.needsReview && custom.data.records.isEmpty, "invalid debug duration rejected")
        custom.commitDebugTime(seconds: 6000)
        check(custom.data.records.first?.seconds == 6000 && custom.data.records.first?.measuredSeconds == 5 && custom.rank == 5 && custom.data.growthSeconds == 6000, "debug time overrides measured duration for records and growth")
        custom.commitDebugTime(seconds: 6000)
        check(custom.data.records.count == 1, "debug confirmation cannot double-credit")
        custom.setConfirmation(.frequent)
        custom.setCheckInterval(15)
        custom.showRank(3)
        custom.toggleSound(.rain)
        custom.start(at: start)
        custom.tick(at: start.addingTimeInterval(1800))
        custom.resetDebugData()
        check(custom.rank == 1 && custom.data.growthSeconds == 0 && custom.data.records.isEmpty && !custom.hasSession && custom.result == nil && !custom.checkInRequested, "debug reset clears progress records and active session")
        check(custom.data.confirmation == .light && custom.data.checkIntervalMinutes == 30 && custom.data.displayRank == nil && custom.data.mix == SoundMix(), "debug reset restores default settings and sounds")
        let resetRestored = FocusStore(persistenceURL: root.appendingPathComponent("custom.json"), startTimer: false)
        check(resetRestored.rank == 1 && resetRestored.data.records.isEmpty && !resetRestored.hasSession && resetRestored.data.confirmation == .light, "debug reset persists after reopening")
        #else
        check(!custom.needsReview && custom.data.records.first?.seconds == 5, "release honors confirmation setting and measured time")
        #endif
        // Decode the old shape exactly: no active-world, per-world progress, or session-world keys.
        var legacy = AppData()
        legacy.growthSeconds = 3100
        legacy.displayRank = 2
        legacy.mix.enabled["music"] = false
        legacy.session = FocusSession(now: start, interval: 1800)
        var legacyJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as! [String: Any]
        legacyJSON.removeValue(forKey: "activeWorldID")
        legacyJSON.removeValue(forKey: "worlds")
        let legacyURL = root.appendingPathComponent("legacy.json")
        try JSONSerialization.data(withJSONObject: legacyJSON).write(to: legacyURL)
        let migrated = FocusStore(persistenceURL: legacyURL, startTimer: false)
        check(migrated.activeWorld == .rooftop && migrated.rank == 3 && migrated.displayedRank == 2
              && migrated.data.growthSeconds == 3100 && !migrated.soundEnabled(.music),
              "version-1 save migration preserves rooftop growth rank and sound preferences")
        migrated.setConfirmation(.everySession)
        migrated.requestFinish(at: start.addingTimeInterval(60))
        migrated.commit(deducting: 0, at: start.addingTimeInterval(60))
        check(migrated.data.growthSeconds == 3160 && migrated.data.records.last?.worldID == RooftopWorld.id,
              "legacy active sessions continue to credit the rooftop world")

        let shrineURL = root.appendingPathComponent("shrine.json")
        let shrine = FocusStore(persistenceURL: shrineURL, startTimer: false)
        shrine.setConfirmation(.everySession)
        check(shrine.useWorld(.shrine) && shrine.rank == 1 && shrine.displayedRank == 1,
              "the new shrine starts at rank 1 independently of rooftop")
        check(shrine.availableSounds.contains(.water) && !shrine.availableSounds.contains(.rain)
              && !shrine.availableSounds.contains(.fire) && !shrine.availableSounds.contains(.pages),
              "shrine ambience excludes rain fire and keyboard sounds")
        guard let shrineStory = FocusWorld.shrine.story else { fatalError("Missing shrine story") }
        check(shrineStory.world == .shrine && shrineStory.title == "もうひとつだけ"
              && (2...5).allSatisfy { shrineStory.chapter(at: $0, unlockedRank: shrine.rank) == nil },
              "shrine story and future chapter titles stay behind its own rank gate")
        check((1...5).allSatisfy { unlocked in
            (1...5).allSatisfy { requested in
                (shrineStory.chapter(at: requested, unlockedRank: unlocked) != nil) == (requested <= unlocked)
            }
        } && shrineStory.chapter(at: 5, unlockedRank: 5)?.text.hasSuffix("「全部でいくつですか」") == true,
              "all five shrine chapters unlock in sequence and preserve the agreed ending")
        shrine.setVolume(0.18, for: .music)
        for target in 2...5 {
            shrine.start(at: start)
            check(!shrine.useWorld(.rooftop) && shrine.activeWorld == .shrine,
                  "world switching cannot redirect an active rank-\(target) session")
            shrine.requestFinish(at: start.addingTimeInterval(1500))
            shrine.commit(deducting: 0, at: start.addingTimeInterval(1500))
            check(shrine.rank == target && shrine.result?.world == .shrine
                  && shrine.data.records.last?.worldID == FocusWorld.shrine.id,
                  "rank \(target) unlocks only in the shrine and its result opens the shrine story")
        }
        check(shrine.data.growthSeconds == 0 && shrine.data.progress(for: .shrine).growthSeconds == 6000,
              "shrine work never changes existing rooftop growth")
        shrine.showRank(2)
        shrine.previewCollectionAudio(rank: 5, world: .rooftop)
        check(shrine.audioWorld == .rooftop && shrine.audioRank == 1 && shrine.rank == 5
              && shrine.displayedRank == 2 && shrine.audio.lastWorld == .rooftop,
              "collection audio uses that world's own unlocks without changing the work scene")
        shrine.setVolume(0.61, for: .music)
        shrine.endCollectionAudioPreview()
        check(shrine.audioWorld == .shrine && shrine.audioRank == 2 && shrine.soundVolume(.music) == 0.18,
              "closing a collection restores the active world's independent audio mix")
        let shrineRestored = FocusStore(persistenceURL: shrineURL, startTimer: false)
        check(shrineRestored.activeWorld == .shrine && shrineRestored.rank == 5
              && shrineRestored.displayedRank == 2 && shrineRestored.data.records.count == 4,
              "shrine progress selected rank active world and records survive reopening")
        check(shrineRestored.useWorld(.rooftop) && shrineRestored.rank == 1
              && shrineRestored.soundVolume(.music) == 0.61 && shrineRestored.useWorld(.shrine, rank: 99)
              && shrineRestored.displayedRank == 5,
              "both real collections are selectable and requested ranks are bounded")
        let harborURL = root.appendingPathComponent("shell-harbor.json")
        let harbor = FocusStore(persistenceURL: harborURL, startTimer: false)
        harbor.setConfirmation(.everySession)
        check(harbor.useWorld(.shellHarbor) && harbor.rank == 1, "shell harbor starts independently at rank 1")
        check(harbor.collectionEntries.first(where: { $0.world == .shellHarbor })?.story == nil
              && FocusWorld.shellHarbor.story == nil, "shell harbor has no story in its collection or results")
        check(harbor.availableSounds == [.music, .water, .wind, .birds]
              && harbor.isSoundUnlocked(.water) && !harbor.isSoundUnlocked(.birds),
              "shell harbor starts with water and excludes unrelated ambience")
        for target in 2...5 {
            harbor.start(at: start)
            check(!harbor.useWorld(.shrine), "shell harbor session cannot be redirected at rank \(target)")
            harbor.requestFinish(at: start.addingTimeInterval(1500))
            harbor.commit(deducting: 0, at: start.addingTimeInterval(1500))
            check(harbor.rank == target && harbor.result?.world == .shellHarbor
                  && harbor.result?.world.story == nil
                  && harbor.data.records.last?.worldID == FocusWorld.shellHarbor.id,
                  "shell harbor rank \(target) credits its own world without story unlocks")
        }
        check(harbor.isSoundUnlocked(.birds) && harbor.data.progress(for: .shrine).rank == 1
              && harbor.data.progress(for: .rooftop).rank == 1, "shell growth preserves both existing worlds")
        harbor.previewCollectionAudio(rank: 2, world: .shellHarbor)
        harbor.setVolume(0.81, for: .birds)
        check(!harbor.isSoundUnlocked(.birds) && harbor.soundVolume(.birds) == 0.4,
              "shell harbor preview prevents editing future bird audio")
        harbor.previewCollectionAudio(rank: 3, world: .shellHarbor)
        harbor.setVolume(0.51, for: .birds)
        check(harbor.isSoundUnlocked(.birds) && harbor.soundVolume(.birds) == 0.51,
              "shell harbor bird audio unlocks with the rank-3 birds")
        harbor.endCollectionAudioPreview()
        harbor.showRank(3)
        let harborRestored = FocusStore(persistenceURL: harborURL, startTimer: false)
        check(harborRestored.activeWorld == .shellHarbor && harborRestored.rank == 5
              && harborRestored.displayedRank == 3 && harborRestored.soundVolume(.birds) == 0.51
              && harborRestored.data.records.count == 4, "shell harbor progress and sound mix survive reopening")
        #if DEBUG
        harborRestored.resetDebugData()
        check(harborRestored.data.progress(for: .shellHarbor).rank == 1,
              "debug reset includes the new shell harbor")
        shrineRestored.resetDebugData()
        check(shrineRestored.activeWorld == .rooftop && shrineRestored.data.worlds == nil
              && shrineRestored.data.progress(for: .shrine).rank == 1,
              "debug reset clears every world's progress")
        #endif
        let workshop = FocusStore(persistenceURL: root.appendingPathComponent("ember-workshop.json"), startTimer: false)
        check(workshop.useWorld(.emberWorkshop) && workshop.rank == 1, "ember workshop starts separately")
        check(workshop.availableSounds == [.music, .embers, .bellows, .hammer, .grinder, .clockwork]
              && workshop.isSoundUnlocked(.embers) && !workshop.isSoundUnlocked(.bellows), "ember sound unlocks begin at the fire")
        workshop.setConfirmation(.everySession)
        for target in 2...5 {
            workshop.start(at: start)
            workshop.requestFinish(at: start.addingTimeInterval(1500))
            workshop.commit(deducting: 0, at: start.addingTimeInterval(1500))
            check(workshop.rank == target && workshop.result?.world == .emberWorkshop
                  && workshop.result?.world.story == nil, "ember rank \(target) grows without a story")
        }
        check(workshop.data.progress(for: .shellHarbor).rank == 1 && workshop.data.progress(for: .rooftop).rank == 1,
              "ember growth leaves existing worlds unchanged")
        workshop.previewCollectionAudio(rank: 2, world: .emberWorkshop)
        check(workshop.isSoundUnlocked(.bellows) && !workshop.isSoundUnlocked(.hammer), "ember previews gate audio by selected rank")
        workshop.endCollectionAudioPreview()
        workshop.setVolume(0.23, for: .clockwork)
        let restoredWorkshop = FocusStore(persistenceURL: root.appendingPathComponent("ember-workshop.json"), startTimer: false)
        check(restoredWorkshop.activeWorld == .emberWorkshop && restoredWorkshop.rank == 5
              && restoredWorkshop.soundVolume(.clockwork) == 0.23, "ember progress and audio survive reopening")
        print("\(passed) core checks passed")
    }
}
