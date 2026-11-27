import Foundation
import CoreGraphics

enum ConfirmationMode: String, Codable, CaseIterable, Identifiable {
    case none, light, everySession, frequent
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: "なし"
        case .light: "軽め"
        case .everySession: "毎回"
        case .frequent: "こまめ"
        }
    }
    var detail: String {
        switch self {
        case .none: "計測した時間を、そのまま反映します。"
        case .light: "60分以上の作業を終えたときに確認します。"
        case .everySession: "作業を終えるたびに、実際に作業した時間を確認します。"
        case .frequent: "終了時と、作業中にも定期的に確認します。"
        }
    }
    func needsReview(seconds: TimeInterval) -> Bool {
        self == .everySession || self == .frequent || (self == .light && seconds >= 3_600)
    }
}

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case normal, pomodoro, countdown
    var id: String { rawValue }
    var title: String {
        switch self { case .normal: "計測"; case .pomodoro: "ポモドーロ"; case .countdown: "タイマー" }
    }
    var icon: String {
        switch self { case .normal: "infinity"; case .pomodoro: "arrow.triangle.2.circlepath"; case .countdown: "hourglass" }
    }
}

struct FocusTimerSettings: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var countdownMinutes = 25
    var bounded: Self {
        Self(focusMinutes: min(120, max(1, focusMinutes)),
             shortBreakMinutes: min(30, max(1, shortBreakMinutes)),
             longBreakMinutes: min(60, max(1, longBreakMinutes)),
             countdownMinutes: min(719, max(1, countdownMinutes)))
    }
}

enum TimerPeriod: String { case focus, shortBreak, longBreak, finished
    var isBreak: Bool { self == .shortBreak || self == .longBreak }
}
struct FocusTimerReading {
    let focusSeconds: TimeInterval
    let remaining: TimeInterval?
    let period: TimerPeriod
    let round: Int
}
struct FocusTimerEvent {
    let after: TimeInterval
    let title: String
    let body: String
}

/// Shared drawing/hit-test geometry for both tap and press-drag-release selection.
struct StartModeLayout {
    let width: CGFloat
    var compact = false
    var height: CGFloat { compact ? 204 : 250 }
    var origin: CGPoint { CGPoint(x: width/2, y: height-64) }
    func center(for mode: FocusMode) -> CGPoint {
        let span = min(compact ? 100.0 : 94.0, max(60, (width-104)/2))
        switch mode {
        case .normal: return CGPoint(x: origin.x-span, y: origin.y-(compact ? 58 : 74))
        case .pomodoro: return CGPoint(x: origin.x, y: origin.y-(compact ? 87 : 114))
        case .countdown: return CGPoint(x: origin.x+span, y: origin.y-(compact ? 58 : 74))
        }
    }
    func hitTest(_ point: CGPoint) -> FocusMode? {
        FocusMode.allCases.filter { mode in
            let c = center(for: mode)
            return pow((point.x-c.x)/49, 2)+pow((point.y-c.y)/46, 2) <= 1
        }.min { a,b in
            let ca=center(for:a), cb=center(for:b)
            return hypot(point.x-ca.x,point.y-ca.y) < hypot(point.x-cb.x,point.y-cb.y)
        }
    }
}

enum SessionPhase: String, Codable { case running, paused, review }

struct FocusSession: Codable, Equatable {
    var id = UUID()
    var worldID: String?
    var mode: FocusMode?
    var timerSettings: FocusTimerSettings?
    var startedAt: Date
    var resumedAt: Date?
    var accumulated: TimeInterval = 0
    var phase: SessionPhase = .running
    var nextCheckAt: TimeInterval

    init(now: Date, interval: TimeInterval) {
        startedAt = now
        resumedAt = now
        nextCheckAt = interval
    }

    var selectedMode: FocusMode { mode ?? .normal }
    var settings: FocusTimerSettings { (timerSettings ?? FocusTimerSettings()).bounded }
    func activeElapsed(at now: Date) -> TimeInterval {
        max(0, accumulated + (phase == .running ? max(0, now.timeIntervalSince(resumedAt ?? now)) : 0))
    }
    func elapsed(at now: Date) -> TimeInterval { reading(at: now).focusSeconds }
    func reading(at now: Date) -> FocusTimerReading { reading(activeSeconds: activeElapsed(at: now)) }
    private func reading(activeSeconds time: TimeInterval) -> FocusTimerReading {
        let s=settings
        switch selectedMode {
        case .normal:
            return FocusTimerReading(focusSeconds: time, remaining: nil, period: .focus, round: 1)
        case .countdown:
            let goal=Double(s.countdownMinutes)*60
            return FocusTimerReading(focusSeconds: min(time,goal), remaining: max(0,goal-time),
                                     period: time >= goal ? .finished : .focus, round: 1)
        case .pomodoro:
            let work=Double(s.focusMinutes)*60, short=Double(s.shortBreakMinutes)*60, long=Double(s.longBreakMinutes)*60
            let length=work*4+short*3+long, groups=floor(time/length)
            var rest=time-groups*length
            for round in 1...4 {
                let focus=groups*4*work+Double(round-1)*work
                if rest < work {
                    return FocusTimerReading(focusSeconds: focus+rest, remaining: work-rest, period: .focus, round: Int(groups)*4+round)
                }
                rest-=work
                let pause=round == 4 ? long:short
                if rest < pause {
                    return FocusTimerReading(focusSeconds: focus+work, remaining: pause-rest,
                                             period: round == 4 ? .longBreak:.shortBreak, round: Int(groups)*4+round)
                }
                rest-=pause
            }
            // Only reachable through floating point rounding at a group boundary.
            return FocusTimerReading(focusSeconds: (groups+1)*4*work, remaining: work, period: .focus, round: Int(groups+1)*4+1)
        }
    }
    func timerEvents(at now: Date, limit: Int = 32) -> [FocusTimerEvent] {
        guard phase == .running, selectedMode != .normal, limit > 0 else { return [] }
        let elapsed=activeElapsed(at: now)
        if selectedMode == .countdown {
            let left=Double(settings.countdownMinutes)*60-elapsed
            return left > 0 ? [FocusTimerEvent(after: left, title: "作業時間になりました", body: "お疲れ様でした。アプリで作業時間を確認できます。")]:[]
        }
        var events=[FocusTimerEvent](), cursor=elapsed
        for _ in 0..<min(32,limit) {
            let current=reading(activeSeconds: cursor)
            guard let left=current.remaining, left > 0 else { break }
            cursor+=left
            if current.period == .focus {
                let minutes=current.round%4 == 0 ? settings.longBreakMinutes:settings.shortBreakMinutes
                events.append(FocusTimerEvent(after: cursor-elapsed, title: "休憩の時間です", body: "\(minutes)分休憩しましょう。休憩時間は育成に含まれません。"))
            } else {
                events.append(FocusTimerEvent(after: cursor-elapsed, title: "休憩が終わりました", body: "次の\(settings.focusMinutes)分の作業をはじめましょう。"))
            }
        }
        return events
    }
    mutating func pause(at now: Date, forReview: Bool = false) {
        accumulated = activeElapsed(at: now)
        resumedAt = nil
        phase = forReview ? .review : .paused
    }
    mutating func resume(at now: Date) {
        guard phase != .running else { return }
        resumedAt = now
        phase = .running
    }
}

struct WorkRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let measuredSeconds: TimeInterval
    let seconds: TimeInterval
    let worldID: String
    var mode: FocusMode? = nil
}

struct SoundMix: Codable, Equatable {
    var enabled: [String: Bool] = ["music": true, "pages": true, "wind": true, "rain": true, "fire": true]
    var volumes: [String: Double] = ["music": 0.32, "pages": 0.25, "wind": 0.30, "rain": 0.45, "fire": 0.40, "embers": 0.25, "bellows": 0.20, "hammer": 0.14, "grinder": 0.13, "clockwork": 0.16]
}

enum SoundKind: String, CaseIterable, Identifiable {
    case music, pages, wind, rain, fire, water, brush, bell, birds, embers, bellows, hammer, grinder, clockwork
    var id: String { rawValue }
    var unlockRank: Int {
        switch self { case .music: 1; case .pages: 2; case .wind: 3; case .rain: 4; case .fire, .birds: 5; case .water: 1; case .brush: 2; case .bell: 4; case .embers: 1; case .bellows: 2; case .hammer: 3; case .grinder: 4; case .clockwork: 5 }
    }
    var title: String {
        switch self { case .music: "BGM"; case .pages: "作業音"; case .wind: "葉擦れ"; case .rain: "雨"; case .fire: "暖炉"; case .water: "水音"; case .brush: "筆音"; case .bell: "鈴"; case .birds: "鳥の声"; case .embers: "炉の火"; case .bellows: "ふいご"; case .hammer: "打鉄"; case .grinder: "研磨輪"; case .clockwork: "時計仕掛け" }
    }
    var icon: String {
        switch self { case .music: "music.note"; case .pages: "keyboard"; case .wind: "wind"; case .rain: "cloud.rain"; case .fire: "flame"; case .water: "water.waves"; case .brush: "pencil.tip"; case .bell: "bell"; case .birds: "bird"; case .embers: "flame"; case .bellows: "wind"; case .hammer: "hammer"; case .grinder: "gearshape"; case .clockwork: "clock" }
    }
}

struct AppData: Codable {
    var version = 1
    var growthSeconds: TimeInterval = 0
    var records: [WorkRecord] = []
    var session: FocusSession?
    var confirmation: ConfirmationMode = .light
    var checkIntervalMinutes = 30
    var mix = SoundMix()
    var displayRank: Int?
    // Optional additions keep version-1 saves decodable without resetting rooftop progress.
    var activeWorldID: String?
    var worlds: [String: WorldProgress]?
    var timerPreferences: FocusTimerSettings?
    var backgroundPlayback: Bool?

    var activeWorld: FocusWorld { FocusWorld(rawValue: activeWorldID ?? "") ?? .rooftop }
    func progress(for world: FocusWorld) -> WorldProgress {
        world == .rooftop ? WorldProgress(growthSeconds: growthSeconds, displayRank: displayRank, mix: mix)
            : worlds?[world.rawValue] ?? WorldProgress()
    }
    mutating func update(_ world: FocusWorld, _ change: (inout WorldProgress) -> Void) {
        var progress = progress(for: world)
        change(&progress)
        if world == .rooftop {
            growthSeconds = progress.growthSeconds
            displayRank = progress.displayRank
            mix = progress.mix
        } else {
            if worlds == nil { worlds = [:] }
            worlds?[world.rawValue] = progress
        }
    }
}

struct WorldProgress: Codable, Equatable {
    var growthSeconds: TimeInterval = 0
    var displayRank: Int?
    var mix = SoundMix()
    var rank: Int { RooftopWorld.rank(for: growthSeconds) }
    var displayedRank: Int { min(rank, max(1, displayRank ?? rank)) }
}

enum FocusWorld: String, Codable, CaseIterable, Identifiable {
    case rooftop = "quiet-library"
    case shrine = "shrine-of-one-more"
    case shellHarbor = "shell-harbor"
    case emberWorkshop = "ember-workshop"
    var id: String { rawValue }
    var title: String {
        switch self { case .rooftop: RooftopWorld.title; case .shrine: "幾重の社"; case .shellHarbor: "貝殻の小さな海"; case .emberWorkshop: "火種の工房" }
    }
    func name(at rank: Int) -> String {
        switch self {
        case .rooftop: rank < 3 ? "まだ名のない場所" : title
        case .shrine: rank < 4 ? "水音のする世界" : title
        case .shellHarbor, .emberWorkshop: title
        }
    }
    var usesLightCanvas: Bool { self == .shellHarbor }
    var artworkSize: CGSize {
        switch self {
        case .rooftop: RooftopWorld.artworkSize
        case .shrine: CGSize(width: 600, height: 1300)
        case .shellHarbor: CGSize(width: 642, height: 882)
        case .emberWorkshop: CGSize(width: 512, height: 768)
        }
    }
    func artworkSize(for rank: Int) -> CGSize {
        self == .emberWorkshop && (3...4).contains(rank) ? CGSize(width: 600, height: 656) : artworkSize
    }
    var artwork: CollectionEntry.Artwork {
        switch self { case .rooftop: .rooftop; case .shrine: .shrine; case .shellHarbor: .shellHarbor; case .emberWorkshop: .emberWorkshop }
    }
    var resourcePrefix: String {
        switch self { case .rooftop: "rooftop"; case .shrine: "shrine"; case .shellHarbor: "shell-harbor"; case .emberWorkshop: "ember-workshop" }
    }
    func resource(for rank: Int) -> String {
        "\(resourcePrefix)-rank-\(min(5, max(1, rank)))"
    }
    var sounds: [SoundKind] {
        switch self {
        case .rooftop: [.music, .pages, .wind, .rain, .fire]
        case .shrine: [.music, .water, .brush, .wind, .bell, .birds]
        case .shellHarbor: [.music, .water, .wind, .birds]
        case .emberWorkshop: [.music, .embers, .bellows, .hammer, .grinder, .clockwork]
        }
    }
    func unlockRank(for sound: SoundKind) -> Int {
        self == .shellHarbor && sound == .birds ? 3 : sound.unlockRank
    }
    var story: CollectionStory? {
        switch self { case .rooftop: .rooftop; case .shrine: .shrine; case .shellHarbor, .emberWorkshop: nil }
    }
    func accessibilityDescription(rank: Int) -> String {
        switch self {
        case .rooftop: rank == 1 ? "暗闇に小さな灯りが浮かぶ世界" : rank < 4 ? "屋上で女の子が作業する世界" : "ネオンの街を見下ろす屋上の世界"
        case .shrine: rank == 1 ? "水面に紅葉が浮かぶ世界" : rank == 2 ? "狐の面をつけた女の子が筆で仕事をする世界" : rank == 3 ? "狐がくつろぐ参道と小さな社務所" : rank == 4 ? "鳥居と社殿を紅葉が舞う世界" : "空へ重なる神秘的な神社の世界"
        case .emberWorkshop:
            switch min(5, max(1, rank)) {
            case 1: "黒い円台に赤い火種と煙が浮かぶ箱庭"
            case 2: "レンガの炉でふいごが動く小さな工房"
            case 3: "小さな車輪と鍛造機が鉄を打つ工房"
            case 4: "屋根と研磨輪が揃い、機械が動く修理工房"
            default: "工房から育ったからくり時計塔。振り子と歯車、鐘が動く箱庭"
            }
        case .shellHarbor:
            switch min(5, max(1, rank)) {
            case 1: "白い円台の上で貝殻から小さな水たまりへ水が流れる箱庭"
            case 2: "貝殻の入り江が広がり、魚が跳ねる箱庭"
            case 3: "貝殻が丘へ育ち、木々と小鳥が暮らす箱庭"
            case 4: "家々と桟橋ができ、舟の上で釣りをする小さな港"
            default: "灯台と石橋のある港町。人々が暮らし、島を囲む海を船が進む箱庭"
            }
        }
    }
}

enum RooftopWorld {
    // Keep saved record identity and existing progress when replacing prototype art.
    static let id = "quiet-library"
    static let title = "ネオンの向こうの屋上"
    static let artworkSize = CGSize(width: 438, height: 900)
    static let aspectRatio = artworkSize.width / artworkSize.height
    static let stageDuration: TimeInterval = 25 * 60
    static let completionSeconds: TimeInterval = 4 * stageDuration

    static func rank(for seconds: TimeInterval) -> Int {
        min(5, max(1, Int(max(0, seconds) / stageDuration) + 1))
    }
    static func progress(for seconds: TimeInterval, rank: Int) -> Double {
        guard rank < 5 else { return 1 }
        return min(1, max(0, (seconds - Double(rank - 1) * stageDuration) / stageDuration))
    }
    static func remaining(for seconds: TimeInterval, rank: Int) -> TimeInterval {
        guard rank < 5 else { return 0 }
        return max(0, Double(rank) * stageDuration - seconds)
    }
    static func resource(for rank: Int) -> String { "rooftop-rank-\(min(5, max(1, rank)))" }
}

struct SessionResult: Identifiable {
    let id = UUID()
    var world: FocusWorld = .rooftop
    let creditedSeconds: TimeInterval
    let previousRank: Int
    let newRank: Int
    let previousGrowthSeconds: TimeInterval
    let growthSeconds: TimeInterval
    var evolved: Bool { newRank > previousRank }
    var completed: Bool { evolved && newRank == 5 }

    struct GrowthStep {
        let rank: Int
        let start: Double
        let end: Double
    }
    /// Each crossed stage is shown separately, including a partially filled final stage.
    var growthSteps: [GrowthStep] {
        (1...4).compactMap { rank in
            let start = RooftopWorld.progress(for: previousGrowthSeconds, rank: rank)
            let end = RooftopWorld.progress(for: growthSeconds, rank: rank)
            return end > start ? GrowthStep(rank: rank, start: start, end: end) : nil
        }
    }
}

/// Presentation data is separate from saved work records and growth state.
struct CollectionEntry: Identifiable, Equatable {
    enum Artwork: Equatable {
        case rooftop
        case shrine
        case shellHarbor
        case emberWorkshop
        case animation(String, CGSize)
        case image(String, CGSize)

        var size: CGSize {
            switch self {
            case .rooftop: RooftopWorld.artworkSize
            case .shrine: FocusWorld.shrine.artworkSize
            case .shellHarbor: FocusWorld.shellHarbor.artworkSize
            case .emberWorkshop: FocusWorld.emberWorkshop.artworkSize
            case .animation(_, let size), .image(_, let size): size
            }
        }
    }
    let id: String
    let title: String
    let rank: Int
    let artwork: Artwork
    var world: FocusWorld? { FocusWorld(rawValue: id) }
    var isSample: Bool { world == nil }
    func artworkSize(at rank: Int? = nil) -> CGSize {
        world?.artworkSize(for: rank ?? self.rank) ?? artwork.size
    }

    #if DEBUG
    static let debugSamples: [CollectionEntry] = [
        .init(id: "debug-library", title: "雨音の書斎", rank: 5,
              artwork: .animation("debug-collection-library", CGSize(width: 836, height: 471))),
        .init(id: "debug-flowers", title: "路地裏の花工房", rank: 5,
              artwork: .image("debug-collection-flowers", CGSize(width: 852, height: 1846))),
        .init(id: "debug-forest", title: "森の薬草室", rank: 5,
              artwork: .image("debug-collection-forest", CGSize(width: 852, height: 1846))),
        .init(id: "debug-moon", title: "月明かりの地図室", rank: 5,
              artwork: .image("debug-collection-moon", CGSize(width: 852, height: 1846))),
        .init(id: "debug-mountain", title: "山あいの観測小屋", rank: 5,
              artwork: .image("debug-collection-mountain", CGSize(width: 852, height: 1846)))
    ]
    #endif
}

enum TimeText {
    static func clock(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds >= 3_600 {
            return String(format: "%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60)
        }
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
    static func duration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds)秒" }
        if seconds < 3_600 { return "\(seconds / 60)分" }
        let hours = seconds / 3_600, minutes = seconds / 60 % 60
        return minutes == 0 ? "\(hours)時間" : "\(hours)時間\(minutes)分"
    }
    static func preciseDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        guard seconds >= 60 else { return "\(seconds)秒" }
        let remainder = seconds % 60
        return duration(interval) + (remainder > 0 ? "\(remainder)秒" : "")
    }
}
