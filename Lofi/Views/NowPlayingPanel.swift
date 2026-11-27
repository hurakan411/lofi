import SwiftUI

struct NowPlayingPanel: View {
    @ObservedObject var audio: SoundscapePlayer
    let isActive: Bool
    var darkOnLight = false
    let onSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onSettings) {
            ZStack(alignment: .trailing) {
                if audio.isAudioPlaying {
                    Canvas { context, size in
                        let center = CGPoint(x: size.width, y: size.height/2)
                        let radius: CGFloat = 86
                        let levels = audio.spectrum
                        let count = levels.count
                        for index in 0..<count {
                            let angle = -.pi/2 - Double(index)/Double(max(1, count-1)) * .pi
                            let amount = isActive && !reduceMotion ? CGFloat(levels[index]) : 0
                            let length: CGFloat = 2 + pow(amount, 1.1) * 44
                            let inner = CGPoint(x: center.x + cos(angle)*radius, y: center.y + sin(angle)*radius)
                            let outer = CGPoint(x: center.x + cos(angle)*(radius+length), y: center.y + sin(angle)*(radius+length))
                            var line = Path(); line.move(to: inner); line.addLine(to: outer)
                            context.stroke(line, with: .color((darkOnLight ? Color.black : .white).opacity(darkOnLight ? 0.36 : 0.52)),
                                           style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                        }
                    }
                    .frame(width: 190, height: 272)
                    .accessibilityHidden(true)
                    VStack(alignment: .trailing, spacing: 5) {
                        Text(audio.playbackTitle)
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .tracking(0.4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .multilineTextAlignment(.trailing)
                        Text("NOW PLAYING")
                            .font(.system(size: 7, weight: .medium))
                            .tracking(1.8)
                            .foregroundStyle((darkOnLight ? Color.black : .white).opacity(0.46))
                    }
                    .frame(width: 142, alignment: .trailing)
                    .padding(.trailing, 8)
                    .foregroundStyle((darkOnLight ? Color.black : .white).opacity(darkOnLight ? 0.78 : 0.90))
                    .shadow(color: .black.opacity(darkOnLight ? 0 : 0.9), radius: 5)
                } else {
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 7) {
                            Image(systemName: "speaker.slash.fill")
                                .font(.system(size: 13, weight: .medium))
                            Text("音を調整")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Palette.text)
                        Text("すべての音がオフ")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Palette.text.opacity(0.70))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background { WorkLegibilityBackground(shape: RoundedRectangle(cornerRadius: 18)) }
                }
            }
            .frame(width: audio.isAudioPlaying ? 190 : nil,
                   height: audio.isAudioPlaying ? 272 : nil, alignment: .trailing)
            .clipped()
            .contentShape(RoundedRectangle(cornerRadius: audio.isAudioPlaying ? 0 : 18))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(audio.isAudioPlaying ? "\(audio.playbackTitle)、再生中" : "音を調整、すべての音がオフ")
        .accessibilityHint("タップしてBGMと環境音の設定を開きます")
        .accessibilityIdentifier("soundSettings")
        .padding(.trailing, audio.isAudioPlaying ? 0 : 10)
        .onAppear { audio.setSpectrumActive(isActive && !reduceMotion) }
        .onChange(of: isActive) { _, active in audio.setSpectrumActive(active && !reduceMotion) }
        .onChange(of: reduceMotion) { _, reduced in audio.setSpectrumActive(isActive && !reduced) }
        .onDisappear { audio.setSpectrumActive(false) }
    }
}
