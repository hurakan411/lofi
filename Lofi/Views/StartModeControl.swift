import SwiftUI
import UIKit

struct StartModeControl: View {
    @Binding var isExpanded: Bool
    var compact = false
    let choose: (FocusMode) -> Void
    @State private var hovered: FocusMode?
    @State private var revealProgress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let layout=StartModeLayout(width: geometry.size.width, compact: compact)
            ZStack(alignment: .topLeading) {
                Path { path in
                    let left=layout.center(for: .normal), mid=layout.center(for: .pomodoro), right=layout.center(for: .countdown)
                    path.move(to: CGPoint(x:left.x,y:left.y-15))
                    path.addQuadCurve(to: CGPoint(x:right.x,y:right.y-15),
                                      control: CGPoint(x:mid.x,y:2*mid.y-left.y-15))
                }
                .trim(from: 0, to: revealProgress)
                .stroke(Palette.text.opacity(0.38), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                .opacity(isExpanded ? 1:0)
                .allowsHitTesting(false)

                if isExpanded {
                    ForEach(Array(FocusMode.allCases.enumerated()), id: \.element) { index, mode in
                        let destination = layout.center(for: mode)
                        // Align the option's icon with the start circle before it launches.
                        let launch = CGPoint(x: layout.origin.x, y: layout.origin.y + 15)
                        Button { select(mode) } label: {
                            // Keep the touch target at its destination from the first frame.
                            // Only the artwork flies out from the start button.
                            ZStack {
                                Color.clear
                                VStack(spacing: 8) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 21, weight: .regular))
                                        .foregroundStyle(hovered == mode ? Palette.onAccent:Palette.accent)
                                        .frame(width: 56, height: 56)
                                        .background {
                                            if hovered == mode { Circle().fill(Palette.accent) }
                                            else { WorkLegibilityBackground(shape: Circle()) }
                                        }
                                        .overlay { Circle().strokeBorder(Palette.accent.opacity(hovered == mode ? 1:0.55), lineWidth: 1) }
                                    Text(mode.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                        .foregroundStyle(Palette.text)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background { WorkLegibilityBackground(shape: Capsule()) }
                                }
                                .frame(width: 100, height: 92)
                                .scaleEffect((hovered == mode ? 1.10:1) * (0.35 + 0.65 * revealProgress))
                                .opacity(revealProgress)
                                .offset(x: (launch.x - destination.x) * (1 - revealProgress),
                                        y: (launch.y - destination.y) * (1 - revealProgress))
                                .animation(reduceMotion ? nil : .smooth(duration: 0.62).delay(Double(index) * 0.13), value: revealProgress)
                                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
                                .allowsHitTesting(false)
                            }
                            .frame(width: 100, height: 92)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mode.title)
                        .accessibilityIdentifier("startMode_\(mode.rawValue)")
                        .transition(.identity)
                        .position(destination)
                    }

                }

                VStack(spacing: 10) {
                    Image(systemName: isExpanded ? "xmark":"play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Palette.onAccent)
                        .frame(width: 56, height: 56)
                        .background(Palette.accent, in: Circle())
                        .overlay { Circle().strokeBorder(.black.opacity(0.22), lineWidth: 1) }
                    Text(isExpanded ? "モードを選ぶ":"作業をはじめる")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, 13).padding(.vertical, 6)
                        .background { WorkLegibilityBackground(shape: Capsule()) }
                }
                .frame(width: 150, height: 94)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay {
                    StartModeTouchSurface(expanded: isExpanded, tap: toggle, hold: open,
                        move: { point in updateHover(layout.hitTest(menuPoint(point, layout))) },
                        release: { point in
                            if let mode=layout.hitTest(menuPoint(point, layout)) { select(mode) }
                            else { hovered=nil }
                        }, cancel: { hovered=nil })
                }
                .position(x: layout.origin.x, y: layout.origin.y+19)
            }
        }
        .frame(height: StartModeLayout(width: 0, compact: compact).height)
        .onChange(of: isExpanded, initial: true) { _, open in
            if !open { hovered=nil }
            if open && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.78).delay(0.08)) { revealProgress=1 }
            } else {
                revealProgress=open ? 1:0
            }
        }

    }
    private func menuPoint(_ point: CGPoint, _ layout: StartModeLayout) -> CGPoint {
        CGPoint(x: point.x + layout.origin.x - 75, y: point.y + layout.origin.y + 19 - 47)
    }
    private func updateHover(_ mode: FocusMode?) {
        if mode != hovered {
            hovered=mode
            if mode != nil { UISelectionFeedbackGenerator().selectionChanged() }
        }
    }
    private func open() {
        withAnimation(reduceMotion ? nil:.spring(response: 0.32, dampingFraction: 0.8)) { isExpanded=true }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
    private func toggle() {
        if isExpanded { withAnimation { isExpanded=false } }
        else { open() }
    }
    private func select(_ mode: FocusMode) {
        guard isExpanded else { return }
        isExpanded=false
        hovered=nil
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        choose(mode)
    }
}

/// UIControl keeps tracking the same touch after it leaves the start button.
private struct StartModeTouchSurface: UIViewRepresentable {
    let expanded: Bool
    let tap: () -> Void
    let hold: () -> Void
    let move: (CGPoint) -> Void
    let release: (CGPoint) -> Void
    let cancel: () -> Void

    func makeUIView(context: Context) -> ModeTrackingControl { ModeTrackingControl() }
    func updateUIView(_ view: ModeTrackingControl, context: Context) {
        view.tap=tap; view.hold=hold; view.move=move; view.release=release; view.cancel=cancel
        view.accessibilityIdentifier="startWork"
        view.accessibilityLabel=expanded ? "作業モードを閉じる":"作業モードを選ぶ"
        view.accessibilityValue=expanded ? "開いています":"閉じています"
        view.accessibilityHint="タップで3つのモードを表示。長押ししてモードへ指をずらし、離しても選べます。"
    }
}

private final class ModeTrackingControl: UIControl {
    var tap: () -> Void = {}
    var hold: () -> Void = {}
    var move: (CGPoint) -> Void = { _ in }
    var release: (CGPoint) -> Void = { _ in }
    var cancel: () -> Void = {}
    private var task: DispatchWorkItem?
    private var held=false
    private var firstPoint=CGPoint.zero
    private var latestPoint=CGPoint.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement=true
        accessibilityTraits = .button
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func accessibilityActivate() -> Bool { tap(); return true }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        held=false
        firstPoint=touch.location(in:self); latestPoint=firstPoint
        let work=DispatchWorkItem { [weak self] in
            guard let self, self.isTracking else { return }
            self.held=true; self.hold(); self.move(self.latestPoint)
        }
        task=work
        DispatchQueue.main.asyncAfter(deadline:.now()+0.3,execute:work)
        return true
    }
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        latestPoint=touch.location(in:self)
        if held { move(latestPoint) }
        else if hypot(latestPoint.x-firstPoint.x,latestPoint.y-firstPoint.y)>24 { task?.cancel() }
        return true
    }
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        task?.cancel(); task=nil
        let point=touch?.location(in:self) ?? latestPoint
        if held { release(point) }
        else if hypot(point.x-firstPoint.x,point.y-firstPoint.y)<=24 { tap() }
        held=false
    }
    override func cancelTracking(with event: UIEvent?) {
        task?.cancel(); task=nil; held=false; cancel()
    }
    override func didMoveToWindow() {
        if window == nil { cancelTracking(with:nil) }
    }
}

struct TimerSetupSheet: View {
    let mode: FocusMode
    @State var settings: FocusTimerSettings
    let close: () -> Void
    let start: (FocusTimerSettings) -> Void

    private var countdownHours: Binding<Int> {
        Binding(get: {settings.countdownMinutes/60}, set: { settings.countdownMinutes=min(719,max(1,$0*60+settings.countdownMinutes%60)) })
    }
    private var countdownMinutes: Binding<Int> {
        Binding(get: {settings.countdownMinutes%60}, set: {settings.countdownMinutes=max(1,(settings.countdownMinutes/60)*60+$0)})
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SheetHeading(title: mode.title, close: close)
                if mode == .countdown {
                    Text(TimeText.clock(Double(settings.countdownMinutes)*60))
                        .font(.system(size: 54, weight: .regular, design: .serif)).monospacedDigit()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("countdownDuration")
                    HStack(spacing: 10) {
                        ForEach([15,25,45,60],id: \.self) { minutes in
                            Button("\(minutes)分") { settings.countdownMinutes=minutes }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(settings.countdownMinutes == minutes ? Palette.onAccent:Palette.text)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(settings.countdownMinutes == minutes ? Palette.accent:Palette.elevated, in: Capsule())
                                .accessibilityIdentifier("countdownPreset_\(minutes)")
                        }
                    }
                    HStack(spacing: 0) {
                        Picker("時間", selection: countdownHours) {
                            ForEach(0...11,id: \.self) { Text("\($0)時間").tag($0) }
                        }.accessibilityIdentifier("countdownHours")
                        Picker("分", selection: countdownMinutes) {
                            ForEach(0...59,id: \.self) { Text("\($0)分").tag($0) }
                        }.accessibilityIdentifier("countdownMinutes")
                    }
                    .pickerStyle(.wheel).frame(height: 132)
                    Text("時間になったら計測を終了し、作業時間を確認します。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                } else {
                    HStack(spacing: 4) {
                        minutePicker("作業", selection: $settings.focusMinutes, range: 1...120,
                                     identifier: "pomodoroFocusMinutes")
                        minutePicker("短い休憩", selection: $settings.shortBreakMinutes, range: 1...30,
                                     identifier: "pomodoroShortBreakMinutes")
                        minutePicker("長い休憩", selection: $settings.longBreakMinutes, range: 1...60,
                                     identifier: "pomodoroLongBreakMinutes")
                    }
                    .padding(.horizontal, 8).padding(.vertical, 18)
                    .background(Palette.elevated.opacity(0.6), in: RoundedRectangle(cornerRadius: 20))
                    Text("作業と休憩を自動で繰り返し、4回ごとに長い休憩をとります。休憩時間は育成に含まれません。")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted).lineSpacing(4)
                }
                Button("\(mode == .countdown ? settings.countdownMinutes:settings.focusMinutes)分の作業をはじめる") { start(settings.bounded) }
                    .buttonStyle(PrimaryButtonStyle(height: 54))
                    .accessibilityIdentifier("startTimedWork")
                Text(mode == .pomodoro
                     ? "通知を許可すると、バックグラウンドでも休憩の開始・終了をお知らせします。振動は端末の通知・触覚設定に従います。"
                     : "通知を許可すると、アプリを閉じていても区切りをお知らせします。")
                    .font(.system(size: 11)).foregroundStyle(Palette.muted)
            }
            .foregroundStyle(Palette.text)
            .frame(maxWidth: 560)
            .padding(24).frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
    private func minutePicker(_ title: String, selection: Binding<Int>, range: ClosedRange<Int>, identifier: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.accent)
            Picker(title, selection: selection) {
                ForEach(range, id: \.self) { minutes in
                    Text("\(minutes)分").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 164)
            .clipped()
            .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity)
    }

}
