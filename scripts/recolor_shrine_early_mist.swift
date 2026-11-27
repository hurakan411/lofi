import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Recompose the accepted animation frames against the rank-four mist field.
// All pose timing, pixels in the foreground core, frame delays and camera stay fixed.
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let w = 600, h = 1300
let space = CGColorSpaceCreateDeviceRGB()
func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
func smooth(_ x: Double) -> Double { let t = clamp(x); return t*t*(3-2*t) }
func raster(_ image: CGImage) -> [UInt8] {
    var p = [UInt8](repeating: 0, count: w*h*4)
    p.withUnsafeMutableBytes { b in
        let c = CGContext(data: b.baseAddress, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: w*4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return p
}
func image(_ p: [UInt8]) -> CGImage {
    CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w*4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: CGDataProvider(data: Data(p) as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
func savePNG(_ p: [UInt8], _ name: String) {
    let d = CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, image(p), nil)
    precondition(CGImageDestinationFinalize(d))
}
let mist: [UInt8] = {
    var p = [UInt8](repeating: 255, count: w*h*4)
    for y in 0..<h { for x in 0..<w {
        let px = Double(x), py = Double(y), depth = clamp(py/1100)
        let cloud = 1.4*sin(px/174+py/250)+1.1*cos(px/250-py/140)+0.5*sin(py/72+px/300)
        let colors = [233-7*depth+cloud, 237-6*depth+cloud, 232-6*depth+cloud]
        for c in 0..<3 { p[(y*w+x)*4+c] = UInt8(colors[c]) }
    }}
    return p
}()
let inputs = ["rank-1-water.gif", "rank-2-office-v10.gif", "rank-3-foreground-v4.gif"]
let outputs = ["rank-1-water-mist-v2.gif", "rank-2-office-mist-v11.gif", "rank-3-foreground-mist-v5.gif"]
func blur(_ input: [Float], radius: Int, passes: Int) -> [Float] {
    var p = input, tmp = input, out = input
    for _ in 0..<passes {
        for y in 0..<h {
            var sum: Float = 0
            for x in 0...radius { sum += p[y*w+x] }
            for x in 0..<w {
                let lo = max(0,x-radius), hi = min(w-1,x+radius)
                tmp[y*w+x] = sum/Float(hi-lo+1)
                if x-radius >= 0 { sum -= p[y*w+x-radius] }
                if x+radius+1 < w { sum += p[y*w+x+radius+1] }
            }
        }
        for x in 0..<w {
            var sum: Float = 0
            for y in 0...radius { sum += tmp[y*w+x] }
            for y in 0..<h {
                let lo = max(0,y-radius), hi = min(h-1,y+radius)
                out[y*w+x] = sum/Float(hi-lo+1)
                if y-radius >= 0 { sum -= tmp[(y-radius)*w+x] }
                if y+radius+1 < h { sum += tmp[(y+radius+1)*w+x] }
            }
        }
        p = out
    }
    return p
}
// 1 in the accepted object core, 0 in the old unrevealed backdrop.
func matte(_ source: [UInt8], rank: Int) -> [Float] {
    var result = [Float](repeating: 0, count: w*h)
    for y in 0..<h { for x in 0..<w {
        let i = (y*w+x)*4
        let brightness = Double(max(source[i], max(source[i+1], source[i+2])))
        // Color support is used only at the old feathered silhouettes, never in
        // the room interior, water core or rank-three paving/fox/plant core.
        var a = smooth((brightness-13)/57)
        let waterD = hypot((Double(x)-116.4)/68, (Double(y)-1166.1)/15)
        let waterCore = 1-smooth((waterD-0.85)/0.25)
        a = max(a, waterCore)
        if rank >= 2 {
            // Strictly inside the office architecture, including the moving clerk.
            if x >= 431 && y >= 881 && y <= 1094 { a = 1 }
            if x >= 414 && y >= 905 && y <= 1025 { a = 1 }
        }
        if rank == 3 && y >= 1100 { a = 1 }
        result[y*w+x] = Float(a)
    }}
    let wide = blur(result, radius: 9, passes: 3)
    let water = blur(result, radius: 2, passes: 2)
    for n in result.indices {
        let x = n%w, y = n/w
        if rank <= 2 && x < 260 && y > 1080 {
            result[n] = min(result[n], water[n])
        } else {
            result[n] = min(result[n], Float(smooth((Double(wide[n])-0.10)/0.90)))
        }
    }
    return result
}
func apply(_ source: [UInt8], _ mask: [Float]) -> [UInt8] {
    var p = source
    for n in mask.indices {
        let a = Double(mask[n])
        if a >= 0.99999 { continue }
        let i = n*4
        for c in 0..<3 { p[i+c] = UInt8(Double(source[i+c])*a+Double(mist[i+c])*(1-a)) }
    }
    return p
}

struct Bin { let rgb: [Int]; let count: Int }
func splitPalette(_ histogram: [Int:Int], count: Int) -> [[Int]] {
    var boxes = [histogram.map { key, n in Bin(rgb: [((key>>10)&31)*8+4, ((key>>5)&31)*8+4, (key&31)*8+4], count: n) }]
    func spread(_ box: [Bin]) -> (Int,Int) {
        let ranges = (0..<3).map { c in box.map{$0.rgb[c]}.max()! - box.map{$0.rgb[c]}.min()! }
        let axis = ranges.indices.max { ranges[$0] < ranges[$1] }!
        return (axis,ranges[axis])
    }
    while boxes.count < count {
        let possible = boxes.indices.filter { boxes[$0].count > 1 }
        guard let index = possible.max(by: {
            Double(spread(boxes[$0]).1)*sqrt(Double(boxes[$0].reduce(0){$0+$1.count})) < Double(spread(boxes[$1]).1)*sqrt(Double(boxes[$1].reduce(0){$0+$1.count}))
        }) else { break }
        let axis = spread(boxes[index]).0
        let ordered = boxes.remove(at: index).sorted { $0.rgb[axis] < $1.rgb[axis] }
        let total = ordered.reduce(0) { $0+$1.count }
        var sum = 0, split = 1
        for i in 0..<(ordered.count-1) {
            sum += ordered[i].count; split=i+1
            if sum >= total/2 { break }
        }
        boxes.append(Array(ordered[..<split])); boxes.append(Array(ordered[split...]))
    }
    return boxes.map { box in
        let total = box.reduce(0){$0+$1.count}
        return (0..<3).map { c in box.reduce(0){$0+$1.rgb[c]*$1.count}/total }
    }
}
func lzw(_ bytes: [UInt8]) -> [UInt8] {
    var encoded=[UInt8](), accumulator=0, bitCount=0
    func emit(_ code: Int) {
        accumulator |= code << bitCount; bitCount += 9
        while bitCount >= 8 { encoded.append(UInt8(accumulator&255)); accumulator >>= 8; bitCount -= 8 }
    }
    var table=[Int:Int](), next=258, prefix=Int(bytes[0]); emit(256)
    for value in bytes.dropFirst() {
        let b=Int(value), key=(prefix<<8)|b
        if let code=table[key] { prefix=code }
        else {
            emit(prefix); table[key]=next; next+=1; prefix=b
            if next >= 500 { emit(256); table.removeAll(keepingCapacity: true); next=258 }
        }
    }
    emit(prefix); emit(257)
    if bitCount > 0 { encoded.append(UInt8(accumulator&255)) }
    return encoded
}
func encode(rank: Int, source: CGImageSource, mask: [Float], first: [UInt8], revised: [UInt8]) {
    let raw = [UInt8](try! Data(contentsOf: folder.appendingPathComponent(inputs[rank-1])))
    precondition(raw[10]&0x80 != 0)
    let tableCount=1 << (Int(raw[10]&7)+1)
    var original=[[Int]](), seen=Set<Int>()
    for j in 0..<min(255,tableCount) {
        let i=13+j*3, color=[Int(raw[i]),Int(raw[i+1]),Int(raw[i+2])]
        let key=(color[0]<<16)|(color[1]<<8)|color[2]
        if seen.insert(key).inserted { original.append(color) }
    }
    var frequency=[Int:Int](), edgeHistogram=[Int:Int]()
    for n in mask.indices {
        let i=n*4
        if mask[n] > 0.99999 {
            let key=(Int(first[i])<<16)|(Int(first[i+1])<<8)|Int(first[i+2])
            frequency[key,default:0] += 1
        } else if mask[n] > 0.001 {
            let key=(Int(revised[i])>>3)<<10 | (Int(revised[i+1])>>3)<<5 | (Int(revised[i+2])>>3)
            edgeHistogram[key,default:0] += 1
        }
    }
    // Reserve 224 of the accepted GIF's exact colors for the object cores.
    // Additional colors are dedicated to pale mist and its soft silhouettes.
    original.sort {
        func score(_ c: [Int]) -> Int { frequency[(c[0]<<16)|(c[1]<<8)|c[2],default:0] }
        let a=score($0), b=score($1)
        return a == b ? $0.lexicographicallyPrecedes($1) : a > b
    }
    var palette=Array(original.prefix(224))
    for y in stride(from: 0, through: 1300, by: 185) {
        let i=(min(h-1,y)*w+300)*4
        palette.append((0..<3).map { Int(mist[i+$0]) })
    }
    palette += splitPalette(edgeHistogram, count: 255-palette.count)
    while palette.count < 256 { palette.append(palette.last!) }
    var lookup=[Int16](repeating:-1,count:1<<24)
    for j in 0..<255 {
        let c=palette[j], key=(c[0]<<16)|(c[1]<<8)|c[2]
        if lookup[key]<0 { lookup[key]=Int16(j) }
    }
    func index(_ r: UInt8,_ g: UInt8,_ b: UInt8) -> UInt8 {
        let key=(Int(r)<<16)|(Int(g)<<8)|Int(b)
        if lookup[key]>=0 { return UInt8(lookup[key]) }
        var best=0, distance=Int.max
        for j in 0..<255 {
            let c=palette[j],dr=c[0]-Int(r),dg=c[1]-Int(g),db=c[2]-Int(b)
            let d=dr*dr*2+dg*dg*3+db*db*2
            if d<distance { distance=d; best=j }
        }
        lookup[key]=Int16(best); return UInt8(best)
    }
    var gif=Data("GIF89a".utf8)
    func byte(_ n: Int) { gif.append(UInt8(n)) }
    func word(_ n: Int) { byte(n&255); byte((n>>8)&255) }
    word(w); word(h); byte(0xF7); byte(0); byte(0)
    for color in palette { for c in color { byte(c) } }
    gif.append(contentsOf: [0x21,0xFF,0x0B]); gif.append(Data("NETSCAPE2.0".utf8)); gif.append(contentsOf:[3,1,0,0,0])
    var previous=[UInt8](repeating:255,count:w*h)
    let count=CGImageSourceGetCount(source), animationTop=rank == 1 ? 1080 : 825
    var duration=0.0, maxCoreError=0.0
    for frame in 0..<count {
        autoreleasepool {
            let original = frame == 0 ? first : raster(CGImageSourceCreateImageAtIndex(source,frame,[kCGImageSourceShouldCacheImmediately:false] as CFDictionary)!)
            let top=frame == 0 ? 0 : animationTop
            var indices=[UInt8](); indices.reserveCapacity(w*(h-top))
            var coreError=0.0, coreCount=0
            for n in (top*w)..<(w*h) {
                let i=n*4, a=Double(mask[n])
                let r:UInt8, g:UInt8, b:UInt8
                if a >= 0.99999 { r=original[i];g=original[i+1];b=original[i+2] }
                else {
                    r=UInt8(Double(original[i])*a+Double(mist[i])*(1-a))
                    g=UInt8(Double(original[i+1])*a+Double(mist[i+1])*(1-a))
                    b=UInt8(Double(original[i+2])*a+Double(mist[i+2])*(1-a))
                }
                let color=index(r,g,b)
                indices.append(frame > 0 && color == previous[n] ? 255 : color)
                previous[n]=color
                if frame%200 == 0 && a >= 0.99999 {
                    coreError += Double(abs(Int(r)-palette[Int(color)][0])+abs(Int(g)-palette[Int(color)][1])+abs(Int(b)-palette[Int(color)][2]))
                    coreCount += 3
                }
            }
            if coreCount>0 { maxCoreError=max(maxCoreError,coreError/Double(coreCount)) }
            let props=CGImageSourceCopyPropertiesAtIndex(source,frame,nil) as! [CFString:Any]
            let gp=props[kCGImagePropertyGIFDictionary] as! [CFString:Any]
            let delay=gp[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gp[kCGImagePropertyGIFDelayTime] as? Double ?? 0.05
            let ticks=Int((delay*100).rounded()); duration += Double(ticks)/100
            gif.append(contentsOf:[0x21,0xF9,4,frame==0 ? 4:5]); word(ticks); byte(255); byte(0); byte(0x2C)
            word(0); word(top); word(w); word(h-top); byte(0); byte(8)
            let compressed=lzw(indices)
            for start in stride(from:0,to:compressed.count,by:255) {
                let end=min(start+255,compressed.count); byte(end-start); gif.append(contentsOf:compressed[start..<end])
            }
            byte(0)
            if frame%200 == 0 { print("Rank \(rank): \(frame)/\(count)"); fflush(stdout) }
        }
    }
    byte(0x3B)
    let output=folder.appendingPathComponent(outputs[rank-1])
    try! gif.write(to: output, options: .atomic)
    let report:[String:Any] = ["rank":rank,"source":inputs[rank-1],"animation":outputs[rank-1],"width":w,"height":h,"frames":count,"durationSeconds":duration,"loop":"infinite","mistReference":"rank4-v6/mist-background.png","motionTimingUnchanged":true,"newSceneryRevealed":false,"maxSampledCoreMeanChannelError":maxCoreError,"bytes":gif.count]
    let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try! data.write(to:folder.appendingPathComponent("rank-\(rank)-mist-report.json"))
    precondition(maxCoreError<3,"Unacceptable foreground palette error")
    print("Saved \(output.lastPathComponent): \(gif.count) bytes, core palette MAE \(maxCoreError)"); fflush(stdout)
}

let previewOnly = CommandLine.arguments.contains("--preview")
for rank in 1...3 {
    let input = folder.appendingPathComponent(inputs[rank-1])
    let source = CGImageSourceCreateWithURL(input as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)!
    let first = raster(CGImageSourceCreateImageAtIndex(source, 0, nil)!)
    let mask = matte(first, rank: rank)
    let revised = apply(first, mask)
    savePNG(revised, "rank-\(rank)-mist-preview.png")
    print("Preview rank \(rank): background \(Array(first[0..<3])) → \(Array(revised[0..<3]))", terminator: "\n")
    if previewOnly { continue }
    encode(rank: rank, source: source, mask: mask, first: first, revised: revised)
}
