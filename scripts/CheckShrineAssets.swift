import Foundation
import ImageIO

let base = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Lofi/Resources/Scenes"
for rank in 1...5 {
    let url = URL(fileURLWithPath: base).appendingPathComponent("shrine-rank-\(rank).gif")
    let started = Date()
    guard let source = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { fatalError("Missing rank \(rank)") }
    let count = CGImageSourceGetCount(source)
    let expected = rank == 1 ? 240 : 2400
    precondition(count == expected, "Rank \(rank) frame count: \(count)")
    var duration = 0.0
    for i in 0..<count {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as! [CFString: Any]
        let gif = properties[kCGImagePropertyGIFDictionary] as! [CFString: Any]
        duration += gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gif[kCGImagePropertyGIFDelayTime] as? Double ?? 0
    }
    precondition(abs(duration - (rank == 1 ? 12 : 120)) < 0.01)
    let metadataTime = Date().timeIntervalSince(started)
    for i in [0, count / 2, count - 1] {
        let beganDecode = Date()
        guard let image = CGImageSourceCreateImageAtIndex(source, i, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else { fatalError("Unreadable frame \(rank):\(i)") }
        precondition(image.width == 600 && image.height == 1300)
        print("Rank \(rank) frame \(i): decode \(String(format: "%.3f", Date().timeIntervalSince(beganDecode)))s")
    }
    print("PASS rank \(rank): \(count) frames, \(String(format: "%.2f", duration))s; metadata \(String(format: "%.3f", metadataTime))s")
}
