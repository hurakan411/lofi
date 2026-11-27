import Accelerate
import AVFoundation

/// Decoded PCM is cached once per bundled sound, independently of playback.
struct SpectrumAudioSource {
    let samples: [Float]
    let sampleRate: Double

    init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    init?(url: URL) {
        guard let file = try? AVAudioFile(forReading: url),
              file.length > 0, file.length <= Int64(UInt32.max),
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buffer)) != nil,
              let channels = buffer.floatChannelData, buffer.format.channelCount > 0 else { return nil }
        sampleRate = file.processingFormat.sampleRate
        let count = Int(buffer.frameLength)
        if buffer.format.channelCount == 1 {
            samples = Array(UnsafeBufferPointer(start: channels[0], count: count))
        } else {
            var mono = [Float](repeating: 0, count: count)
            let gain = 1 / Float(buffer.format.channelCount)
            for channel in 0..<Int(buffer.format.channelCount) {
                for index in 0..<count { mono[index] += channels[channel][index] * gain }
            }
            samples = mono
        }
    }
}

/// Mix each player's PCM at its own playback position and gain, then analyze
/// the combined signal with one reusable DFT. No audio route changes are needed.
final class MusicSpectrum {
    struct Input {
        let source: SpectrumAudioSource
        let time: TimeInterval
        let volume: Float
        var loops = true
    }
    static let bandCount = 48
    private let size = 1024
    private let sampleRate = 24_000.0
    private let setup: vDSP_DFT_Setup
    private var window = [Float](repeating: 0, count: 1024)
    private var input = [Float](repeating: 0, count: 1024)
    private var imaginary = [Float](repeating: 0, count: 1024)
    private var realOutput = [Float](repeating: 0, count: 1024)
    private var imaginaryOutput = [Float](repeating: 0, count: 1024)
    private var smoothed = [Float](repeating: 0, count: bandCount)

    init?() {
        guard let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(size), .FORWARD) else { return nil }
        self.setup = setup
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
    }
    deinit { vDSP_DFT_DestroySetup(setup) }

    func bands(inputs: [Input]) -> [Float] {
        let audible = inputs.filter { $0.volume > 0 && $0.volume.isFinite && $0.time.isFinite &&
            !$0.source.samples.isEmpty && $0.source.sampleRate > 0 && $0.source.sampleRate.isFinite }
        guard !audible.isEmpty else {
            smoothed = [Float](repeating: 0, count: Self.bandCount)
            return smoothed
        }
        for index in 0..<size { input[index] = 0 }
        for track in audible {
            let samples = track.source.samples
            let count = samples.count
            let rate = track.source.sampleRate
            let start = max(0, track.time) * rate
            for index in 0..<size {
                let position = start + Double(index) * rate / sampleRate
                if !track.loops && position >= Double(count) { break }
                let wrapped = position.truncatingRemainder(dividingBy: Double(count))
                let first = Int(wrapped)
                let next = first + 1 < count ? first + 1 : (track.loops ? 0 : first)
                let fraction = Float(wrapped - Double(first))
                input[index] += (samples[first] + (samples[next] - samples[first]) * fraction) * track.volume
            }
        }
        for index in 0..<size { input[index] = min(1, max(-1, input[index])) * window[index] }
        vDSP_DFT_Execute(setup, input, imaginary, &realOutput, &imaginaryOutput)
        for band in 0..<Self.bandCount {
            let low = 45 * pow(180.0, Double(band) / Double(Self.bandCount))
            let high = 45 * pow(180.0, Double(band+1) / Double(Self.bandCount))
            let first = max(1, Int(low * Double(size) / sampleRate))
            let last = min(size/2-1, max(first, Int(high * Double(size) / sampleRate)))
            var peak: Float = 0
            for bin in first...last {
                peak = max(peak, hypot(realOutput[bin], imaginaryOutput[bin]) / Float(size))
            }
            let level = min(1, max(0, (20 * log10(max(peak, 0.00001)) + 78) / 60))
            smoothed[band] += (level-smoothed[band]) * (level > smoothed[band] ? 0.7 : 0.19)
        }
        return smoothed
    }
}
