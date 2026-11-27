import SwiftUI

private enum SettingsDestination: String, Identifiable {
    case onboarding, guide, privacy
    var id: String { rawValue }
    var title: String {
        switch self {
        case .onboarding: "はじめの案内"
        case .guide: "画面ガイド"
        case .privacy: "プライバシーポリシー"
        }
    }
    var icon: String {
        switch self {
        case .onboarding: "book"
        case .guide: "hand.tap"
        case .privacy: "doc.text"
        }
    }
}

struct SettingsPage: View {
    @ObservedObject var store: FocusStore
    @State private var destination: SettingsDestination?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if DEBUG
    @State private var developerExpanded = false
    @State private var showResetConfirmation = false
    @State private var didReset = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: PageLayout.sectionSpacing) {
                heading
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("音の再生")
                    Toggle(isOn: Binding(get: { store.backgroundPlaybackEnabled },
                                         set: { store.setBackgroundPlaybackEnabled($0) })) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("バックグラウンド再生")
                                .font(.system(size: 16, weight: .semibold))
                            Text("他のアプリを使っているときや、画面をロックしたときも音を流す")
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.text.opacity(0.72))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .tint(Palette.accent)
                    .padding(18)
                    .modifier(SettingsCard())
                    .accessibilityIdentifier("backgroundPlaybackToggle")
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("作業時間の確認")
                    confirmationOptions
                }
                if store.data.confirmation == .frequent {
                    checkInterval
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("はじめかたとガイド")
                    VStack(spacing: 0) {
                        destinationRow(.onboarding)
                        separator
                        destinationRow(.guide)
                    }
                    .modifier(SettingsCard())
                }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("アプリについて")
                    destinationRow(.privacy).modifier(SettingsCard())
                }
                #if DEBUG
                developerControls
                #endif
                Text("LOFI  /  \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0")")
                    .font(.system(size: 11, weight: .medium)).tracking(1.5)
                    .foregroundStyle(Palette.text.opacity(0.50))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .frame(maxWidth: PageLayout.contentWidth)
            .padding(.horizontal, PageLayout.horizontalPadding).padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .foregroundStyle(Palette.text)
        .blur(radius: destination == nil ? 0 : 10)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: destination)
        .sheet(item: $destination) { target in
            SettingsInformationSheet(destination: target)
                .presentationDetents(target == .privacy ? [.large] : [.height(310), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(32)
                .presentationBackground { SoundSheetBackground() }
                .preferredColorScheme(.dark)
        }
        #if DEBUG
        .alert("データをすべて削除しますか？", isPresented: $showResetConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除して最初から", role: .destructive) {
                store.resetDebugData()
                didReset = store.storageError == nil
            }
        } message: {
            Text("記録・育成・進行中の作業・設定を初期化します。この操作は取り消せません。")
        }
        #endif
    }

    private var heading: some View {
        PageHeading(title: "設定")
            .background(alignment: .trailing) {
                Image("SettingsLamp")
                    .resizable().scaledToFit()
                    .frame(width: 220, height: 146)
                    .mask {
                        LinearGradient(stops: [
                            .init(color: .clear, location: 0),
                            .init(color: .white, location: 0.30),
                            .init(color: .white, location: 1)
                        ], startPoint: .leading, endPoint: .trailing)
                    }
                    .offset(x: 22, y: -3)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
    }

    private var confirmationOptions: some View {
        VStack(spacing: 0) {
            ForEach(ConfirmationMode.allCases) { mode in
                let selected = store.data.confirmation == mode
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
                        store.setConfirmation(mode)
                    }
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(mode.title).font(.system(size: 16, weight: .semibold))
                            Text(shortDescription(mode))
                                .font(.system(size: 13))
                                .foregroundStyle(Palette.text.opacity(0.72))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 23, weight: .regular))
                            .foregroundStyle(selected ? Palette.accent : Palette.text.opacity(0.48))
                    }
                    .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background {
                        if selected {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Palette.accent.opacity(0.11))
                        }
                    }
                    .overlay(alignment: .leading) {
                        if selected {
                            Capsule().fill(Palette.accent).frame(width: 3, height: 30).padding(.leading, 6)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(mode.title)、\(mode.detail)")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier("confirmation_\(mode.rawValue)")
                if mode != .frequent { separator }
            }
        }
        .modifier(SettingsCard())
    }

    private var checkInterval: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("作業中の確認間隔")
            HStack(spacing: 5) {
                ForEach([15, 30, 60], id: \.self) { minutes in
                    let selected = store.data.checkIntervalMinutes == minutes
                    Button { store.setCheckInterval(minutes) } label: {
                        Text("\(minutes)分")
                            .font(.system(size: 15, weight: selected ? .semibold : .medium))
                            .foregroundStyle(selected ? Palette.onAccent : Palette.text.opacity(0.80))
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                            .background {
                                if selected { RoundedRectangle(cornerRadius: 12).fill(Palette.accent) }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("作業中の確認間隔、\(minutes)分")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .accessibilityIdentifier("checkInterval_\(minutes)")
                }
            }
            .padding(6).modifier(SettingsCard())
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.system(size: 16, weight: .semibold))
            .accessibilityAddTraits(.isHeader)
    }

    private var separator: some View {
        Rectangle().fill(Palette.text.opacity(0.10)).frame(height: 0.5).padding(.horizontal, 18)
    }

    private func shortDescription(_ mode: ConfirmationMode) -> String {
        switch mode {
        case .none: "計測時間をそのまま反映"
        case .light: "60分以上の作業終了時に確認"
        case .everySession: "作業終了時に確認"
        case .frequent: "終了時と作業中に確認"
        }
    }

    private func destinationRow(_ target: SettingsDestination) -> some View {
        Button { destination = target } label: {
            HStack(spacing: 14) {
                Image(systemName: target.icon)
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 26)
                Text(target.title).font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.text.opacity(0.45))
            }
            .padding(.horizontal, 18).padding(.vertical, 15)
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings_\(target.rawValue)")
    }

    #if DEBUG
    private var developerControls: some View {
        DisclosureGroup(isExpanded: $developerExpanded) {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("サンプルコレクション", isOn: $store.debugCollectionsEnabled)
                    .font(.system(size: 14)).tint(Palette.accent)
                    .accessibilityIdentifier("debugCollections")
                Text("一覧の確認用に5つの世界を表示します。記録や育成には影響しません。")
                    .font(.system(size: 12)).foregroundStyle(Palette.text.opacity(0.65)).lineSpacing(4)
                Rectangle().fill(Palette.line).frame(height: 0.5)
                Text("最初から試す").font(.system(size: 14, weight: .medium))
                Text("作業記録・育成・進行中の作業・設定を初期化し、ランク1に戻します。")
                    .font(.system(size: 12)).foregroundStyle(Palette.text.opacity(0.65)).lineSpacing(4)
                Button("データをすべて削除", role: .destructive) { showResetConfirmation = true }
                    .font(.system(size: 14, weight: .medium)).frame(minHeight: 44)
                    .accessibilityIdentifier("debugResetData")
                if didReset {
                    Text("初期化しました。「作業」からランク1で始められます。")
                        .font(.system(size: 12)).foregroundStyle(Palette.accent)
                }
            }
            .padding(.top, 16)
        } label: {
            Text("開発者向け").font(.system(size: 15, weight: .medium)).frame(minHeight: 24)
        }
        .tint(Palette.text.opacity(0.65))
        .padding(18).modifier(SettingsCard())
        .accessibilityIdentifier("developerSettings")
    }
    #endif
}

private struct SettingsCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.10, green: 0.09, blue: 0.085))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(colors: [.white.opacity(0.025), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
            }
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.07), lineWidth: 0.5) }
    }
}

private struct SettingsInformationSheet: View {
    let destination: SettingsDestination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(destination.title).font(.system(size: 21, weight: .medium))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.06), in: Circle())
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain).accessibilityLabel("閉じる")
            }
            .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 12)
            if destination == .privacy {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("最終更新：2026年11月24日")
                            .font(.system(size: 12)).foregroundStyle(Palette.text.opacity(0.65))
                        Text("Lofiでは、作業の記録と世界の成長をアプリ内で管理します。現在のバージョンでのデータの取り扱いは、以下のとおりです。")
                            .font(.system(size: 14)).lineSpacing(6)
                        ForEach(Array(SettingsPrivacyPolicy.sections.enumerated()), id: \.offset) { _, section in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(section.title).font(.system(size: 16, weight: .semibold))
                                    .accessibilityAddTraits(.isHeader)
                                Text(section.body).font(.system(size: 14))
                                    .foregroundStyle(Palette.text.opacity(0.82))
                                    .lineSpacing(6).textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding(24).frame(maxWidth: .infinity)
                }
                .accessibilityIdentifier("privacyPolicyContent")
            } else {
                VStack(spacing: 16) {
                    Image(systemName: destination.icon).font(.system(size: 32, weight: .light))
                        .foregroundStyle(Palette.accent).padding(.top, 12)
                    Text("この案内は準備中です。")
                        .font(.system(size: 15)).foregroundStyle(Palette.text.opacity(0.76))
                    Spacer(minLength: 12)
                    Button("閉じる") { dismiss() }.buttonStyle(PrimaryButtonStyle(height: 50))
                }
                .padding(24)
                .accessibilityIdentifier("settingsPlaceholder_\(destination.rawValue)")
            }
        }
        .foregroundStyle(Palette.text)
        .background(.black.opacity(0.48))
    }
}

private enum SettingsPrivacyPolicy {
    // Based on the bundled audio, local FocusStore JSON and absence of external SDKs.
    private static var deletionDescription: String {
        let description = "データはアプリの利用を継続する間、端末内に保存されます。端末内のアプリデータは、アプリを削除することで削除できます。"
        #if DEBUG
        return description + "デバッグ版の「データをすべて削除」でも、作業記録・育成状況・設定を初期化できます。"
        #else
        return description
        #endif
    }
    static let sections: [(title: String, body: String)] = [
        ("保存する情報", "作業の開始・終了日時、計測時間、確認後の作業時間、進行中の作業状態、世界の成長状況、表示するランク、音量や確認頻度などの設定を端末内に保存します。氏名やメールアドレスの入力、アカウント登録は必要ありません。"),
        ("情報の利用目的", "保存した情報は、作業時間の計測と確認、世界・音・物語の解禁、前回の作業や設定の復元に使用します。広告配信や利用者の追跡には使用しません。"),
        ("外部への送信・第三者への提供", "現在のアプリには、作業記録や設定を開発者のサーバーへ送信する機能、広告・利用状況解析のための外部SDKはありません。アプリがこれらのデータを第三者へ送信・提供することはありません。音声とアニメーションは、アプリに含まれる素材を使用します。"),
        ("保存期間と削除", deletionDescription),
        ("端末のバックアップ等", "iOSのバックアップや診断情報の取り扱いは、端末の設定とAppleのサービスに従います。アプリを削除しても、OSのバックアップにデータが残る場合があります。バックアップの管理は、端末の設定をご確認ください。"),
        ("権限について", "現在のアプリは、位置情報、連絡先、写真、カメラ、マイクへのアクセスを求めません。音の再生のために、マイクで録音することもありません。"),
        ("内容の変更", "機能の追加やデータの取り扱いの変更に伴い、このポリシーを更新することがあります。変更後の内容と最終更新日は、この画面に掲載します。")
    ]
}
