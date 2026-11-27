import SwiftUI

struct SoundsSheet: View {
    static let detents: Set<PresentationDetent> = [.height(440), .large]
    @ObservedObject var store: FocusStore
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heading
                musicControls
                VStack(spacing: 8) {
                    ForEach(store.availableSounds.filter { $0 != .music }) { sound in
                        soundRow(sound)
                    }
                }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 24).padding(.vertical, 20)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Palette.text)
        .accessibilityIdentifier("soundMixer")
    }

    private var heading: some View {
        HStack {
            Text("この場所の音")
                .font(.system(size: 21, weight: .medium))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Palette.text.opacity(0.55))
                    .frame(width: 32, height: 32)
                    .background(.white.opacity(0.045), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
        }
    }

    private var musicControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                soundButton(.music)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BGM").font(.system(size: 15, weight: .medium))
                    Text(store.audio.trackTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.text.opacity(0.50))
                }
                Spacer()
                Button { store.toggleSound(.music) } label: {
                    Image(systemName: store.soundEnabled(.music) ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.accent)
                        .frame(width: 34, height: 34)
                        .overlay { Circle().strokeBorder(Palette.accent.opacity(0.85), lineWidth: 1) }
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.soundEnabled(.music) ? "BGMを停止" : "BGMを再生")
                .accessibilityIdentifier("toggleMusic")
            }
            HStack(spacing: 12) {
                volumeSlider(.music)
                percentage(.music)
            }
        }
    }

    private func soundRow(_ sound: SoundKind) -> some View {
        let unlocked = store.isSoundUnlocked(sound)
        return HStack(spacing: 8) {
            soundButton(sound)
            Text(unlocked ? sound.title : "未解禁")
                .font(.system(size: 13))
                .foregroundStyle(Palette.text.opacity(unlocked ? 0.9 : 0.30))
                .lineLimit(1).minimumScaleFactor(0.85)
                .frame(width: 50, alignment: .leading)
            volumeSlider(sound)
            percentage(sound)
        }
        .frame(minHeight: 44)
    }

    private func soundButton(_ sound: SoundKind) -> some View {
        let unlocked = store.isSoundUnlocked(sound)
        let enabled = unlocked && store.soundEnabled(sound)
        return Button { store.toggleSound(sound) } label: {
            Image(systemName: unlocked ? sound.icon : "lock")
                .font(.system(size: sound == .music ? 21 : 18, weight: .light))
                .foregroundStyle(enabled ? Palette.accent : Palette.text.opacity(unlocked ? 0.42 : 0.20))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityLabel(unlocked ? "\(sound.title)のオン・オフ" : "ランク\(store.audioWorld.unlockRank(for: sound))で見つかる音")
        .accessibilityValue(unlocked ? (enabled ? "オン" : "オフ") : "未解禁")
        .accessibilityIdentifier("toggleSound_\(sound.rawValue)")
    }

    private func volumeSlider(_ sound: SoundKind) -> some View {
        let unlocked = store.isSoundUnlocked(sound)
        let enabled = unlocked && store.soundEnabled(sound)
        return SoundVolumeRuler(
            value: Binding(get: { enabled ? store.soundVolume(sound) : 0 },
                           set: { store.setVolume($0, for: sound) }),
            isEnabled: unlocked,
            isActive: enabled,
            label: unlocked ? "\(sound.title)の音量" : "未解禁の音量"
        )
        .accessibilityIdentifier("soundVolume_\(sound.rawValue)")
    }

    private func percentage(_ sound: SoundKind) -> some View {
        let unlocked = store.isSoundUnlocked(sound)
        let enabled = unlocked && store.soundEnabled(sound)
        return Text(unlocked ? "\(Int((enabled ? store.soundVolume(sound) : 0) * 100))%" : "—")
            .font(.system(size: 11)).monospacedDigit()
            .foregroundStyle(Palette.text.opacity(unlocked ? 0.56 : 0.22))
            .frame(width: 34, alignment: .trailing)
            .accessibilityHidden(true)
    }
}

/// Native material samples the actual view underneath the sheet, including animation.
struct SoundSheetBackground: View {
    var lightBackdrop = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                Palette.surface
            } else {
                Rectangle().fill(.ultraThinMaterial)
                    .opacity(0.12)
                    .overlay(Color(red: 0.18, green: 0.23, blue: 0.31).opacity(0.04))
                    .overlay(.black.opacity(lightBackdrop ? 0.66 : 0))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 32)
                .strokeBorder(.white.opacity(reduceTransparency ? 0 : 0.07), lineWidth: 0.5)
        }
        .ignoresSafeArea()
    }
}

private struct SoundVolumeRuler: View {
    @Binding var value: Double
    let isEnabled: Bool
    let isActive: Bool
    let label: String

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = 5
            let length = max(1, geometry.size.width - inset * 2)
            let level = min(1, max(0, value))
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    var rail = Path()
                    rail.move(to: CGPoint(x: inset, y: 17))
                    rail.addLine(to: CGPoint(x: inset + length, y: 17))
                    context.stroke(rail, with: .color(Palette.text.opacity(0.18)),
                                   style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    if isActive {
                        var filled = Path()
                        filled.move(to: CGPoint(x: inset, y: 17))
                        filled.addLine(to: CGPoint(x: inset + length * level, y: 17))
                        context.stroke(filled, with: .color(Palette.accent),
                                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    }
                    for index in 0...10 {
                        let x = inset + length * CGFloat(index) / 10
                        var tick = Path()
                        tick.move(to: CGPoint(x: x, y: 25))
                        tick.addLine(to: CGPoint(x: x, y: index.isMultiple(of: 5) ? 31 : 28))
                        context.stroke(tick, with: .color(Palette.text.opacity(isActive ? 0.38 : 0.16)),
                                       lineWidth: 0.7)
                    }
                }
                Circle()
                    .fill(isActive ? Palette.accent : Palette.text.opacity(0.42))
                    .frame(width: 10, height: 10)
                    .position(x: inset + length * level, y: 17)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        guard isEnabled else { return }
                        value = Double(min(1, max(0, (drag.location.x - inset) / length)))
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(Int(value * 100))パーセント")
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            switch direction {
            case .increment: value = min(1, value + 0.05)
            case .decrement: value = max(0, value - 0.05)
            @unknown default: break
            }
        }
        .disabled(!isEnabled)
    }
}

struct ReviewSheet: View {
    @ObservedObject var store: FocusStore
    @State private var deductSeconds: Double = 0
    #if DEBUG
    @State private var debugMinutes = ""
    @State private var debugSeconds = ""
    private var debugDuration: TimeInterval? {
        guard let minutes = Int(debugMinutes), let seconds = Int(debugSeconds),
              minutes >= 0, (0...59).contains(seconds), minutes < Int.max / 240 else { return nil }
        return Double(minutes) * 60 + Double(seconds)
    }
    #endif
    private var maximum: Double { max(0, floor(store.elapsed)) }
    private var shortSession: Bool { maximum < 60 }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("作業時間を確認").font(.system(size: 21, weight: .medium))
                    Spacer()
                    if store.canResume {
                        Button("作業に戻る") { store.resume() }.font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                }
                VStack(spacing: 8) {
                    Text(TimeText.clock(store.elapsed)).font(.system(size: 44, weight: .regular, design: .rounded)).monospacedDigit()
                    if store.sessionMode == .pomodoro {
                        Text("休憩時間を除いた作業時間です").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    Text("この時間、作業できていましたか？").font(.system(size: 13)).foregroundStyle(Palette.muted)
                }.frame(maxWidth: .infinity).padding(.vertical, 8)
                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("DEBUG · 反映する作業時間").font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.accent)
                    HStack {
                        TextField("分", text: $debugMinutes)
                            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("反映する作業時間の分").accessibilityIdentifier("debugMinutes")
                        Text("分")
                        TextField("秒", text: $debugSeconds)
                            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                            .accessibilityLabel("反映する作業時間の秒").accessibilityIdentifier("debugSeconds")
                        Text("秒")
                    }
                    Text("計測時間を超える値も入力できます。記録と育成の両方に反映します。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                    if debugDuration == nil {
                        Text("分は0以上の整数、秒は0〜59で入力してください。")
                            .font(.system(size: 12)).foregroundStyle(.orange)
                    }
                }.padding(18).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18))
                Button("作業した時間を反映") {
                    if let seconds = debugDuration { store.commitDebugTime(seconds: seconds) }
                }
                .buttonStyle(PrimaryButtonStyle()).disabled(debugDuration == nil)
                .accessibilityIdentifier("confirmTime")
                #else
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("作業していなかった時間").font(.system(size: 13))
                        Spacer()
                        Text(TimeText.duration(deductSeconds)).font(.system(size: 13)).monospacedDigit().foregroundStyle(Palette.accent)
                    }
                    Slider(value: $deductSeconds, in: 0...max(1, maximum), step: shortSession ? 1 : 60)
                        .tint(Palette.accent).accessibilityLabel("作業していなかった時間")
                    HStack {
                        Text("反映する時間").foregroundStyle(Palette.muted)
                        Spacer()
                        Text(TimeText.duration(maximum - min(maximum, deductSeconds)))
                    }.font(.system(size: 12))
                }.padding(18).background(Palette.elevated, in: RoundedRectangle(cornerRadius: 18))
                Button("作業した時間を反映") { store.commit(deducting: min(maximum, deductSeconds)) }
                    .buttonStyle(PrimaryButtonStyle()).accessibilityIdentifier("confirmTime")
                #endif
                Button("今回は記録しない") { store.discardSession() }
                    .font(.system(size: 13)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity).frame(minHeight: 44)
            }.padding(24)
        }
        .foregroundStyle(Palette.text)
        .interactiveDismissDisabled()
        #if DEBUG
        .onAppear {
            let seconds = Int(maximum)
            debugMinutes = String(seconds / 60)
            debugSeconds = String(seconds % 60)
        }
        #endif
    }
}

struct ResultSheet: View {
    @ObservedObject var store: FocusStore
    let onHeightChange: (CGFloat) -> Void
    let close: () -> Void
    @State private var showingStory = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("お疲れ様でした")
                    .font(.system(size: 25, weight: .medium, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) { rule }
                VStack(spacing: 15) {
                    if let result = store.result {
                        ResultGrowthProgress(result: result)
                            .id(result.id)
                        Text(message)
                            .font(.system(size: 19, weight: .medium, design: .serif))
                            .multilineTextAlignment(.center)
                        if result.newRank < 5 && result.creditedSeconds > 0 {
                            Text("次の進化まであと\(Int(ceil(RooftopWorld.remaining(for: result.growthSeconds, rank: result.newRank) / 60)))分")
                                .font(.system(size: 12))
                                .foregroundStyle(Palette.text.opacity(0.72))
                        }
                        if result.evolved && result.world.story != nil {
                            Button { showingStory = true } label: {
                                Text("物語の続きを見る")
                                    .font(.system(size: 13, weight: .medium))
                                    .underline(pattern: .solid, color: Palette.accent.opacity(0.65))
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("resultStory")
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                HStack {
                    Text("今回の作業").font(.system(size: 14))
                    Spacer()
                    Text(TimeText.preciseDuration(store.result?.creditedSeconds ?? 0))
                        .font(.system(size: 22, weight: .medium, design: .serif))
                        .monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .accessibilityIdentifier("resultCreditedTime")
                }
                .padding(.vertical, 12)
                .overlay(alignment: .top) { rule }
                .overlay(alignment: .bottom) { rule }
                Button("閉じる", action: close)
                    .buttonStyle(PrimaryButtonStyle(height: 52))
                    .accessibilityIdentifier("closeResult")
            }
            .foregroundStyle(Palette.text)
            .shadow(color: .black.opacity(0.65), radius: 5, y: 1)
            .frame(maxWidth: 560)
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: ResultContentHeightKey.self, value: geometry.size.height)
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(ResultContentHeightKey.self) { height in
            guard height > 0 else { return }
            // Reserve room for the native sheet handle above the measured content.
            onHeightChange(ceil(height + 20))
        }
        .sheet(isPresented: $showingStory) {
            if let result = store.result, let story = result.world.story {
                CollectionStorySheet(story: story, unlockedRank: result.newRank, initialRank: result.newRank)
            }
        }
        .onDisappear { if !showingStory { store.result = nil } }
    }
    private var rule: some View {
        Rectangle().fill(Palette.accent.opacity(0.45)).frame(height: 0.7)
    }
    private var message: String {
        guard let result = store.result else { return "" }
        if result.creditedSeconds == 0 { return "今回は記録に反映しませんでした。" }
        if result.completed { return "この世界が完成しました" }
        if result.previousRank == 5 { return "この世界で、またひとつ積み重ねました" }
        return result.evolved ? "世界に、新しい変化が生まれました" : "世界が、少し育ちました"
    }
}

private struct ResultContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ResultGrowthProgress: View {
    let result: SessionResult
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeRank: Int
    @State private var progress: Double

    init(result: SessionResult) {
        self.result = result
        _activeRank = State(initialValue: result.previousRank)
        _progress = State(initialValue: RooftopWorld.progress(for: result.previousGrowthSeconds, rank: result.previousRank))
    }

    var body: some View {
        VStack(spacing: 14) {
            if result.evolved {
                Text("\(result.previousRank) → \(result.newRank)")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundStyle(Palette.accent)
            }
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { rank in
                    ZStack {
                        if rank == activeRank && rank < 5 {
                            let existing = RooftopWorld.progress(for: result.previousGrowthSeconds, rank: rank)
                            Circle().strokeBorder(Palette.text.opacity(0.24), lineWidth: 2)
                            Circle().trim(from: 0, to: existing)
                                .stroke(Palette.text.opacity(0.58), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                                .rotationEffect(.degrees(-90)).padding(1.4)
                            Circle().trim(from: existing, to: max(existing, progress))
                                .stroke(Palette.accent, style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
                                .rotationEffect(.degrees(-90)).padding(1.4)
                        } else if rank <= activeRank {
                            Circle().fill(Palette.accent)
                                .frame(width: rank == activeRank ? 32 : 12, height: rank == activeRank ? 32 : 12)
                        } else {
                            Circle().strokeBorder(Palette.text.opacity(0.50), lineWidth: 1.3)
                                .frame(width: 12, height: 12)
                        }
                    }
                    .frame(width: 32, height: 32)
                    if rank < 5 {
                        Rectangle().fill(Palette.accent.opacity(rank < activeRank ? 0.80 : 0.30))
                            .frame(height: 1.2).frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(maxWidth: 340)
            Text("\(activeRank)/5")
                .font(.system(size: 15, weight: .semibold)).monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("世界の成長")
        .accessibilityValue(result.evolved ? "ランク\(result.previousRank)から\(result.newRank)に成長" : "ランク\(result.newRank)、今回\(TimeText.duration(result.creditedSeconds))を反映")
        .task(id: reduceMotion) { await animateGrowth() }
    }

    @MainActor private func animateGrowth() async {
        guard !reduceMotion, !result.growthSteps.isEmpty else {
            activeRank = result.newRank
            progress = RooftopWorld.progress(for: result.growthSeconds, rank: result.newRank)
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(350))
            for step in result.growthSteps {
                try Task.checkCancellation()
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    activeRank = step.rank
                    progress = step.start
                }
                try await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeInOut(duration: 0.95)) { progress = step.end }
                try await Task.sleep(for: .milliseconds(1150))
            }
            try Task.checkCancellation()
            withAnimation(.easeInOut(duration: 0.3)) {
                activeRank = result.newRank
                progress = RooftopWorld.progress(for: result.growthSeconds, rank: result.newRank)
            }
        } catch {
            // Dismissal or a motion-setting change cancels the old sequence.
        }
    }
}

struct CheckInSheet: View {
    @ObservedObject var store: FocusStore
    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "sparkle").font(.system(size: 25)).foregroundStyle(Palette.accent).padding(.top, 22)
            Text("作業、できていますか？").font(.system(size: 22, weight: .medium))
            Text("\(TimeText.duration(store.elapsed))が経ちました。\nひと息ついて、今の調子を確認しましょう。")
                .font(.system(size: 13)).lineSpacing(6).foregroundStyle(Palette.muted).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button("このまま続ける") { store.acknowledgeCheckIn(takeBreak: false) }.buttonStyle(PrimaryButtonStyle())
            Button("少し休憩する") { store.acknowledgeCheckIn(takeBreak: true) }
                .foregroundStyle(Palette.muted).frame(minHeight: 44)
        }.foregroundStyle(Palette.text).padding(26).interactiveDismissDisabled()
    }
}
