import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Local water animation over the approved rank-one illustration. Coordinates
// below refer to its 1070 x 1470 source canvas; shell and land stay stationary.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let folder = root.appendingPathComponent("output/concepts/shell-harbor/growth-ranks-v1")
let input = folder.appendingPathComponent("rank-1-puddle-v3.png")
let output = folder.appendingPathComponent("rank-1-puddle-animation-v1.gif")
let w = 642, h = 882, fps = 25, frameCount = 200
let duration = Double(frameCount) / Double(fps), scale = 0.6
let tau = 2 * Double.pi
let space = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
func clamp(_ value: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double { min(hi, max(lo, value)) }
func smooth(_ value: Double) -> Double { let t = clamp(value); return t*t*(3-2*t) }
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let sourceImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Missing source") }
var base = [UInt8](repeating: 0, count: w*h*4)
base.withUnsafeMutableBytes { bytes in
    let ctx = CGContext(data: bytes.baseAddress, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: w*4, space: space, bitmapInfo: bitmapInfo)!
    ctx.interpolationQuality = .high
    ctx.draw(sourceImage, in: CGRect(x: 0, y: 0, width: w, height: h))
}
func sample(_ pixels: [UInt8], _ x: Double, _ y: Double, _ c: Int) -> Double {
    let xx = clamp(x, 0, Double(w-2)), yy = clamp(y, 0, Double(h-2))
    let ix = Int(xx), iy = Int(yy), fx = xx-Double(ix), fy = yy-Double(iy)
    let i = (iy*w+ix)*4+c
    return Double(pixels[i])*(1-fx)*(1-fy)+Double(pixels[i+4])*fx*(1-fy)
        + Double(pixels[i+w*4])*(1-fx)*fy+Double(pixels[i+w*4+4])*fx*fy
}
typealias Point = (Double, Double)
func polygonMask(_ x: Double, _ y: Double, _ vertices: [Point], feather: Double) -> Double {
    var inside = false, distance = Double.greatestFiniteMagnitude
    for j in vertices.indices {
        let a = vertices[j], b = vertices[(j+1)%vertices.count]
        if (a.1 > y) != (b.1 > y), x < (b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0 { inside.toggle() }
        let dx = b.0-a.0, dy = b.1-a.1
        let t = clamp(((x-a.0)*dx+(y-a.1)*dy)/max(0.001, dx*dx+dy*dy))
        distance = min(distance, hypot(x-a.0-t*dx, y-a.1-t*dy))
    }
    return inside ? smooth(distance/feather) : 0
}
let pool: [Point] = [(756,1039),(801,1044),(851,1061),(862,1085),(838,1110),
    (795,1128),(735,1149),(629,1160),(540,1153),(474,1137),(405,1111),
    (348,1087),(307,1062),(331,1047),(393,1042),(443,1044),(516,1050),
    (599,1050),(674,1049),(705,1041)]
let inner: [Point] = [(551,947),(587,947),(626,949),(668,955),(705,966),
    (728,981),(738,998),(724,1008),(691,1009),(654,1007),(609,999),
    (580,985),(564,967)]
let eraseDrop: [Point] = [(706,1034),(734,1034),(738,1045),(738,1072),
    (701,1072),(701,1045)]
var clean = base
// Remove only the frozen pendant in the illustration; nearby water supplies
// matching texture for the brief interval between physical falling droplets.
for y in Int(1033*scale)...Int(1074*scale) { for x in Int(700*scale)...Int(740*scale) {
    let px = Double(x)/scale, py = Double(y)/scale
    let a = polygonMask(px, py, eraseDrop, feather: 4.5)
    if a > 0 { let i = (y*w+x)*4
        let mix=clamp((px-695)/53)
        for c in 0..<3 {
            let background=sample(base,695*scale,Double(y),c)*(1-mix)+sample(base,748*scale,Double(y),c)*mix
            clean[i+c]=UInt8(clamp(Double(base[i+c])*(1-a)+background*a,0,255))
        }
    }
}}
// The still illustration also contains a permanently drawn impact ring. Replace
// that small water-only patch before drawing rings whose radii actually grow.
for y in Int(1068*scale)...Int(1106*scale) { for x in Int(658*scale)...Int(780*scale) {
    let px=Double(x)/scale,py=Double(y)/scale
    let ellipse=pow((px-719)/61,2)+pow((py-1087)/19,2)
    let a=smooth((1-ellipse)*3)*0.94
    if a>0 {let i=(y*w+x)*4
        for c in 0..<3 {clean[i+c]=UInt8(clamp(Double(base[i+c])*(1-a)+sample(base,Double(x)+23*scale,Double(y)+26*scale,c)*a,0,255))}
    }
}}
let x0 = Int(300*scale), x1 = Int(869*scale)
let y0 = Int(941*scale), y1 = Int(1168*scale)
let originX = 719.0, originY = 1031.0, impactX = 719.0, impactY = 1081.0
var poolMask = [Double](repeating: 0, count: w*h)
var innerMask = poolMask
for y in y0...y1 { for x in x0...x1 {
    let px = Double(x)/scale, py = Double(y)/scale
    poolMask[y*w+x] = polygonMask(px,py,pool,feather: 5)
    innerMask[y*w+x] = polygonMask(px,py,inner,feather: 4)
}}
func colorBlend(_ pixels: inout [UInt8], _ x: Int, _ y: Int, _ color: [Double], _ alpha: Double) {
    guard x>=0, y>=0, x<w, y<h else { return }
    let i = (y*w+x)*4, a = clamp(alpha)
    for c in 0..<3 { pixels[i+c] = UInt8(clamp(Double(pixels[i+c])*(1-a)+color[c]*a,0,255)) }
}
func drawDrop(_ pixels: inout [UInt8], x: Double, y: Double, radius: Double, length: Double, alpha: Double) {
    let cx = x*scale, cy = y*scale, rx = max(0.65,radius*scale), ry = max(0.8,length*scale)
    for yy in Int(floor(cy-ry-1))...Int(ceil(cy+ry+1)) {
        for xx in Int(floor(cx-rx-1))...Int(ceil(cx+rx+1)) {
            let dx = (Double(xx)-cx)/rx, dy = (Double(yy)-cy)/ry
            let a = clamp((1-dx*dx-dy*dy)*2.5)*alpha
            if a>0 {
                colorBlend(&pixels,xx,yy,[117,139,164],a*0.85)
                if xx<=Int(cx), yy<=Int(cy) { colorBlend(&pixels,xx,yy,[185,194,201],a*0.65) }
            }
        }
    }
}
func frame(_ time: Double) -> [UInt8] {
    var pixels = clean
    let phase = tau*time/duration
    for y in y0...y1 { for x in x0...x1 {
        let m = poolMask[y*w+x], im = innerMask[y*w+x]
        let px = Double(x)/scale, py = Double(y)/scale, i = (y*w+x)*4
        if m > 0 {
            let dx = px-impactX, dy = (py-impactY)/0.30
            let distance = max(1,hypot(dx,dy))
            var displacement = 0.45*sin(px*0.065+py*0.043-phase*3)
            var glint = 1.0*sin(px*0.09+py*0.11-phase*2)
            // Four impacts per eight-second loop; modulo time also carries
            // fading ripples from the previous loop through the seam.
            for impact in [1.55,3.55,5.55,7.55] {
                let age = (time-impact+duration).truncatingRemainder(dividingBy: duration)
                guard age < 2.25 else { continue }
                let radius = 7+age*76
                let width = 3.0+age*1.7
                let ring = exp(-pow((distance-radius)/width,2))
                let trough = exp(-pow((distance-radius+5.5)/4.5,2))
                let fade = pow(max(0,1-age/2.25),1.45)*smooth(age/0.12)
                displacement += sin((distance-radius)/5)*exp(-pow((distance-radius)/18,2))*fade*1.25
                glint += (ring*15-trough*5)*fade
                let second = exp(-pow((distance-radius*0.73)/4.5,2))
                glint += second*4.5*fade
            }
            let sx = Double(x)+dx/distance*displacement*scale*m
            let sy = Double(y)+dy/distance*displacement*scale*0.3*m
            for c in 0..<3 {
                let tint = [0.73,0.92,1.0][c]
                let warped = sample(clean,sx,sy,c)
                pixels[i+c] = UInt8(clamp(Double(clean[i+c])*(1-m)+(warped+glint*tint)*m,0,255))
            }
        }
        if im > 0 {
            let wave = sin(px*0.072+py*0.11-phase*4)
            let sx = Double(x)+0.68*scale*wave*im
            let sy = Double(y)+0.48*scale*sin(px*0.05-phase*3)*im
            let highlight = sin(px*0.13+py*0.22-phase*3)*2.8
            for c in 0..<3 {
                pixels[i+c] = UInt8(clamp(Double(clean[i+c])*(1-im)+(sample(clean,sx,sy,c)+highlight*[0.65,0.85,1.0][c])*im,0,255))
            }
        }
    }}
    let u = time.truncatingRemainder(dividingBy: 2)
    if u < 1.25 {
        let growth = smooth(u/1.25)
        drawDrop(&pixels,x:originX,y:originY+2+3.5*growth,radius:1.5+2*growth,length:2+4*growth,alpha:0.9)
    } else if u < 1.55 {
        let fall = (u-1.25)/0.30
        let yy = originY+6+(impactY-originY-6)*fall*fall
        drawDrop(&pixels,x:originX,y:yy,radius:3.2,length:5.2+2.5*fall,alpha:0.95)
        drawDrop(&pixels,x:originX,y:originY+1,radius:1.1,length:1.4,alpha:0.6)
    } else {
        drawDrop(&pixels,x:originX,y:originY+1,radius:1.1,length:1.4,alpha:0.7)
        let age = u-1.55
        if age<0.15 {
            let a = sin(.pi*age/0.15)*0.7
            drawDrop(&pixels,x:impactX-7,y:impactY-6-8*sin(.pi*age/0.15),radius:1.2,length:1.8,alpha:a)
            drawDrop(&pixels,x:impactX+6,y:impactY-4-5*sin(.pi*age/0.15),radius:1.0,length:1.5,alpha:a)
        }
    }
    return pixels
}

// Fixed shared palette prevents static-shell or ground shimmer from per-frame
// GIF quantization. Quantization and LZW follow existing shrine GIF exporters.
struct ColorBin { let r:Int; let g:Int; let b:Int; let count:Int }
var histogram: [Int:Int] = [:]
for y in stride(from:0,to:h,by:2) { for x in stride(from:0,to:w,by:2) {
    let i=(y*w+x)*4
    let key=(Int(base[i])>>3)<<10 | (Int(base[i+1])>>3)<<5 | (Int(base[i+2])>>3)
    histogram[key,default:0] += 1
}}
var boxes=[histogram.map { key,count in ColorBin(r:((key>>10)&31)*8+4,g:((key>>5)&31)*8+4,b:(key&31)*8+4,count:count) }]
func spread(_ box:[ColorBin]) -> (Int,Int) {
    let ranges=[box.map(\.r).max()!-box.map(\.r).min()!,box.map(\.g).max()!-box.map(\.g).min()!,box.map(\.b).max()!-box.map(\.b).min()!]
    let axis=ranges.enumerated().max(by:{$0.element<$1.element})!.offset
    return (axis,ranges[axis])
}
while boxes.count<256 {
    let candidate=boxes.indices.filter{boxes[$0].count>1}.max {
        Double(spread(boxes[$0]).1)*sqrt(Double(boxes[$0].reduce(0){$0+$1.count})) < Double(spread(boxes[$1]).1)*sqrt(Double(boxes[$1].reduce(0){$0+$1.count}))
    }
    guard let index=candidate else { break }
    let axis=spread(boxes[index]).0
    let ordered=boxes.remove(at:index).sorted{a,b in (axis==0 ? a.r : axis==1 ? a.g:a.b) < (axis==0 ? b.r : axis==1 ? b.g:b.b)}
    let total=ordered.reduce(0){$0+$1.count}
    var count=0,split=1
    for j in 0..<(ordered.count-1) {count += ordered[j].count;split=j+1;if count>=total/2{break}}
    boxes.append(Array(ordered[..<split]));boxes.append(Array(ordered[split...]))
}
var palette:[[Int]]=boxes.map {box in
    let total=box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 {palette.append(palette.last!)}
var colorCache=[Int](repeating:-1,count:32768)
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
    let key=(Int(r)>>3)<<10 | (Int(g)>>3)<<5 | (Int(b)>>3)
    if colorCache[key]>=0{return UInt8(colorCache[key])}
    let rr=((key>>10)&31)*8+4,gg=((key>>5)&31)*8+4,bb=(key&31)*8+4
    var best=0,distance=Int.max
    for j in 0..<256 {
        let dr=palette[j][0]-rr,dg=palette[j][1]-gg,db=palette[j][2]-bb
        let d=dr*dr*2+dg*dg*3+db*db*2
        if d<distance{distance=d;best=j}
    }
    colorCache[key]=best;return UInt8(best)
}
func lzw(_ bytes:[UInt8])->[UInt8] {
    var encoded:[UInt8]=[],accumulator=0,bitCount=0
    func emit(_ code:Int) {
        accumulator |= code<<bitCount;bitCount += 9
        while bitCount>=8{encoded.append(UInt8(accumulator&255));accumulator >>= 8;bitCount -= 8}
    }
    var table:[Int:Int]=[:],next=258,prefix=Int(bytes[0]);emit(256)
    for value in bytes.dropFirst() {
        let byte=Int(value),key=(prefix<<8)|byte
        if let code=table[key]{prefix=code}
        else{emit(prefix);table[key]=next;next += 1;prefix=byte
            if next>=500{emit(256);table.removeAll(keepingCapacity:true);next=258}}
    }
    emit(prefix);emit(257);if bitCount>0{encoded.append(UInt8(accumulator&255))};return encoded
}
var gif=Data("GIF89a".utf8)
func byte(_ n:Int){gif.append(UInt8(n))}
func word(_ n:Int){byte(n&255);byte((n>>8)&255)}
word(w);word(h);byte(0xF7);byte(0);byte(0)
for color in palette{for value in color{byte(value)}}
gif.append(contentsOf:[0x21,0xFF,0x0B]);gif.append(Data("NETSCAPE2.0".utf8));gif.append(contentsOf:[3,1,0,0,0])
var first:[UInt8]=[],previous:[UInt8]=[],last:[UInt8]=[]
var maxDelta=0.0,changingPixels=Set<Int>(),outsideChanges=0
var snapshots:[[UInt8]]=[]
for index in 0..<frameCount {
    let pixels=frame(Double(index)/Double(fps))
    if index==0{first=pixels}
    if [0,30,37,41,50,70].contains(index){snapshots.append(pixels)}
    var delta=0.0
    if !previous.isEmpty {
        for y in 0..<h{for x in 0..<w{
            let i=(y*w+x)*4
            for c in 0..<3 where pixels[i+c] != first[i+c] {
                changingPixels.insert(y*w+x)
                if x<x0 || x>x1 || y<y0 || y>y1{outsideChanges += 1}
            }
            if x>=x0,x<=x1,y>=y0,y<=y1 {
                for c in 0..<3{delta += abs(Double(pixels[i+c])-Double(previous[i+c]))}
            }
        }}
        maxDelta=max(maxDelta,delta/Double((x1-x0+1)*(y1-y0+1)*3))
    }
    previous=pixels;last=pixels
    let left=index==0 ? 0:x0,top=index==0 ? 0:y0
    let width=index==0 ? w:x1-x0+1,height=index==0 ? h:y1-y0+1
    var indices=[UInt8]();indices.reserveCapacity(width*height)
    for y in top..<(top+height){for x in left..<(left+width){
        let i=(y*w+x)*4;indices.append(paletteIndex(pixels[i],pixels[i+1],pixels[i+2]))
    }}
    gif.append(contentsOf:[0x21,0xF9,4,4,4,0,0,0,0x2C])
    word(left);word(top);word(width);word(height);byte(0);byte(8)
    let data=lzw(indices)
    for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])}
    byte(0)
    if index%50==0{print("Rendered \(index)/\(frameCount)")}
}
byte(0x3B);try gif.write(to:output)
var seam=0.0
for y in y0...y1{for x in x0...x1{for c in 0..<3{
    let i=(y*w+x)*4+c;seam += abs(Double(first[i])-Double(last[i]))
}}}
seam /= Double((x1-x0+1)*(y1-y0+1)*3)
precondition(outsideChanges==0,"Motion leaked outside water region")
precondition(changingPixels.count>200,"Water should animate")
precondition(seam<=maxDelta*1.4,"Loop seam is too abrupt")
guard let check=CGImageSourceCreateWithURL(output as CFURL,nil),CGImageSourceGetCount(check)==frameCount,
      CGImageSourceCreateImageAtIndex(check,frameCount-1,nil) != nil else{fatalError("Invalid GIF")}
let meta=CGImageSourceCopyProperties(check,nil)! as NSDictionary
precondition((meta[kCGImagePropertyGIFDictionary] as? NSDictionary)?[kCGImagePropertyGIFLoopCount] as? Int == 0)
var decodedDuration=0.0
for j in 0..<frameCount {
    let props=CGImageSourceCopyPropertiesAtIndex(check,j,nil)! as NSDictionary
    let values=props[kCGImagePropertyGIFDictionary] as! NSDictionary
    decodedDuration += (values[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (values[kCGImagePropertyGIFDelayTime] as! Double)
}
precondition(abs(decodedDuration-duration)<0.001)
func makeImage(_ pixels:[UInt8])->CGImage {
    CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,
            bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),provider:CGDataProvider(data:Data(pixels) as CFData)!,
            decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
let cropW=x1-x0+1,cropH=y1-y0+1,zoom=2
let sheetW=cropW*zoom*2,sheetH=cropH*zoom*3
let sheet=CGContext(data:nil,width:sheetW,height:sheetH,bitsPerComponent:8,bytesPerRow:sheetW*4,space:space,bitmapInfo:bitmapInfo)!
sheet.interpolationQuality = .none
for (j,pixels) in snapshots.enumerated(){
    let crop=makeImage(pixels).cropping(to:CGRect(x:x0,y:y0,width:cropW,height:cropH))!
    sheet.draw(crop,in:CGRect(x:(j%2)*cropW*zoom,y:(2-j/2)*cropH*zoom,width:cropW*zoom,height:cropH*zoom))
}
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-1-puddle-motion-check-v1.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
let report="""
Rank1 shell: \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
Only inner water, pendant/falling droplets and small puddle move. Four drops per loop.
Water patch bounds: \(x0),\(y0) to \(x1),\(y1). Puddle shoreline remains fixed.
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette, no temporal dithering.
GIF has no audio. Illustration, shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-1-puddle-animation-v1-report.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
