import SwiftUI

struct CollectionStorySheet: View {
    let story: CollectionStory
    let unlockedRank: Int
    let onRankChange: (Int) -> Void
    @State private var selectedRank: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(story: CollectionStory, unlockedRank: Int, initialRank: Int,
         onRankChange: @escaping (Int) -> Void = { _ in }) {
        self.story = story
        self.unlockedRank = unlockedRank
        self.onRankChange = onRankChange
        _selectedRank = State(initialValue: min(max(1, initialRank), max(1, min(5, unlockedRank))))
    }

    var body: some View {
        ZStack {
            scenery
            VStack(spacing: 0) {
                heading
                ScrollViewReader { proxy in
                    ScrollView {
                        if let chapter = story.chapter(at: selectedRank, unlockedRank: unlockedRank) {
                            VStack(alignment: .leading, spacing: 28) {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("第\(chapter.rank)話")
                                        .font(.system(size: 11, weight: .medium)).tracking(1)
                                        .foregroundStyle(Palette.accent)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Palette.accent.opacity(0.08), in: Capsule())
                                        .overlay { Capsule().strokeBorder(Palette.accent.opacity(0.24), lineWidth: 0.5) }
                                    Text(chapter.title)
                                        .font(.system(size: 25, weight: .regular, design: .serif))
                                        .accessibilityAddTraits(.isHeader)
                                }
                                .padding(.bottom, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .overlay(alignment: .bottom) {
                                    Rectangle().fill(Palette.text.opacity(0.12)).frame(height: 0.5)
                                }
                                .id("storyTop")

                                Text(chapter.text)
                                    .font(.system(size: 17, weight: .regular, design: .serif))
                                    .lineSpacing(8)
                                    .foregroundStyle(Palette.text.opacity(0.94))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .textSelection(.enabled)
                                    .accessibilityIdentifier("storyChapter_\(chapter.rank)")
                            }
                            .shadow(color: .black.opacity(0.65), radius: 6, y: 1)
                            .frame(maxWidth: 560, alignment: .leading)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 32)
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .onChange(of: selectedRank) { _, rank in
                        proxy.scrollTo("storyTop", anchor: .top)
                        onRankChange(rank)
                    }
                }
                chapterNavigation
            }
        }
        .foregroundStyle(Palette.text)
        .onChange(of: unlockedRank) { _, rank in
            selectedRank = min(selectedRank, max(1, min(5, rank)))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
        .presentationBackground(.clear)
        .preferredColorScheme(.dark)
    }

    private var scenery: some View {
        GeometryReader { geometry in
            let native = story.world.artworkSize
            let scale = max(geometry.size.width / native.width, geometry.size.height / native.height)
            ZStack {
                Palette.background
                if story.chapter(at: selectedRank, unlockedRank: unlockedRank) != nil {
                    AnimatedGIFView(resource: story.world.resource(for: selectedRank),
                                    isPlaying: scenePhase == .active, reduceMotion: reduceMotion,
                                    transitionDuration: 0.8)
                        .opacity(reduceTransparency ? 0.08 : 0.30)
                        .frame(width: native.width * scale, height: native.height * scale)
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                if reduceTransparency {
                    Palette.background.opacity(0.88)
                } else {
                    Rectangle().fill(.ultraThinMaterial).opacity(0.08)
                    LinearGradient(stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.48), location: 0.48),
                        .init(color: .black.opacity(0.12), location: 0.78),
                        .init(color: .black.opacity(0.52), location: 1)
                    ], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var heading: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Label("物語", systemImage: "book.closed")
                    .font(.system(size: 10, weight: .medium)).tracking(1)
                    .foregroundStyle(Palette.accent.opacity(0.8))
                Text(story.title)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(2).minimumScaleFactor(0.85)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.06), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("物語を閉じる")
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 18)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.18))
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.text.opacity(0.1)).frame(height: 0.5)
        }
    }

    private var chapterNavigation: some View {
        VStack(spacing: 14) {
            chapterPicker
            HStack(spacing: 14) {
                Button { selectedRank -= 1 } label: {
                    Label("前の話", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(.white.opacity(0.025), in: Capsule())
                        .overlay { Capsule().strokeBorder(Palette.text.opacity(0.35), lineWidth: 0.8) }
                }
                .disabled(selectedRank == 1)
                .opacity(selectedRank == 1 ? 0.25 : 1)
                .accessibilityIdentifier("previousStoryChapter")

                if selectedRank < min(5, unlockedRank) {
                    Button { selectedRank += 1 } label: {
                        HStack(spacing: 8) {
                            Text("次の話")
                            Image(systemName: "chevron.right")
                        }
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(.white.opacity(0.025), in: Capsule())
                        .overlay { Capsule().strokeBorder(Palette.accent.opacity(0.6), lineWidth: 0.8) }
                    }
                    .accessibilityIdentifier("nextStoryChapter")
                } else {
                    Group {
                        if selectedRank < 5 {
                            Label("続きはランク\(selectedRank + 1)で", systemImage: "lock")
                        } else {
                            Text("おわり")
                        }
                    }
                    .foregroundStyle(Palette.text.opacity(0.5))
                    .frame(maxWidth: .infinity).frame(height: 44)
                }
            }
            .font(.system(size: 12))
            .lineLimit(1).minimumScaleFactor(0.8)
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.35)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea(edges: .bottom)
        }
    }

    private var chapterPicker: some View {
        CollectionRankRail(selectedRank: $selectedRank, unlockedRank: unlockedRank,
                           axis: .horizontal, accessibilityPrefix: "story")
    }
}
