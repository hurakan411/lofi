import Foundation
import Combine

@MainActor
final class FocusStore: ObservableObject {
    @Published private(set) var data: AppData
    @Published private(set) var now = Date()
    @Published var result: SessionResult?
    @Published private(set) var timerBoundaryID: UUID?
    @Published var checkInRequested = false
    @Published var storageError: String?
    @Published var audioError: String?
    @Published private(set) var collectionAudioRank: Int?
    @Published private(set) var collectionAudioWorld: FocusWorld?
    private var collectionAudioMuted = false
    let audio = SoundscapePlayer()
    private let persistenceURL: URL
    private var timer: Timer?
    var isForeground = true
    private(set) var isInBackground = false
    #if DEBUG
    @Published var debugCollectionsEnabled = true
    private let debugUnlockAllRanks: Bool
    #endif

    init(persistenceURL: URL? = nil, startTimer: Bool = true, debugUnlockAllRanks: Bool = false) {
        #if DEBUG
        self.debugUnlockAllRanks = debugUnlockAllRanks
        #endif
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lofi", isDirectory: true)
        self.persistenceURL = persistenceURL ?? directory.appendingPathComponent("focus-state.json")
        if let saved = try? Data(contentsOf: self.persistenceURL),
           let decoded = try? JSONDecoder().decode(AppData.self, from: saved) {
            data = decoded
        } else {
            data = AppData()
        }
        #if DEBUG
        // Simulator previews use an isolated, in-memory state; never overwrite saved progress.
        if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--preview-rank=") }),
           let rank = Int(argument.split(separator: "=").last ?? "1") {
            data = AppData()
            if let world = FocusWorld.allCases.first(where: {
                ProcessInfo.processInfo.arguments.contains("--preview-world=\($0.resourcePrefix)")
            }) { data.activeWorldID = world.rawValue }
            let world = data.activeWorld
            data.update(world) { $0.growthSeconds = Double(min(5, max(1, rank)) - 1) * RooftopWorld.stageDuration }
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            data.mix.enabled = Dictionary(uniqueKeysWithValues: SoundKind.allCases.map { ($0.rawValue, false) })
        }
        #endif
        if startTimer {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        }
    }

    var activeWorld: FocusWorld { data.activeWorld }
    var growth: WorldProgress { data.progress(for: activeWorld) }
    var rank: Int { growth.rank }
    func unlockedRank(for world: FocusWorld) -> Int {
        #if DEBUG
        if debugUnlockAllRanks { return 5 }
        #endif
        return data.progress(for: world).rank
    }
    func displayedRank(for world: FocusWorld) -> Int {
        let progress = data.progress(for: world)
        return min(unlockedRank(for: world), max(1, progress.displayRank ?? progress.rank))
    }
    var displayedRank: Int { displayedRank(for: activeWorld) }
    var audioWorld: FocusWorld { collectionAudioWorld ?? activeWorld }
    var audioRank: Int { min(unlockedRank(for: audioWorld), collectionAudioRank ?? displayedRank) }
    var availableSounds: [SoundKind] { audioWorld.sounds }
    var worldName: String { activeWorld.name(at: displayedRank) }
    var isComplete: Bool { rank == 5 }
    var collectionEntries: [CollectionEntry] {
        let worlds = FocusWorld.allCases.map { world in
            let rank = unlockedRank(for: world)
            return CollectionEntry(id: world.id, title: world.name(at: rank), rank: rank,
                                   artwork: world.artwork)
        }
        #if DEBUG
        return worlds + (debugCollectionsEnabled ? CollectionEntry.debugSamples : [])
        #else
        return worlds
        #endif
    }
    func canUseWorld(_ world: FocusWorld) -> Bool {
        !hasSession || world == (FocusWorld(rawValue: data.session?.worldID ?? "") ?? .rooftop)
    }
    @discardableResult
    func useWorld(_ world: FocusWorld, rank: Int? = nil) -> Bool {
        guard canUseWorld(world) else { return false }
        data.activeWorldID = world.rawValue
        let limit = unlockedRank(for: world)
        data.update(world) { progress in
            let chosen = rank.map { min(limit, max(1, $0)) }
            progress.displayRank = chosen == progress.rank ? nil : chosen
        }
        persist()
        syncAudio()
        return true
    }
    var timerSettings: FocusTimerSettings { data.timerPreferences ?? FocusTimerSettings() }
    var sessionMode: FocusMode { data.session?.selectedMode ?? .normal }
    var timerReading: FocusTimerReading? { data.session?.reading(at: now) }
    var isOnBreak: Bool { timerReading?.period.isBreak == true }
    var clockSeconds: TimeInterval { timerReading?.remaining.map { ceil($0) } ?? elapsed }
    var canResume: Bool { hasSession && timerReading?.period != .finished }
    var sessionStatus: String {
        if needsReview { return "時間を確認中" }
        if isPaused { return isOnBreak ? "休憩を一時停止中":"一時停止中" }
        if timerReading?.period == .longBreak { return "長い休憩中" }
        return isOnBreak ? "休憩中":"作業中"
    }
    var elapsed: TimeInterval { data.session?.elapsed(at: now) ?? 0 }
    var isRunning: Bool { data.session?.phase == .running }
    var isPaused: Bool { data.session?.phase == .paused }
    var needsReview: Bool { data.session?.phase == .review }
    var hasSession: Bool { data.session != nil }
    var previewGrowth: TimeInterval { growth.growthSeconds + (hasSession ? elapsed : 0) }
    var evolutionProgress: Double { RooftopWorld.progress(for: previewGrowth, rank: rank) }
    var remaining: TimeInterval { RooftopWorld.remaining(for: previewGrowth, rank: rank) }
    var evolutionLabel: String {
        if isComplete { return "この場所は、育ちました" }
        if remaining <= 0 { return "進化まで到達 · 終了後に反映" }
        return "次の進化まで あと\(Int(ceil(remaining / 60)))分"
    }

    func tick(at date: Date = Date()) {
        let previousReading=data.session?.reading(at: now)
        now = date
        if isForeground, let session=data.session, session.phase == .running,
           session.selectedMode == .countdown, session.reading(at: date).period == .finished {
            timerBoundaryID=UUID()
            requestFinish(at: date)
            return
        }
        if let session=data.session, session.phase == .running, session.selectedMode == .pomodoro,
           let previousReading, let reading=timerReading,
           previousReading.period != reading.period || previousReading.round != reading.round {
            timerBoundaryID=UUID()
        }
        guard isForeground, !isOnBreak, data.confirmation == .frequent,
              let session = data.session, session.phase == .running,
              session.elapsed(at: now) >= session.nextCheckAt, !checkInRequested else { return }
        checkInRequested = true
    }

    func start(mode: FocusMode = .normal, settings: FocusTimerSettings? = nil, at date: Date = Date()) {
        guard data.session == nil else { return }
        now = date
        data.session = FocusSession(now: date, interval: Double(data.checkIntervalMinutes * 60))
        data.session?.worldID = activeWorld.rawValue
        data.session?.mode = mode
        data.session?.timerSettings = (settings ?? timerSettings).bounded
        if mode != .normal { data.timerPreferences = (settings ?? timerSettings).bounded }
        persist()
        syncAudio()
    }
    func pause(at date: Date = Date()) {
        guard data.session?.phase == .running else { return }
        now = date
        data.session?.pause(at: date)
        persist()
    }
    func resume(at date: Date = Date()) {
        guard let session = data.session, session.phase != .running, canResume else { return }
        now = date
        data.session?.resume(at: date)
        persist()
    }
    func requestFinish(at date: Date = Date()) {
        guard data.session != nil, data.session?.phase != .review else { return }
        now = date
        data.session?.pause(at: date, forReview: true)
        checkInRequested = false
        persist()
        #if !DEBUG
        if !data.confirmation.needsReview(seconds: elapsed) { commit(deducting: 0, at: date) }
        #endif
    }
    func commit(deducting seconds: TimeInterval, at date: Date = Date()) {
        guard let session = data.session, session.phase == .review else { return }
        let measured = session.elapsed(at: date)
        let credited = max(0, floor(measured - max(0, seconds)))
        finishCommit(session: session, measured: measured, credited: credited, at: date)
    }
    #if DEBUG
    func resetDebugData() {
        data = AppData()
        collectionAudioRank = nil
        collectionAudioWorld = nil
        result = nil
        timerBoundaryID = nil
        checkInRequested = false
        storageError = nil
        audioError = nil
        now = Date()
        persist()
        syncAudio()
    }
    func commitDebugTime(seconds: TimeInterval, at date: Date = Date()) {
        guard let session = data.session, session.phase == .review,
              seconds.isFinite, seconds >= 0, seconds < Double(Int.max) / 4 else { return }
        finishCommit(session: session, measured: session.elapsed(at: date), credited: floor(seconds), at: date)
    }
    #endif
    private func finishCommit(session: FocusSession, measured: TimeInterval, credited: TimeInterval, at date: Date) {
        let world = FocusWorld(rawValue: session.worldID ?? "") ?? .rooftop
        let previous = data.progress(for: world).rank
        let previousGrowth = data.progress(for: world).growthSeconds
        if credited > 0 {
            data.records.append(WorkRecord(id: session.id, startedAt: session.startedAt,
                endedAt: date, measuredSeconds: measured, seconds: credited, worldID: world.rawValue, mode: session.selectedMode))
            data.update(world) {
                $0.growthSeconds += credited
                $0.displayRank = nil
            }
        }
        data.session = nil
        result = SessionResult(world: world, creditedSeconds: credited, previousRank: previous,
                               newRank: data.progress(for: world).rank,
                               previousGrowthSeconds: previousGrowth, growthSeconds: data.progress(for: world).growthSeconds)
        now = date
        persist()
        syncAudio()
    }
    func discardSession() {
        data.session = nil
        checkInRequested = false
        persist()
    }
    func acknowledgeCheckIn(takeBreak: Bool) {
        if takeBreak { pause() }
        data.session?.nextCheckAt = elapsed + Double(data.checkIntervalMinutes * 60)
        checkInRequested = false
        persist()
    }
    func setConfirmation(_ mode: ConfirmationMode) {
        data.confirmation = mode
        data.session?.nextCheckAt = elapsed + Double(data.checkIntervalMinutes * 60)
        checkInRequested = false
        persist()
    }
    func setCheckInterval(_ minutes: Int) {
        data.checkIntervalMinutes = minutes
        data.session?.nextCheckAt = elapsed + Double(minutes * 60)
        persist()
    }
    func showRank(_ rank: Int) {
        let chosen = min(unlockedRank(for: activeWorld), max(1, rank))
        data.update(activeWorld) { $0.displayRank = chosen }
        persist()
        syncAudio()
    }
    func followGrowingScene() {
        data.update(activeWorld) { $0.displayRank = nil }
        persist()
        syncAudio()
    }
    func soundEnabled(_ sound: SoundKind) -> Bool { data.progress(for: audioWorld).mix.enabled[sound.rawValue] ?? true }
    func isSoundUnlocked(_ sound: SoundKind) -> Bool {
        availableSounds.contains(sound) && audioRank >= audioWorld.unlockRank(for: sound)
    }
    func soundVolume(_ sound: SoundKind) -> Double { data.progress(for: audioWorld).mix.volumes[sound.rawValue] ?? 0.4 }
    func toggleSound(_ sound: SoundKind) {
        guard isSoundUnlocked(sound) else { return }
        let enabled = !soundEnabled(sound)
        data.update(audioWorld) { $0.mix.enabled[sound.rawValue] = enabled }
        persist()
        syncAudio()
    }
    func setVolume(_ value: Double, for sound: SoundKind) {
        guard isSoundUnlocked(sound), value.isFinite else { return }
        let volume = min(1, max(0, value))
        data.update(audioWorld) {
            $0.mix.volumes[sound.rawValue] = volume
            if volume > 0 { $0.mix.enabled[sound.rawValue] = true }
        }
        persist()
        syncAudio()
    }
    var backgroundPlaybackEnabled: Bool { data.backgroundPlayback ?? true }
    func setBackgroundPlaybackEnabled(_ enabled: Bool) {
        data.backgroundPlayback = enabled
        persist()
        syncAudio()
    }
    func setAppInBackground(_ background: Bool) {
        isInBackground = background
        syncAudio()
    }
    func syncAudio() {
        let allowed = !collectionAudioMuted && (!isInBackground || backgroundPlaybackEnabled)
        audio.setPlaybackAllowed(allowed)
        guard allowed else { return }
        do { try audio.update(mix: data.progress(for: audioWorld).mix, rank: audioRank, world: audioWorld) }
        catch { audioError = "音を再生できませんでした。音声の設定を確認してください。" }
    }
    func previewCollectionAudio(rank: Int, world: FocusWorld? = nil) {
        let world = world ?? activeWorld
        if collectionAudioWorld != world || collectionAudioMuted { audio.stopAll() }
        collectionAudioMuted = false
        collectionAudioWorld = world
        collectionAudioRank = min(unlockedRank(for: world), max(1, rank))
        syncAudio()
    }
    func silenceCollectionAudio() {
        collectionAudioMuted = true
        audio.stopAll()
    }
    func endCollectionAudioPreview() {
        guard collectionAudioRank != nil || collectionAudioMuted else { return }
        audio.stopAll()
        collectionAudioMuted = false
        collectionAudioRank = nil
        collectionAudioWorld = nil
        syncAudio()
    }
    func persist() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("--preview-rank=") }) { return }
        #endif
        do {
            try FileManager.default.createDirectory(at: persistenceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(data).write(to: persistenceURL, options: .atomic)
        } catch {
            storageError = "記録を保存できませんでした。端末の空き容量を確認してください。"
        }
    }
}
