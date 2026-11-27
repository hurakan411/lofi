import XCTest
@testable import Lofi

final class SpectrumTests: XCTestCase {
    private func tone(_ frequency: Double, rate: Double = 24_000) -> SpectrumAudioSource {
        SpectrumAudioSource(samples: (0..<Int(rate / 5)).map {
            Float(sin(2 * Double.pi * frequency * Double($0) / rate)) * 0.2
        }, sampleRate: rate)
    }

    func testSpectrumAnalyzesTheCombinedWaveformAndAppliesEachVolume() throws {
        let first = tone(187.5), second = tone(1_500)
        let mixed = try XCTUnwrap(MusicSpectrum()).bands(inputs: [
            .init(source: first, time: 0, volume: 0.3),
            .init(source: second, time: 0, volume: 0.7)
        ])
        let combined = SpectrumAudioSource(samples: zip(first.samples, second.samples).map { $0 * 0.3 + $1 * 0.7 }, sampleRate: 24_000)
        let expected = try XCTUnwrap(MusicSpectrum()).bands(inputs: [.init(source: combined, time: 0, volume: 1)])
        for (actual, reference) in zip(mixed, expected) { XCTAssertEqual(actual, reference, accuracy: 0.00001) }
        let quiet = try XCTUnwrap(MusicSpectrum()).bands(inputs: [.init(source: first, time: 0, volume: 0.03)])
        let loud = try XCTUnwrap(MusicSpectrum()).bands(inputs: [.init(source: first, time: 0, volume: 0.8)])
        XCTAssertGreaterThan(loud.reduce(0,+), quiet.reduce(0,+))
        let analyzer = try XCTUnwrap(MusicSpectrum())
        XCTAssertEqual(analyzer.bands(inputs: [.init(source: first, time: 0, volume: 0)]), [Float](repeating: 0, count: 48))
        _ = analyzer.bands(inputs: [.init(source: first, time: 0, volume: 1)])
        XCTAssertEqual(analyzer.bands(inputs: []), [Float](repeating: 0, count: 48))
    }

    func testOneShotDoesNotWrapAfterItsEndAndDifferentSampleRatesWork() throws {
        let source = tone(1_500, rate: 48_000)
        let stopped = try XCTUnwrap(MusicSpectrum()).bands(inputs: [.init(source: source, time: 1, volume: 1, loops: false)])
        XCTAssertTrue(stopped.allSatisfy { $0 == 0 })
        let looping = try XCTUnwrap(MusicSpectrum()).bands(inputs: [.init(source: source, time: 1, volume: 1)])
        XCTAssertTrue(looping.contains { $0 > 0 })
        XCTAssertTrue(looping.allSatisfy { $0.isFinite && (0...1).contains($0) })
    }

    func testAllAppSoundAssetsCanParticipateInTheSpectrum() throws {
        let bundle = Bundle(for: FocusStore.self)
        for name in SoundKind.allCases.map(\.rawValue) + ["timer-chime"] {
            let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "wav"))
            let source = try XCTUnwrap(SpectrumAudioSource(url: url), name)
            XCTAssertFalse(source.samples.isEmpty, name)
            XCTAssertGreaterThan(source.sampleRate, 0, name)
        }
    }

    @MainActor func testAmbienceAndChimeMoveSpectrumWithMusicOffAndSilenceClearsIt() async throws {
        let audio = SoundscapePlayer()
        var silent = SoundMix()
        for kind in SoundKind.allCases { silent.enabled[kind.rawValue] = false }
        defer { audio.setSpectrumActive(false); try? audio.update(mix: silent, rank: 3) }
        audio.setSpectrumActive(true)
        var ambience = silent
        ambience.enabled[SoundKind.wind.rawValue] = true
        ambience.volumes[SoundKind.wind.rawValue] = 0.5
        try audio.update(mix: ambience, rank: 3)
        try await Task.sleep(for: .milliseconds(450))
        audio.refreshSpectrum()
        XCTAssertFalse(audio.isMusicPlaying)
        XCTAssertTrue(audio.isAudioPlaying)
        XCTAssertEqual(audio.playbackTitle, "環境音")
        XCTAssertTrue(audio.spectrum.contains { $0 > 0 })
        try audio.update(mix: silent, rank: 3)
        XCTAssertFalse(audio.isAudioPlaying)
        XCTAssertTrue(audio.spectrum.allSatisfy { $0 == 0 })
        audio.playChime()
        audio.refreshSpectrum()
        XCTAssertFalse(audio.isMusicPlaying)
        XCTAssertTrue(audio.isAudioPlaying)
        XCTAssertEqual(audio.playbackTitle, "お知らせ")
        XCTAssertTrue(audio.spectrum.contains { $0 > 0 })
        try await Task.sleep(for: .milliseconds(1_350))
        audio.refreshSpectrum()
        XCTAssertFalse(audio.isAudioPlaying)
        XCTAssertTrue(audio.spectrum.allSatisfy { $0 == 0 })
    }
}
