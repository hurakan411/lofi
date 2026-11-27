import SwiftUI

struct CollectionPage: View {
    @ObservedObject var store: FocusStore
    let onOpen: (CollectionEntry) -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .regular ? 200 : 132, maximum: 250), spacing: 16, alignment: .top)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PageHeading(title: "コレクション")
                    .padding(.bottom, PageLayout.sectionSpacing)

                LazyVGrid(columns: columns, alignment: .leading, spacing: 26) {
                    ForEach(store.collectionEntries) { entry in
                        Button { onOpen(entry) } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                GeometryReader { geometry in
                                    let native = entry.artworkSize()
                                    let scale = max(geometry.size.width / native.width, geometry.size.height / native.height)
                                    CollectionArtwork(entry: entry)
                                        .frame(width: native.width * scale, height: native.height * scale)
                                        .frame(width: geometry.size.width, height: geometry.size.height,
                                               alignment: !entry.isSample ? .bottom : .center)
                                        .clipped()
                                }
                                .aspectRatio(0.76, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 7) {
                                    Text(entry.title)
                                        .font(.system(size: 14, weight: .regular))
                                        .lineLimit(1).minimumScaleFactor(0.85)
                                        .foregroundStyle(Palette.text.opacity(0.9))
                                    HStack(spacing: 7) {
                                        Text("\(entry.rank)/5").monospacedDigit()
                                        if entry.rank < 5 {
                                            Circle().frame(width: 2, height: 2)
                                            Text("育成中")
                                        }
                                        if entry.story != nil {
                                            Spacer(minLength: 0)
                                            Image(systemName: "book.closed")
                                                .accessibilityLabel("物語あり")
                                        }
                                    }
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(Palette.muted.opacity(0.85))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(entry.title)、\(entry.rank)/5、\(entry.story == nil ? "" : "物語あり、")詳細を開く")
                        .accessibilityIdentifier("collection_\(entry.id)")
                    }
                }
            }
            .frame(maxWidth: PageLayout.contentWidth)
            .padding(.horizontal, PageLayout.horizontalPadding).padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .foregroundStyle(Palette.text)
    }
}

private struct CollectionArtwork: View {
    let entry: CollectionEntry
    var rank: Int? = nil
    var transitionDuration: TimeInterval = 0
    var isActive = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch entry.artwork {
        case .rooftop, .shrine, .shellHarbor, .emberWorkshop:
            AnimatedGIFView(resource: (entry.world ?? .rooftop).resource(for: rank ?? entry.rank),
                            isPlaying: isActive && scenePhase == .active, reduceMotion: reduceMotion,
                            transitionDuration: transitionDuration)
        case .animation(let resource, _):
            AnimatedGIFView(resource: resource, isPlaying: isActive && scenePhase == .active, reduceMotion: reduceMotion)
        case .image(let resource, _):
            if let url = Bundle.main.url(forResource: resource, withExtension: "jpg"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image).resizable().interpolation(.high)
            }
        }
    }
}

private enum CollectionDetailModal: String, Identifiable {
    case story, sounds
    var id: String { rawValue }
}

/// Shared rank selector: vertical beside the scene, horizontal in the reader.
struct CollectionRankRail: View {
    @Binding var selectedRank: Int
    let unlockedRank: Int
    var axis: Axis = .vertical
    var accessibilityPrefix = "collection"
    @GestureState private var dragPosition: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let hitSize: CGFloat = 44
    private var lastRank: Int { min(5, max(1, unlockedRank)) }

    var body: some View {
        GeometryReader { geometry in
            let vertical = axis == .vertical
            let top = hitSize / 2
            let length = vertical ? geometry.size.height : geometry.size.width
            let step = max(0, length - hitSize) / 4
            let selectedPosition = top + CGFloat(selectedRank - 1) * step
            let thumbPosition = dragPosition ?? selectedPosition
            let point: (CGFloat) -> CGPoint = { position in
                vertical ? CGPoint(x: hitSize / 2, y: position) : CGPoint(x: position, y: hitSize / 2)
            }

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Palette.text.opacity(0.16))
                    .frame(width: vertical ? 1 : step * 4, height: vertical ? step * 4 : 1)
                    .position(point(top + step * 2))
                    .accessibilityHidden(true)

                ForEach(1...5, id: \.self) { rank in
                    Button { selectedRank = rank } label: {
                        Text("\(rank)")
                            .font(.system(size: 13, weight: rank == selectedRank ? .semibold : .regular,
                                          design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(rank == selectedRank ? Palette.accent : Palette.text.opacity(rank <= lastRank ? 0.65 : 0.22))
                            .frame(width: 30, height: 30)
                            .background(Palette.surface, in: Circle())
                            .overlay {
                                Circle().strokeBorder(Palette.text.opacity(rank <= lastRank ? 0.26 : 0.10), lineWidth: 1)
                            }
                            .frame(width: hitSize, height: hitSize)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(rank > lastRank)
                    .position(point(top + CGFloat(rank - 1) * step))
                    .accessibilityLabel(rank <= lastRank
                        ? (accessibilityPrefix == "story" ? "第\(rank)話を表示" : "ランク\(rank)を表示")
                        : "ランク\(rank)で解禁")
                    .accessibilityAddTraits(rank == selectedRank ? .isSelected : [])
                    .accessibilityIdentifier("\(accessibilityPrefix)Rank_\(rank)")
                }

                Circle()
                    .fill(Palette.accent.opacity(0.08))
                    .overlay { Circle().strokeBorder(Palette.accent, lineWidth: 1.5) }
                    .frame(width: 39, height: 39)
                    .position(point(thumbPosition))
                    .shadow(color: Palette.accent.opacity(0.15), radius: 5)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .animation(reduceMotion || dragPosition != nil ? nil : .spring(response: 0.32, dampingFraction: 0.85), value: thumbPosition)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 4)
                    .updating($dragPosition) { value, position, _ in
                        guard step > 0 else { return }
                        let coordinate = vertical ? value.location.y : value.location.x
                        position = min(top + CGFloat(lastRank - 1) * step, max(top, coordinate))
                    }
                    .onChanged { value in
                        guard step > 0 else { return }
                        let coordinate = vertical ? value.location.y : value.location.x
                        let position = min(top + CGFloat(lastRank - 1) * step, max(top, coordinate))
                        selectedRank = min(lastRank, max(1, Int(((position - top) / step).rounded()) + 1))
                    }
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityPrefix == "story" ? "話の選択" : "ランク選択")
            .accessibilityValue("\(selectedRank)/5")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: selectedRank = min(lastRank, selectedRank + 1)
                case .decrement: selectedRank = max(1, selectedRank - 1)
                @unknown default: break
                }
            }
        }
        .frame(width: axis == .vertical ? hitSize : nil, height: axis == .horizontal ? hitSize : nil)
        .frame(maxHeight: axis == .vertical ? 320 : nil)
    }
}

struct CollectionDetailSheet: View {
    @ObservedObject var store: FocusStore
    let entry: CollectionEntry
    let onUse: () -> Void
    @State private var selectedRank = 1
    @State private var modal: CollectionDetailModal?

    init(store: FocusStore, entry: CollectionEntry, onUse: @escaping () -> Void) {
        self.store = store
        self.entry = entry
        self.onUse = onUse
        _selectedRank = State(initialValue: entry.world.map { store.displayedRank(for: $0) } ?? entry.rank)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width > geometry.size.height && geometry.size.width > 560
            let padding: CGFloat = compact ? 16 : 24

            Group {
                if compact {
                    HStack(spacing: 24) {
                        artworkPreview
                        VStack(alignment: .leading, spacing: 12) {
                            title
                            controls(compact: true)
                        }
                        .frame(width: min(360, (geometry.size.width - padding * 2) * 0.48))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 18) {
                        title
                        artworkPreview
                            .layoutPriority(-1)
                        controls(compact: false)
                    }
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, padding)
            .padding(.top, compact ? 16 : 24)
            .padding(.bottom, compact ? 16 : 20)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .foregroundStyle(Palette.text)
        .onAppear {
            if let world = entry.world { store.previewCollectionAudio(rank: selectedRank, world: world) }
            else { store.silenceCollectionAudio() }
        }
        .onChange(of: selectedRank) { _, rank in
            if let world = entry.world { store.previewCollectionAudio(rank: rank, world: world) }
        }
        .sheet(item: $modal) { active in
            switch active {
            case .story:
                if let story = entry.story {
                    CollectionStorySheet(story: story, unlockedRank: entry.rank, initialRank: selectedRank,
                                         onRankChange: { selectedRank = $0 })
                }
            case .sounds:
                SoundsSheet(store: store) { modal = nil }
                    .presentationDetents(SoundsSheet.detents)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(32)
                    .presentationBackground { SoundSheetBackground(lightBackdrop: entry.world?.usesLightCanvas == true) }
            }
        }
    }

    private var title: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(entry.title)
                .font(.system(size: 24, weight: .medium))
                .lineLimit(2).minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.accent.opacity(0.55)).frame(height: 1)
                }
            Spacer(minLength: 0)
            Button { modal = .sounds } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17))
                    .foregroundStyle(Palette.text)
                    .frame(width: 44, height: 44)
                    .background(Palette.elevated, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("音響設定")
            .accessibilityIdentifier("collectionSoundSettings")
        }
    }

    /// The illustration uses only the space left after laying out the controls.
    private var artworkPreview: some View {
        HStack(spacing: 16) {
            if !entry.isSample {
                CollectionRankRail(selectedRank: $selectedRank, unlockedRank: entry.rank)
            }
            GeometryReader { geometry in
                let native = entry.artworkSize(at: selectedRank)
                let scale = max(0, min(geometry.size.width / native.width, geometry.size.height / native.height))
                CollectionArtwork(entry: entry, rank: selectedRank, transitionDuration: 0.8,
                                  isActive: modal != .story)
                    .frame(width: native.width * scale, height: native.height * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("collectionDetailArtwork")
    }

    private func controls(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            if entry.isSample {
                Text("デバッグ用のサンプル")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
            } else {
                if let story = entry.story,
                   let chapter = story.chapter(at: selectedRank, unlockedRank: entry.rank) {
                    storyButton(chapter: chapter, compact: compact)
                }
                Button("この世界で作業する") {
                    if let world = entry.world, store.useWorld(world, rank: selectedRank) { onUse() }
                }
                .buttonStyle(PrimaryButtonStyle(height: compact ? 48 : 56))
                .disabled(entry.world.map { !store.canUseWorld($0) } ?? true)
                .accessibilityIdentifier("useCollectionScene")
                if let world = entry.world, !store.canUseWorld(world) {
                    Text("作業を終了すると、この世界に切り替えられます")
                        .font(.system(size: 12)).foregroundStyle(Palette.muted)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func storyButton(chapter: CollectionStory.Chapter, compact: Bool) -> some View {
        Button { modal = .story } label: {
            HStack(spacing: 14) {
                Image(systemName: "book")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Palette.accent)
                VStack(alignment: .leading, spacing: 5) {
                    Text("物語を読む")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Palette.text)
                    Text("\(chapter.rank)/5 · \(chapter.title)")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: compact ? 56 : 64)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Rectangle().fill(Palette.line).frame(height: 1) }
            .overlay(alignment: .bottom) { Rectangle().fill(Palette.line).frame(height: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("readCollectionStory")
    }
}
