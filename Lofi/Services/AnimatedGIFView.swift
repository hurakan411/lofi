import SwiftUI
import ImageIO
import UIKit

/// Decode on a serial queue with a bounded cache, including 2,400-frame scenes.
struct AnimatedGIFView: UIViewRepresentable {
    var resource: String
    var isPlaying = true
    var reduceMotion = false
    var transitionDuration: TimeInterval = 0

    func makeUIView(context: Context) -> GIFSurface {
        let view = GIFSurface()
        view.setResource(resource, transitionDuration: reduceMotion ? 0 : transitionDuration)
        view.setPlaying(isPlaying && !reduceMotion)
        return view
    }
    func updateUIView(_ view: GIFSurface, context: Context) {
        view.setResource(resource, transitionDuration: reduceMotion ? 0 : transitionDuration)
        view.setPlaying(isPlaying && !reduceMotion)
    }
    static func dismantleUIView(_ view: GIFSurface, coordinator: Void) { view.stop() }
}

final class GIFSurface: UIView {
    private var source: CGImageSource?
    private var resource: String?
    private var frames = 0
    private var durations: [Double] = []
    private var totalDuration = 8.0
    private let cache = NSCache<NSNumber, CGImage>()
    private let decoding = DispatchQueue(label: "lofi.gif.decode", qos: .userInitiated)
    private var inFlight: Set<Int> = []
    private var generation = UUID()
    private var loading: Progress?
    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?
    private var startedAt = CACurrentMediaTime()
    private var pausedAt = 0.0
    private var playing = true
    private var currentFrame = -1

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.contentsGravity = .resizeAspect
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .nearest
        clipsToBounds = true
        isUserInteractionEnabled = false
        cache.countLimit = 8
        cache.totalCostLimit = 16 * 1_024 * 1_024
        NotificationCenter.default.addObserver(self, selector: #selector(suspend), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(restorePlayback), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { loading?.cancel(); displayLink?.invalidate(); NotificationCenter.default.removeObserver(self) }

    func setResource(_ name: String, transitionDuration: TimeInterval = 0) {
        guard resource != name else { return }
        loading?.cancel()
        let request = Progress(totalUnitCount: 1)
        loading = request
        generation = UUID()
        let token = generation
        resource = name
        source = nil
        frames = 0
        cache.removeAllObjects()
        inFlight.removeAll()
        currentFrame = -1
        // Long GIF metadata can take over a second. Keep the previous frame visible
        // and load on the same serial queue as decoding, so rank changes stay responsive.
        decoding.async { [weak self] in
            guard !request.isCancelled,
                  let url = Bundle.main.url(forResource: name, withExtension: "gif"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return }
            let frames = CGImageSourceGetCount(source)
            var durations: [Double] = []
            durations.reserveCapacity(frames)
            for index in 0..<frames {
                guard !request.isCancelled else { return }
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
                let gif = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                durations.append(max(0.02, gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gif?[kCGImagePropertyGIFDelayTime] as? Double ?? 0.05))
            }
            guard !request.isCancelled,
                  let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == token else { return }
                self.loading = nil
                self.source = source
                self.frames = frames
                self.durations = durations
                self.totalDuration = max(0.02, durations.reduce(0, +))
                self.startedAt = CACurrentMediaTime()
                self.pausedAt = 0
                self.cache.setObject(image, forKey: 0, cost: image.bytesPerRow * image.height)
                if transitionDuration > 0, self.layer.contents != nil, self.window != nil {
                    let fade = CATransition()
                    fade.type = .fade
                    fade.duration = transitionDuration
                    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    self.layer.add(fade, forKey: "rankCrossfade")
                } else {
                    self.layer.removeAnimation(forKey: "rankCrossfade")
                }
                self.layer.contents = image
                self.currentFrame = 0
                if self.playing { self.resumeDisplayLink() }
            }
        }
    }
    func setPlaying(_ value: Bool) {
        guard playing != value else { return }
        playing = value
        if value {
            startedAt = CACurrentMediaTime() - pausedAt
            resumeDisplayLink()
        } else {
            pausedAt = CACurrentMediaTime() - startedAt
            stop()
        }
    }
    func stop() { displayLink?.invalidate(); displayLink = nil; proxy = nil }
    @objc private func suspend() { pausedAt = CACurrentMediaTime() - startedAt; stop() }
    @objc private func restorePlayback() {
        if playing { startedAt = CACurrentMediaTime() - pausedAt; resumeDisplayLink() }
    }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { suspend() } else if playing { restorePlayback() }
    }
    private func resumeDisplayLink() {
        guard displayLink == nil else { return }
        let proxy = DisplayLinkProxy(target: self)
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.step))
        link.preferredFramesPerSecond = 20
        link.add(to: .main, forMode: .common)
        self.proxy = proxy
        displayLink = link
    }
    fileprivate func step() {
        guard let source, frames > 0 else { return }
        let time = (CACurrentMediaTime() - startedAt).truncatingRemainder(dividingBy: totalDuration)
        var accumulated = 0.0, index = 0
        for (i, duration) in durations.enumerated() {
            accumulated += duration
            if time < accumulated { index = i; break }
        }
        if index != currentFrame, let image = cache.object(forKey: NSNumber(value: index)) {
            layer.contents = image
            currentFrame = index
        }
        for offset in 0...3 {
            let next = (index + offset) % frames
            guard cache.object(forKey: NSNumber(value: next)) == nil, !inFlight.contains(next) else { continue }
            inFlight.insert(next)
            let token = generation
            decoding.async { [weak self] in
                let image = CGImageSourceCreateImageAtIndex(source, next, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.inFlight.remove(next)
                    if let image { self.cache.setObject(image, forKey: NSNumber(value: next), cost: image.bytesPerRow * image.height) }
                }
            }
        }
    }
}

private final class DisplayLinkProxy: NSObject {
    weak var target: GIFSurface?
    init(target: GIFSurface) { self.target = target }
    @objc func step() { target?.step() }
}
