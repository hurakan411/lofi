import SwiftUI
import UIKit

enum MainTab: String, CaseIterable {
    case work = "作業", collection = "コレクション", settings = "設定"
    var icon: String {
        switch self { case .work: "laptopcomputer"; case .collection: "square.stack"; case .settings: "gearshape" }
    }
}
private enum ActiveSheet: String, Identifiable {
    case sounds, review, result, checkIn, collection, pomodoro, countdown
    var id: String { rawValue }
}

struct ContentView: View {
    @ObservedObject var store: FocusStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: MainTab = .work
    @State private var controlsVisible = true
    @State private var sheet: ActiveSheet?
    @State private var selectedCollection: CollectionEntry?
    @StateObject private var timerNotifications = FocusTimerNotifications()
    @State private var startMenuExpanded = false
    @State private var resultSheetHeight: CGFloat = 440

    private var compact: Bool { verticalSizeClass == .compact }
    private var workChromeVisible: Bool {
        controlsVisible && sheet != .result && sheet != .pomodoro && sheet != .countdown
    }
    private var chromeVisible: Bool { tab != .work || workChromeVisible }
    private var displayedProgress: Double { store.displayedRank != store.rank ? 1 : store.evolutionProgress }
    private var sceneInk: Color { store.activeWorld.usesLightCanvas ? Color.black.opacity(0.78) : Palette.text }
    private var sceneAccent: Color { store.activeWorld.usesLightCanvas ? Color(red: 0.38, green: 0.31, blue: 0.23) : Palette.accent }
    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.background.ignoresSafeArea()
            if tab == .work {
                workPage
            } else {
                Group {
                    switch tab {
                    case .collection: CollectionPage(store: store, onOpen: { entry in
                        selectedCollection = entry
                        if let world = entry.world {
                            store.previewCollectionAudio(rank: store.displayedRank(for: world), world: world)
                        } else {
                            store.silenceCollectionAudio()
                        }
                        sheet = .collection
                    })
                    case .settings: SettingsPage(store: store)
                    case .work: EmptyView()
                    }
                }
                .safeAreaPadding(.bottom, 95)
            }
            navigation
                    .padding(.horizontal, compact ? 90 : 18)
                    .padding(.bottom, 8)
                    .allowsHitTesting(chromeVisible)
        }
        .sheet(item: $sheet, onDismiss: {
            store.endCollectionAudioPreview()
            controlsVisible = true
            refreshSheet()
        }) { active in
            Group {
                switch active {
                case .sounds: SoundsSheet(store: store) { sheet = nil }
                case .review: ReviewSheet(store: store)
                case .result: ResultSheet(store: store, onHeightChange: { resultSheetHeight = $0 }) { store.result = nil; sheet = nil }
                case .checkIn: CheckInSheet(store: store)
                case .pomodoro, .countdown:
                    TimerSetupSheet(mode: active == .pomodoro ? .pomodoro:.countdown,
                                    settings: store.timerSettings, close: { sheet=nil }) { settings in
                        store.start(mode: active == .pomodoro ? .pomodoro:.countdown, settings: settings)
                        timerNotifications.update(session: store.data.session, requestPermission: true)
                        sheet=nil
                    }
                case .collection: CollectionDetailSheet(store: store, entry: selectedCollection ?? store.collectionEntries[0]) {
                    tab = .work
                    sheet = nil
                    controlsVisible = true
                }
                }
            }
            .presentationDetents(active == .sounds ? SoundsSheet.detents : active == .collection || active == .pomodoro || active == .countdown ? [.large] : active == .result ? [.height(resultSheetHeight), .large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(active == .sounds || active == .result || active == .pomodoro || active == .countdown ? 32 : 30)
            .presentationBackground {
                if active == .sounds || active == .result || active == .pomodoro || active == .countdown {
                    SoundSheetBackground(lightBackdrop: store.audioWorld.usesLightCanvas)
                }
                else { Palette.surface }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            store.tick()
            store.syncAudio()
            timerNotifications.update(session: store.data.session)
            refreshSheet()
        }
        .onChange(of: store.timerBoundaryID) { _, id in
            if id != nil, store.isForeground {
                timerNotifications.playBoundaryCue(vibrate: store.sessionMode == .pomodoro, audio: store.audio)
            }
        }
        .onChange(of: store.needsReview) { _, _ in refreshSheet() }
        .onChange(of: store.result?.id) { _, _ in refreshSheet() }
        .onChange(of: store.checkInRequested) { _, _ in refreshSheet() }
        .onChange(of: store.data.session) { _, _ in timerNotifications.update(session: store.data.session) }
        .onChange(of: tab) { _, _ in controlsVisible = true; startMenuExpanded=false }
        .onChange(of: sheet) { _, active in
            if active != .collection { store.endCollectionAudioPreview() }
            if active != nil { startMenuExpanded=false }
        }
        .onChange(of: scenePhase) { _, phase in
            store.isForeground = phase == .active
            store.setAppInBackground(phase == .background)
            if phase == .active {
                store.tick(); store.syncAudio()
                timerNotifications.update(session: store.data.session)
            } else {
                startMenuExpanded=false; store.persist()
                timerNotifications.update(session: store.data.session)
            }
        }
        .alert("保存について", isPresented: Binding(get: { store.storageError != nil }, set: { if !$0 { store.storageError = nil } })) {
            Button("閉じる") { store.storageError = nil }
        } message: { Text(store.storageError ?? "") }
        .alert("音の再生について", isPresented: Binding(get: { store.audioError != nil }, set: { if !$0 { store.audioError = nil } })) {
            Button("閉じる") { store.audioError = nil }
        } message: { Text(store.audioError ?? "") }
        .preferredColorScheme(tab == .work && store.activeWorld.usesLightCanvas ? .light : .dark)
    }

    private var workPage: some View {
        GeometryReader { geometry in
            ZStack {
                SceneViewport(world: store.activeWorld, rank: store.displayedRank, isPlaying: scenePhase == .active,
                    onBackgroundTap: toggleControls)
                    .ignoresSafeArea()
                LinearGradient(colors: [.black.opacity(0.32), .clear, .clear, .black.opacity(0.42)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea().allowsHitTesting(false)
                    .opacity(workChromeVisible && !store.activeWorld.usesLightCanvas ? 1 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: workChromeVisible)
                VStack {
                    header
                        .frame(maxWidth: compact ? geometry.size.width * 0.52 : .infinity, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    workControls
                        .modifier(ChromeFade(visible: workChromeVisible, order: 5))
                        .frame(maxWidth: compact ? 430 : 520)
                        .padding(.horizontal, 22)
                        .padding(.bottom, compact ? 64 : 84)
                }
                if store.hasSession {
                    sessionTime
                        .frame(width: compact ? min(geometry.size.width * 0.38, 300) : min(geometry.size.width - 56, 420))
                        .position(x: compact ? geometry.size.width * 0.72 : geometry.size.width / 2,
                                  y: compact ? geometry.size.height * 0.25 + 10 : max(176, geometry.size.height * 0.23) + 18 + (store.sessionMode == .normal ? 0 : 12))
                }
                HStack {
                    Spacer(minLength: 0)
                    NowPlayingPanel(audio: store.audio, isActive: scenePhase == .active && workChromeVisible && sheet == nil,
                                    darkOnLight: store.activeWorld.usesLightCanvas) { sheet = .sounds }
                        .modifier(ChromeFade(visible: workChromeVisible, order: 4))
                }
                .ignoresSafeArea(.container, edges: .horizontal)
                .offset(y: compact ? -12 : -18)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.worldName)
                .font(.system(size: compact ? 20 : 26, weight: .medium, design: .serif))
                .tracking(0.8)
                .lineLimit(2)
                .padding(.bottom, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(sceneAccent.opacity(0.90)).frame(height: 1.4)
                }
                .modifier(ChromeFade(visible: workChromeVisible, order: 0))
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 14) {
                    Text("\(store.displayedRank)/5")
                        .font(.system(size: 15, weight: .semibold))
                        .monospacedDigit()
                        .tracking(0.6)
                        .foregroundStyle(sceneInk)
                    WorkGrowthLights(rank: store.displayedRank, progress: displayedProgress,
                                     completed: store.isComplete || store.displayedRank != store.rank,
                                     ink: sceneInk, accent: sceneAccent)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("レベル\(store.displayedRank)、全5段階")
                .accessibilityValue(store.displayedRank != store.rank ? "完了したレベル" : store.isComplete ? store.evolutionLabel : "次のレベルまで\(Int(displayedProgress * 100))パーセント、\(store.evolutionLabel)")
                .modifier(ChromeFade(visible: workChromeVisible, order: 1))
                if !store.isComplete && store.displayedRank == store.rank {
                    Text(store.remaining <= 0 ? "進化まで到達 · 終了後に反映" : "進化まであと\(Int(ceil(store.remaining / 60)))分")
                        .font(.system(size: 10))
                        .foregroundStyle(sceneInk.opacity(0.70))
                        .modifier(ChromeFade(visible: workChromeVisible, order: 2))
                }
            }
        }
        .foregroundStyle(sceneInk)
        .shadow(color: .black.opacity(store.activeWorld.usesLightCanvas ? 0 : 0.90), radius: 2, y: 1)
        .shadow(color: .black.opacity(store.activeWorld.usesLightCanvas ? 0 : 0.5), radius: 12, y: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, compact ? 16 : 28)
    }

    private var sessionTime: some View {
        VStack(spacing: 0) {
            Text(store.sessionStatus)
                .accessibilityIdentifier("sessionStatus")
                .font(.system(size: 12, weight: .medium)).tracking(1.2)
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background { WorkLegibilityBackground(shape: Capsule()) }
            Text(TimeText.clock(store.clockSeconds))
                .foregroundStyle(sceneInk)
                .font(.system(size: compact ? 40 : 58, weight: .regular, design: .serif))
                .monospacedDigit().tracking(compact ? 2 : 3)
                .lineLimit(1).minimumScaleFactor(0.7)
                .accessibilityIdentifier("elapsedTime")
                .accessibilityLabel(store.sessionMode == .normal ? "経過時間":"残り時間")
            if store.sessionMode != .normal {
                Text(store.sessionMode == .pomodoro
                     ? "ポモドーロ · \(store.timerReading?.round ?? 1)回目 · 作業 \(TimeText.duration(store.elapsed))"
                     : FocusMode.countdown.title)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background { WorkLegibilityBackground(shape: Capsule()) }
                    .accessibilityIdentifier("sessionMode")
            }
        }
        .foregroundStyle(Palette.text)
        .shadow(color: .black.opacity(store.activeWorld.usesLightCanvas ? 0 : 0.65), radius: 12, y: 2)
        .allowsHitTesting(false)
    }

    @ViewBuilder private var workControls: some View {
        if store.hasSession {
            HStack(alignment: .top, spacing: compact ? 38 : 54) {
                Button {
                    if store.isPaused { store.resume() } else { store.pause() }
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(Palette.onAccent)
                            .frame(width: 56, height: 56)
                            .background(Palette.accent, in: Circle())
                            .overlay { Circle().strokeBorder(.black.opacity(0.22), lineWidth: 1) }
                        Text(store.isPaused ? "再開" : "一時停止")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 5)
                            .background { WorkLegibilityBackground(shape: Capsule()) }
                    }
                    .frame(width: 84)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.isPaused ? "作業を再開" : "作業を一時停止")
                .accessibilityIdentifier("pauseResume")
                finishButton
            }
            .shadow(color: .black.opacity(0.55), radius: 8, y: 2)
        } else {
            StartModeControl(isExpanded: $startMenuExpanded, compact: compact) { mode in
                switch mode {
                case .normal: store.start()
                case .pomodoro: sheet = .pomodoro
                case .countdown: sheet = .countdown
                }
            }
        }
    }

    private var finishButton: some View {
        Button {
            store.requestFinish()
            refreshSheet()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 56, height: 56)
                    .background { WorkLegibilityBackground(shape: Circle()) }
                    .overlay { Circle().strokeBorder(Palette.accent, lineWidth: 1.4) }
                Text("終了")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.text)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background { WorkLegibilityBackground(shape: Capsule()) }
            }
            .frame(width: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("作業を終える")
        .accessibilityIdentifier("finishWork")
    }
    private var navigation: some View {
        HStack(spacing: 2) {
            ForEach(MainTab.allCases, id: \.self) { item in
                Button {
                    tab = item
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: item.icon).font(.system(size: 17, weight: .regular))
                        Text(item.rawValue).font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(tab == .work ? (tab == item ? Palette.accent : Palette.text.opacity(0.48)) : (tab == item ? Palette.text : Palette.muted))
                    .frame(maxWidth: .infinity).frame(height: 55)
                    .background {
                        if tab != .work && tab == item {
                            RoundedRectangle(cornerRadius: 17).fill(Palette.elevated)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if tab == .work && tab == item {
                            Capsule().fill(Palette.accent).frame(width: 38, height: 2)
                        }
                    }
                }
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityIdentifier("tab_\(item.rawValue)")
                .modifier(ChromeFade(visible: chromeVisible, order: 6 + (MainTab.allCases.firstIndex(of: item) ?? 0), animated: tab == .work))
            }
        }
        .padding(5)
        .background {
            if tab == .work {
                WorkLegibilityBackground(shape: RoundedRectangle(cornerRadius: 23))
                    .modifier(ChromeFade(visible: chromeVisible, order: 6))
            } else {
                RoundedRectangle(cornerRadius: 23).fill(Palette.surface.opacity(0.97))
                    .overlay(RoundedRectangle(cornerRadius: 23).strokeBorder(Palette.line))
            }
        }
        .frame(maxWidth: 520)
    }
    private func toggleControls() {
        if startMenuExpanded { startMenuExpanded=false }
        else { controlsVisible.toggle() }
    }
    private func refreshSheet() {
        if store.needsReview { sheet = .review }
        else if store.result != nil { sheet = .result }
        else if store.checkInRequested, sheet == nil { sheet = .checkIn }
        else if sheet == .review || sheet == .checkIn || sheet == .result { sheet = nil }
    }
}

private struct WorkGrowthLights: View {
    let rank: Int
    let progress: Double
    let completed: Bool
    var ink: Color = Palette.text
    var accent: Color = Palette.accent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...5, id: \.self) { level in
                ZStack {
                    if level < rank || (level == rank && completed) {
                        Circle().fill(accent).frame(width: 10, height: 10)
                    } else if level == rank {
                        Circle().strokeBorder(ink.opacity(0.40), lineWidth: 2)
                        Circle().trim(from: 0, to: min(1, max(0, progress)))
                            .stroke(accent, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .padding(1.2)
                    } else {
                        Circle().strokeBorder(ink.opacity(0.55), lineWidth: 1.3)
                            .frame(width: 10, height: 10)
                    }
                }
                .frame(width: 16, height: 16)
                if level < 5 {
                    Rectangle().fill(accent.opacity(level < rank ? 0.80 : 0.42))
                        .frame(width: 18, height: 1.2)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: progress)
    }
}

/// A local contrast floor keeps controls readable over every scene and zoom level.
struct WorkLegibilityBackground<S: InsettableShape>: View {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if reduceTransparency {
            shape.fill(Palette.surface)
        } else {
            shape.fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.75)
                .overlay { shape.fill(.black.opacity(colorScheme == .light ? 0.44 : 0.16)) }
                .overlay { shape.strokeBorder(.white.opacity(0.10), lineWidth: 0.5) }
        }
    }
}

/// Keep views mounted so showing and hiding can both fade in the same order.
private struct ChromeFade: ViewModifier {
    let visible: Bool
    let order: Int
    var animated = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .animation(animated && !reduceMotion ? .easeInOut(duration: 0.28).delay(Double(order) * 0.055) : nil, value: visible)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }
}
