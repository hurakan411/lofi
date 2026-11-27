import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rank two retains the approved rank-one water renderer verbatim, then adds
// registered office keyframes. GIF delta transparency keeps static scenery fixed.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("output/concepts/shrine")
let input = folder.appendingPathComponent("rank-1-base.png")
let output = folder.appendingPathComponent("rank-2-office-v2.gif")
let w = 600, h = 1300, fps = 20, frameCount = 240
let duration = Double(frameCount) / Double(fps)
let tau = 2 * Double.pi
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
func clamp(_ n: Double, _ a: Double = 0, _ b: Double = 1) -> Double { min(b, max(a, n)) }
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing plate") }
var base = [UInt8](repeating: 0, count: w * h * 4)
base.withUnsafeMutableBytes { bytes in
    let context = CGContext(data: bytes.baseAddress, width: w, height: h,
                            bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: colorSpace, bitmapInfo: bitmapInfo)!
    context.interpolationQuality = .high
    context.draw(sourceImage, in: CGRect(x: 0, y: 0, width: w, height: h))
}

func readPlate(_ name: String) -> [UInt8] {
    let url = folder.appendingPathComponent(name)
    let source = CGImageSourceCreateWithURL(url as CFURL,nil)!
    let image = CGImageSourceCreateImageAtIndex(source,0,nil)!
    var pixels = [UInt8](repeating:0,count:w*h*4)
    pixels.withUnsafeMutableBytes { bytes in
        let context = CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:colorSpace,bitmapInfo:bitmapInfo)!
        context.interpolationQuality = .high
        context.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
    }
    return pixels
}
let office = readPlate("rank-2-base.png")
let stampRaised = readPlate("rank-2-stamp-raised.png")
let emptyArm = readPlate("rank-2-clean-plate-v2.png")
let officeLeft = Int(Double(w)*0.63)
let officeTop = Int(Double(h)*0.63)
let officeBottom = Int(Double(h)*0.915)

func smooth(_ n:Double) -> Double { let x=clamp(n);return x*x*(3-2*x) }
typealias Point=(Double,Double)
func contains(_ p:Point,_ polygon:[Point]) -> Bool {
    var inside=false,j=polygon.count-1
    for i in polygon.indices {
        let a=polygon[i],b=polygon[j]
        if ((a.1>p.1) != (b.1>p.1)) && p.0<(b.0-a.0)*(p.1-a.1)/(b.1-a.1)+a.0 { inside.toggle() }
        j=i
    }
    return inside
}
func spriteMask(_ polygons:[[Point]]) -> [Double] {
    var mask=[Double](repeating:0,count:w*h)
    let points=polygons.flatMap{$0}
    let left=max(0,Int(points.map(\.0).min()!)-2),right=min(w-1,Int(points.map(\.0).max()!)+2)
    let top=max(0,Int(points.map(\.1).min()!)-2),bottom=min(h-1,Int(points.map(\.1).max()!)+2)
    for y in top...bottom { for x in left...right {
        var covered=0
        for sy in 0..<4 { for sx in 0..<4 {
            let p=(Double(x)+(Double(sx)+0.5)/4,Double(y)+(Double(sy)+0.5)/4)
            if polygons.contains(where:{contains(p,$0)}) { covered += 1 }
        }}
        mask[y*w+x]=Double(covered)/16
    }}
    return mask
}
// Foreground-only silhouettes, traced around the active forearm/hand and tool.
// Unlike a broad ellipse, these contain no desk, page or wall pixels.
let writingMask=spriteMask([
    [(497,998),(500,997),(504,998),(507,1001),(513,1002),(522,1001),(526,998),(529,998),(532,1004),(532,1010),(528,1013),(519,1012),(512,1009),(507,1008),(501,1006),(498,1004)],
    [(496,1010),(504.5,987),(506.2,987),(498,1010)]
])
let stampMask=spriteMask([
    [(496,990),(499,987),(504,988),(507,991),(512,994),(522,998),(527,997),(531,1003),(532,1009),(528,1012),(519,1010),(510,1006),(503,1002),(501,1009),(496,1009)]
])
func maskSample(_ mask:[Double],_ x:Double,_ y:Double) -> Double {
    guard x>=0,y>=0,x<Double(w-1),y<Double(h-1) else { return 0 }
    let ix=Int(x),iy=Int(y),fx=x-Double(ix),fy=y-Double(iy),i=iy*w+ix
    return mask[i]*(1-fx)*(1-fy)+mask[i+1]*fx*(1-fy)+mask[i+w]*(1-fx)*fy+mask[i+w+1]*fx*fy
}
func armPose(_ time:Double) -> (Bool,Double) {
    // Rigid foreground rotation about the elbow. No image-space displacement field.
    switch time {
    case 8.0..<8.35:return (true,0.02+0.10*smooth((time-8)/0.35))
    case 8.35..<8.7:return (true,0.12)
    case 8.7..<8.95:return (true,0.12-0.155*smooth((time-8.7)/0.25))
    case 8.95..<9.15:return (true,-0.035)
    case 9.15..<9.45:return (true,-0.035+0.135*smooth((time-9.15)/0.3))
    case 9.45..<9.85:return (true,0.10-0.08*smooth((time-9.45)/0.4))
    default:
        let phase=tau*time/duration
        return (false,0.018*sin(phase*8)+0.006*sin(phase*17))
    }
}

func addOffice(_ water:[UInt8],_ time:Double) -> [UInt8] {
    var pixels=water
    let phase=tau*time/duration
    let (stamping,theta)=armPose(time)
    let armImage=stamping ? stampRaised:office
    let armMask=stamping ? stampMask:writingMask
    let cs=cos(theta),sn=sin(theta),elbowX=529.0,elbowY=1007.0
    for y in officeTop...officeBottom { for x in officeLeft..<w {
        let px=Double(x),py=Double(y),i=(y*w+x)*4
        let edge=smooth((px-Double(officeLeft))/20)*smooth((py-Double(officeTop))/22)*smooth((Double(officeBottom)-py)/22)
        var color=[Double(office[i]),Double(office[i+1]),Double(office[i+2])]
        // Fixed reconstructed background replaces ONLY the original active arm.
        let removed=writingMask[y*w+x]
        for c in 0..<3 { color[c]=color[c]*(1-removed)+Double(emptyArm[i+c])*removed }
        if x>=488 && x<=537 && y>=980 && y<=1020 {
            let dx=px-elbowX,dy=py-elbowY
            let sx=cs*dx+sn*dy+elbowX,sy = -sn*dx+cs*dy+elbowY
            let alpha=maskSample(armMask,sx,sy)
            if alpha>0 {
                for c in 0..<3 { color[c]=color[c]*(1-alpha)+sample(armImage,sx,sy,c)*alpha }
            }
        }
        // Hair ends sway independently, fading to zero well before their roots.
        let hairA=clamp(1-pow((px-Double(w)*0.942)/6.5,2)-pow((py-Double(h)*0.791)/13,2))
        let hairB=clamp(1-pow((px-Double(w)*0.930)/4,2)-pow((py-Double(h)*0.798)/7,2))
        if hairA+hairB>0 && max(color[0],max(color[1],color[2]))<90 && color[2]>color[0]*0.45 {
            let dx=0.65*sin(phase*3+0.4)*hairA*hairA+0.5*sin(phase*5+1.8)*hairB*hairB
            for c in 0..<3 { color[c]=sample(office,px-dx,py,c) }
        }
        // Small bounded light modulation inside the lantern, no large halo or dark dips.
        let lamp=clamp(1-pow((px-Double(w)*0.807)/13,2)-pow((py-Double(h)*0.704)/19,2))
        let warm=clamp((color[0]-color[2]-25)/60)*clamp((max(color[0],color[1])-120)/80)
        let gain=1+lamp*warm*(0.04*sin(phase*3)+0.015*sin(phase*7+0.6))
        for c in 0..<3 { pixels[i+c]=UInt8(clamp(Double(pixels[i+c])*(1-edge)+color[c]*gain*edge,0,255)) }
    }}
    return pixels
}

var leafPoints: [(Int, Int)] = []
var visiblePoints: [(Int, Int)] = []
for y in Int(Double(h) * 0.79)..<h {
    for x in 0..<Int(Double(w) * 0.45) {
        let i = (y * w + x) * 4
        let r = Double(base[i]), g = Double(base[i+1]), b = Double(base[i+2])
        if max(r, max(g, b)) > 35 { visiblePoints.append((x, y)) }
        if r > 95 && r > g * 1.45 && r > b * 1.35 { leafPoints.append((x, y)) }
    }
}
guard leafPoints.count > 15, visiblePoints.count > 100 else { fatalError("Cannot locate leaf/water") }
let lx0 = leafPoints.map(\.0).min()! - 3
let lx1 = leafPoints.map(\.0).max()! + 4
let ly0 = leafPoints.map(\.1).min()! - 3
let ly1 = leafPoints.map(\.1).max()! + 4
let cx = Double(lx0 + lx1) / 2, cy = Double(ly0 + ly1) / 2
let rw = lx1-lx0+1, rh = ly1-ly0+1
var leafAlpha = [Double](repeating: 0, count: rw * rh)
for y in ly0...ly1 { for x in lx0...lx1 {
    let i = (y*w+x)*4
    leafAlpha[(y-ly0)*rw+x-lx0] = clamp((Double(base[i])-max(Double(base[i+1]),Double(base[i+2]))-5)/38)
}}
var clean = base
for y in ly0...ly1 { for x in lx0...lx1 {
    let alpha = clamp(leafAlpha[(y-ly0)*rw+x-lx0]*2.5)
    let i = (y*w+x)*4
    // Sample quiet water well left of the impact, not its bright reflection.
    let sampleX = max(0, x-Int(Double(w)*0.12))
    let si = (y*w+sampleX)*4
    for c in 0..<3 { clean[i+c] = UInt8(clamp(Double(base[i+c])*(1-alpha)+Double(base[si+c])*alpha,0,255)) }
}}

let x0 = max(0, visiblePoints.map(\.0).min()!-12)
let x1 = min(w-1, visiblePoints.map(\.0).max()!+12)
let y0 = max(0, visiblePoints.map(\.1).min()!-12)
let y1 = min(h-1, visiblePoints.map(\.1).max()!+12)
let impactX = Double(w)*0.171
let impactY = Double(h)*0.890
let waterX = Double(w)*0.194
let waterY = Double(h)*0.897
let waterRX = Double(w)*0.136
let waterRY = Double(h)*0.024

func sample(_ pixels: [UInt8], _ x: Double, _ y: Double, _ channel: Int) -> Double {
    let xx = clamp(x,0,Double(w-2)), yy = clamp(y,0,Double(h-2))
    let ix = Int(xx), iy = Int(yy), fx = xx-Double(ix), fy = yy-Double(iy)
    let i = (iy*w+ix)*4+channel
    return Double(pixels[i])*(1-fx)*(1-fy) + Double(pixels[i+4])*fx*(1-fy)
        + Double(pixels[i+w*4])*(1-fx)*fy + Double(pixels[i+w*4+4])*fx*fy
}

func frame(_ time: Double) -> [UInt8] {
    var pixels = clean
    let phase = tau*time/duration
    // Each frequency completes an integer number of cycles in the twelve-second loop.
    for y in y0...y1 { for x in x0...x1 {
        let px = Double(x), py = Double(y), i = (y*w+x)*4
        let ellipse = pow((px-waterX)/waterRX,2)+pow((py-waterY)/waterRY,2)
        let waterMask = clamp((1-ellipse)*5)
        if waterMask > 0 {
            let dx = px-impactX, dy = (py-impactY)/0.31
            let radius = max(1,sqrt(dx*dx+dy*dy))
            let wave = sin(tau*radius/17-phase*15)
            let displacement = 0.85*wave*waterMask
            let sx = px+dx/radius*displacement
            let sy = py+dy/radius*displacement*0.31
            let ring = pow(max(0,cos(tau*radius/19-phase*12)),16)
            let shade = sin(tau*radius/26-phase*9)*1.5
            let strength = waterMask * clamp(radius/9) * clamp((100-radius)/80)
            for c in 0..<3 {
                let glint = ring * [11.0,20.0,24.0][c]*strength + shade*waterMask
                pixels[i+c] = UInt8(clamp(sample(clean,sx,sy,c)+glint,0,255))
            }
        }
        // Advected highlights travel down the original thin, textured water stream.
        if abs(px-impactX)<3.1 && py>Double(h)*0.852 && py<impactY+2 {
            let brightness = max(Double(clean[i]),max(Double(clean[i+1]),Double(clean[i+2])))
            let streamMask = clamp((brightness-27)/80)*clamp(1-abs(px-impactX)/3.2)
            let streak = pow(max(0,sin((py-impactY)*0.78-phase*72)),4)
            for c in 0..<3 {
                let value = Double(pixels[i+c])*(1-0.18*streamMask)+streak*streamMask*[38.0,49.0,53.0][c]
                pixels[i+c] = UInt8(clamp(value,0,255))
            }
        }
    }}
    let driftX = 5.8*sin(phase)+1.3*sin(phase*2)
    let driftY = 1.8*sin(phase+0.6)-1.8*sin(0.6)
    let theta = 0.27*sin(phase)+0.055*sin(phase*2)
    let cs = cos(theta), sn = sin(theta)
    for y in (ly0-12)...(ly1+12) { for x in (lx0-15)...(lx1+15) {
        let dx = Double(x)-cx-driftX, dy = Double(y)-cy-driftY
        let sx = cs*dx+sn*dy+cx, sy = -sn*dx+cs*dy+cy
        let ax = sx-Double(lx0), ay = sy-Double(ly0)
        guard ax>=0, ay>=0, ax<Double(rw-1), ay<Double(rh-1) else { continue }
        let ix = Int(ax), iy = Int(ay), fx = ax-Double(ix), fy = ay-Double(iy)
        let a = iy*rw+ix
        let alpha = leafAlpha[a]*(1-fx)*(1-fy)+leafAlpha[a+1]*fx*(1-fy)
            + leafAlpha[a+rw]*(1-fx)*fy+leafAlpha[a+rw+1]*fx*fy
        if alpha>0.001 {
            let i = (y*w+x)*4
            for c in 0..<3 { pixels[i+c] = UInt8(clamp(sample(base,sx,sy,c)*alpha+Double(pixels[i+c])*(1-alpha),0,255)) }
        }
    }}
    return addOffice(pixels,time)
}

let paletteBase = addOffice(base,0)
struct ColorBin { let r:Int; let g:Int; let b:Int; let count:Int }
var histogram: [Int:Int] = [:]
for y in stride(from:0,to:h,by:2) { for x in stride(from:0,to:w,by:2) {
    let i = (y*w+x)*4
    let key = (Int(paletteBase[i])>>3)<<10 | (Int(paletteBase[i+1])>>3)<<5 | (Int(paletteBase[i+2])>>3)
    histogram[key,default:0] += 1
}}
var boxes = [histogram.map { key,count in ColorBin(r:((key>>10)&31)*8+4,g:((key>>5)&31)*8+4,b:(key&31)*8+4,count:count) }]
func spread(_ box:[ColorBin]) -> (Int,Int) {
    let ranges = [(box.map(\.r).max()!-box.map(\.r).min()!), (box.map(\.g).max()!-box.map(\.g).min()!), (box.map(\.b).max()!-box.map(\.b).min()!)]
    let axis = ranges.enumerated().max(by:{$0.element<$1.element})!.offset
    return (axis,ranges[axis])
}
while boxes.count<255 {
    let candidate = boxes.indices.filter { boxes[$0].count>1 }.max {
        Double(spread(boxes[$0]).1)*sqrt(Double(boxes[$0].reduce(0){$0+$1.count})) < Double(spread(boxes[$1]).1)*sqrt(Double(boxes[$1].reduce(0){$0+$1.count}))
    }
    guard let index = candidate else { break }
    let axis = spread(boxes[index]).0
    let ordered = boxes.remove(at:index).sorted { a,b in (axis==0 ? a.r : axis==1 ? a.g:a.b) < (axis==0 ? b.r : axis==1 ? b.g:b.b) }
    let total = ordered.reduce(0){$0+$1.count}
    var count = 0, split = 1
    for j in 0..<(ordered.count-1) { count += ordered[j].count; split=j+1; if count>=total/2 { break } }
    boxes.append(Array(ordered[..<split])); boxes.append(Array(ordered[split...]))
}
var palette: [[Int]] = boxes.map { box in
    let total = box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 { palette.append(palette.last!) }
var colorCache = [Int](repeating:-1,count:32768)
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8) -> UInt8 {
    let key = (Int(r)>>3)<<10 | (Int(g)>>3)<<5 | (Int(b)>>3)
    if colorCache[key]>=0 { return UInt8(colorCache[key]) }
    let rr = ((key>>10)&31)*8+4, gg = ((key>>5)&31)*8+4, bb = (key&31)*8+4
    var best=0, distance=Int.max
    for j in 0..<255 {
        let dr=palette[j][0]-rr,dg=palette[j][1]-gg,db=palette[j][2]-bb
        let d=dr*dr*2+dg*dg*3+db*db*2
        if d<distance { distance=d; best=j }
    }
    colorCache[key]=best; return UInt8(best)
}
// A shared global palette plus local frame rectangles keep the mostly empty
// portrait GIF compact. Reset LZW before a width transition to use unambiguous
// nine-bit codes throughout; no lossy temporal optimization is applied.
func lzw(_ bytes:[UInt8]) -> [UInt8] {
    var encoded:[UInt8]=[], accumulator=0, bitCount=0
    func emit(_ code:Int) {
        accumulator |= code<<bitCount; bitCount += 9
        while bitCount>=8 { encoded.append(UInt8(accumulator&255)); accumulator >>= 8; bitCount -= 8 }
    }
    var table:[Int:Int]=[:], next=258, prefix=Int(bytes[0])
    emit(256)
    for value in bytes.dropFirst() {
        let byte=Int(value), key=(prefix<<8)|byte
        if let code=table[key] { prefix=code }
        else {
            emit(prefix); table[key]=next; next += 1; prefix=byte
            if next>=500 { emit(256); table.removeAll(keepingCapacity:true); next=258 }
        }
    }
    emit(prefix); emit(257)
    if bitCount>0 { encoded.append(UInt8(accumulator&255)) }
    return encoded
}
var gif=Data("GIF89a".utf8)
func byte(_ n:Int) { gif.append(UInt8(n)) }
func word(_ n:Int) { byte(n&255); byte((n>>8)&255) }
word(w); word(h); byte(0xF7); byte(0); byte(0)
for color in palette { for value in color { byte(value) } }
gif.append(contentsOf:[0x21,0xFF,0x0B]); gif.append(Data("NETSCAPE2.0".utf8)); gif.append(contentsOf:[3,1,0,0,0])
var snapshots:[[UInt8]]=[]
var maximumFrameDelta=0.0, seamDelta=0.0
var firstFrame:[UInt8]=[], lastFrame:[UInt8]=[]
var previousIndices=[UInt8](repeating:255,count:w*h)
let encodingTop=min(y0,officeTop)
let encodingBottom=max(y1,officeBottom)
for index in 0..<frameCount {
    let pixels=frame(Double(index)/Double(fps))
    if index==0 { firstFrame=pixels }
    if [0,60,120,168,182,196].contains(index) { snapshots.append(pixels) }
    if !lastFrame.isEmpty {
        var diff=0.0
        for y in encodingTop...encodingBottom { for x in x0..<w { for c in 0..<3 {
            let i=(y*w+x)*4+c; diff += abs(Double(pixels[i])-Double(lastFrame[i]))
        }}}
        maximumFrameDelta=max(maximumFrameDelta,diff/Double((w-x0)*(encodingBottom-encodingTop+1)*3))
    }
    lastFrame=pixels
    let left=index==0 ? 0:x0, top=index==0 ? 0:encodingTop
    let width=index==0 ? w:w-x0, height=index==0 ? h:encodingBottom-encodingTop+1
    var indices=[UInt8]();indices.reserveCapacity(width*height)
    for y in top..<(top+height) { for x in left..<(left+width) {
        let p=y*w+x,i=p*4
        let color=paletteIndex(pixels[i],pixels[i+1],pixels[i+2])
        indices.append(index>0 && color==previousIndices[p] ? 255:color)
        previousIndices[p]=color
    }}
    gif.append(contentsOf:[0x21,0xF9,4,index==0 ? 4:5,5,0,255,0,0x2C])
    word(left);word(top);word(width);word(height);byte(0);byte(8)
    let data=lzw(indices)
    for start in stride(from:0,to:data.count,by:255) {
        let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])
    }
    byte(0)
}
byte(0x3B)
try gif.write(to:output)
for y in encodingTop...encodingBottom { for x in x0..<w { for c in 0..<3 {
    let i=(y*w+x)*4+c;seamDelta += abs(Double(firstFrame[i])-Double(lastFrame[i]))
}}}
seamDelta /= Double((w-x0)*(encodingBottom-encodingTop+1)*3)
guard let check=CGImageSourceCreateWithURL(output as CFURL,nil),CGImageSourceGetCount(check)==frameCount,
      CGImageSourceCreateImageAtIndex(check,frameCount-1,nil) != nil else { fatalError("Invalid GIF") }
let metadata=CGImageSourceCopyProperties(check,nil)! as NSDictionary
let loop=(metadata[kCGImagePropertyGIFDictionary] as? NSDictionary)?[kCGImagePropertyGIFLoopCount] as? Int
precondition(loop==0,"GIF must loop forever")
precondition(seamDelta<=maximumFrameDelta*1.3,"Loop seam is too abrupt")

// Inspect writing and both drawn stamping poses at the delivered pixel scale.
let cropX=Int(Double(w)*0.75),cropY=Int(Double(h)*0.73)
let cropW=w-cropX,cropH=Int(Double(h)*0.13),scale=3
let sheetW=cropW*scale*3,sheetH=cropH*scale*2
let sheetContext=CGContext(data:nil,width:sheetW,height:sheetH,bitsPerComponent:8,bytesPerRow:sheetW*4,space:colorSpace,bitmapInfo:bitmapInfo)!
sheetContext.interpolationQuality = .none
for (j,pixels) in snapshots.enumerated() {
    let data=Data(pixels)
    let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    let crop=image.cropping(to:CGRect(x:cropX,y:cropY,width:cropW,height:cropH))!
    sheetContext.draw(crop,in:CGRect(x:(j%3)*cropW*scale,y:(1-j/3)*cropH*scale,width:cropW*scale,height:cropH*scale))
}
let sheetURL=folder.appendingPathComponent("rank-2-motion-check-v2.png")
let png=CGImageDestinationCreateWithURL(sheetURL as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(png,sheetContext.makeImage()!,nil);precondition(CGImageDestinationFinalize(png))
let report="""
Rank 2: \(w) x \(h), \(frameCount) frames, \(fps) fps, \(duration)s, infinite loop.
GIF size: \(gif.count) bytes. Animation area: \(x0),\(encodingTop)–\(w-1),\(encodingBottom).
Leaf center: \(cx),\(cy); drift ±5.8 px + secondary sway, angular sway ±18.6° maximum.
Loop boundary mean pixel delta: \(seamDelta); maximum adjacent delta: \(maximumFrameDelta).
Motion: inherited water/leaf; foreground-only rigid pen/arm motion; one stamping action per 12s; hair-tip movement; bounded lantern light.
Stationary desk, ledger and wall; no wrist-area warp, no background pose blending.
Plates: rank-1-base.png, rank-2-base.png, rank-2-clean-plate-v2.png, rank-2-stamp-raised.png.
Future scenery remains hidden; fixed camera. Water rendering is unchanged from rank one.
"""
try report.write(to:folder.appendingPathComponent("rank-2-animation-report-v2.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
