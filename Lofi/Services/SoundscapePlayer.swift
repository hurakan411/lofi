import AVFoundation
import Combine

@MainActor
final class SoundscapePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    let trackTitle = "Night Signal"
    @Published private(set) var spectrum = [Float](repeating: 0, count: MusicSpectrum.bandCount)
    @Published private(set) var isMusicPlaying = false
    @Published private(set) var isAudioPlaying = false
    private let analyzer = MusicSpectrum()
    private var sources: [SoundKind: SpectrumAudioSource] = [:]
    private var spectrumTimer: Timer?
    private var spectrumActive = false
    private var players: [SoundKind: AVAudioPlayer] = [:]
    private var chime: AVAudioPlayer?
    private var chimeSource: SpectrumAudioSource?
    private var configured = false
    private var playbackAllowed = true
    private var interruptions: NSObjectProtocol?

    var playbackTitle: String {
        isMusicPlaying ? trackTitle : (players.values.contains { $0.isPlaying && $0.volume > 0 } ? "環境音" : "お知らせ")
    }

    override init() {
        super.init()
        interruptions = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification,
            object: nil, queue: .main) { [weak self] notification in
            let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init(rawValue:))
            let options = AVAudioSession.InterruptionOptions(rawValue: notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0)
            Task { @MainActor in
                if type == .ended, options.contains(.shouldResume), self?.playbackAllowed == true {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    self?.players.values.filter { $0.volume > 0 }.forEach { $0.play() }
                }
                self?.refreshSpectrum()
            }
        }
    }
    deinit {
        spectrumTimer?.invalidate()
        if let interruptions { NotificationCenter.default.removeObserver(interruptions) }
    }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try AVAudioSession.sharedInstance().setActive(true)
        configured = true
    }

    func update(mix: SoundMix, rank: Int, world: FocusWorld = .rooftop) throws {
        guard playbackAllowed else { return }
        try configureIfNeeded()
        for sound in SoundKind.allCases {
            let shouldPlay = world.sounds.contains(sound) && rank >= world.unlockRank(for: sound) && (mix.enabled[sound.rawValue] ?? true)
            if shouldPlay {
                if players[sound] == nil {
                    guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
                        throw CocoaError(.fileNoSuchFile)
                    }
                    let player = try AVAudioPlayer(contentsOf: url)
                    player.numberOfLoops = -1
                    player.prepareToPlay()
                    players[sound] = player
                    sources[sound] = SpectrumAudioSource(url: url)
                }
                let player = players[sound]!
                player.setVolume(Float(mix.volumes[sound.rawValue] ?? 0.4), fadeDuration: 0.35)
                if !player.isPlaying { player.play() }
            } else {
                players[sound]?.stop()
                players[sound]?.volume = 0
            }
        }
        updateSpectrumPlayback()
    }

    func setPlaybackAllowed(_ allowed: Bool) {
        guard playbackAllowed != allowed else { return }
        playbackAllowed = allowed
        if !allowed { stopAll() }
    }

    /// End the previous screen's playback before another screen takes ownership.
    func stopAll() {
        for player in players.values {
            player.stop()
            player.volume = 0
        }
        players.removeAll()
        sources.removeAll()
        chime?.stop()
        refreshSpectrum()
    }

    var playingSounds: Set<SoundKind> {
        Set(players.compactMap { $0.value.isPlaying ? $0.key : nil })
    }

    /// The same mixer owns short effects so they participate in the spectrum too.
    func playChime() {
        guard playbackAllowed else { return }
        do {
            try configureIfNeeded()
            if chime == nil {
                guard let url = Bundle.main.url(forResource: "timer-chime", withExtension: "wav") else { return }
                chime = try AVAudioPlayer(contentsOf: url)
                chime?.delegate = self
                chimeSource = SpectrumAudioSource(url: url)
            }
            chime?.currentTime = 0
            chime?.volume = 0.45
            chime?.play()
            updateSpectrumPlayback()
        } catch { return }
    }

    private func updateSpectrumPlayback() {
        refreshSpectrum()
        guard spectrumActive, spectrumTimer == nil else { return }
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshSpectrum() }
        }
        RunLoop.main.add(timer, forMode: .common)
        spectrumTimer = timer
    }

    func refreshSpectrum() {
        var inputs = [MusicSpectrum.Input]()
        let musicPlaying = players[.music]?.isPlaying == true && (players[.music]?.volume ?? 0) > 0
        var anyPlaying = false
        for (sound, player) in players where player.isPlaying && player.volume > 0 {
            anyPlaying = true
            if spectrumActive, (!musicPlaying || sound == .music), let source = sources[sound] {
                inputs.append(.init(source: source, time: player.currentTime, volume: player.volume))
            }
        }
        if let chime, chime.isPlaying, chime.volume > 0 {
            anyPlaying = true
            if spectrumActive, !musicPlaying, let source = chimeSource {
                inputs.append(.init(source: source, time: chime.currentTime, volume: chime.volume, loops: false))
            }
        }
        if isMusicPlaying != musicPlaying { isMusicPlaying = musicPlaying }
        if isAudioPlaying != anyPlaying { isAudioPlaying = anyPlaying }
        if spectrumActive {
            spectrum = analyzer?.bands(inputs: inputs) ?? [Float](repeating: 0, count: MusicSpectrum.bandCount)
        } else if !anyPlaying && spectrum.contains(where: { $0 > 0 }) {
            spectrum = [Float](repeating: 0, count: MusicSpectrum.bandCount)
        }
    }

    func setSpectrumActive(_ active: Bool) {
        spectrumActive = active
        if active {
            updateSpectrumPlayback()
        } else {
            spectrumTimer?.invalidate()
            spectrumTimer = nil
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.refreshSpectrum() }
    }
}
