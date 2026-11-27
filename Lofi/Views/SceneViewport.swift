import SwiftUI

struct SceneViewport: View {
    var world: FocusWorld = .rooftop
    let rank: Int
    let isPlaying: Bool
    let onBackgroundTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom: CGFloat = 1
    @State private var pinchStart: CGFloat?
    @State private var pan: CGSize = .zero
    @State private var dragStart: CGSize?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let artwork = world.artworkSize(for: rank)
            let scale = min(size.width / artwork.width, size.height / artwork.height) * zoom
            let artSize = CGSize(width: artwork.width * scale, height: artwork.height * scale)
            let offset = bounded(pan, art: artSize, viewport: size)
            ZStack {
                (world.usesLightCanvas ? Color.white : Color.black)
                AnimatedGIFView(resource: world.resource(for: rank), isPlaying: isPlaying, reduceMotion: reduceMotion)
                    .frame(width: artSize.width, height: artSize.height)
                    .position(x: size.width / 2 + offset.width, y: size.height / 2 + offset.height)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(MagnifyGesture()
                .onChanged { value in
                    if pinchStart == nil { pinchStart = zoom }
                    zoom = min(4, max(1, (pinchStart ?? 1) * value.magnification))
                    let factor = min(size.width / artwork.width, size.height / artwork.height) * zoom
                    pan = bounded(pan, art: CGSize(width: artwork.width * factor, height: artwork.height * factor), viewport: size)
                }
                .onEnded { _ in pinchStart = nil })
            .simultaneousGesture(DragGesture(minimumDistance: 15)
                .onChanged { value in
                    guard zoom > 1 else { return }
                    if dragStart == nil { dragStart = offset }
                    let origin = dragStart ?? .zero
                    pan = bounded(CGSize(width: origin.width + value.translation.width,
                                         height: origin.height + value.translation.height), art: artSize, viewport: size)
                }
                .onEnded { _ in dragStart = nil })
            .simultaneousGesture(SpatialTapGesture().onEnded { _ in onBackgroundTap() })
            .onChange(of: world) { _, _ in resetZoom() }
            .onChange(of: size) { _, _ in resetZoom() }
            .accessibilityLabel(world.accessibilityDescription(rank: rank))
        }
        .accessibilityRepresentation {
            Button("世界の操作を表示・非表示", action: onBackgroundTap)
                .accessibilityHint("背景をタップして操作を表示。ピンチで拡大し、拡大中はドラッグで見渡せます。")
                .accessibilityAction(named: "世界全体を表示") { resetZoom() }
        }
    }
    private func resetZoom() {
        zoom = 1
        pan = .zero
        pinchStart = nil
        dragStart = nil
    }
    private func bounded(_ value: CGSize, art: CGSize, viewport: CGSize) -> CGSize {
        let x = max(0, (art.width - viewport.width) / 2)
        let y = max(0, (art.height - viewport.height) / 2)
        return CGSize(width: min(x, max(-x, value.width)), height: min(y, max(-y, value.height)))
    }
}
