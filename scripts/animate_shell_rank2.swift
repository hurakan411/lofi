import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rank2: a developing shell-bay and the finite pond fed by its overflow.
// Coordinates are in the 1070x1470 approved plate, output at sixty percent.
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shell-harbor/growth-ranks-v1")
let input=folder.appendingPathComponent("rank-2-growing-pond-v2.png")
let output=folder.appendingPathComponent("rank-2-growing-sea-animation-v1.gif")
let w=642,h=882,fps=25,frameCount=300
let duration=Double(frameCount)/Double(fps),scale=0.6,tau=2*Double.pi
let space=CGColorSpaceCreateDeviceRGB()
let bitmapInfo=CGImageAlphaInfo.premultipliedLast.rawValue
func clamp(_ v:Double,_ lo:Double=0,_ hi:Double=1)->Double{min(hi,max(lo,v))}
func smooth(_ v:Double)->Double{let t=clamp(v);return t*t*(3-2*t)}
guard let source=CGImageSourceCreateWithURL(input as CFURL,nil),
      let sourceImage=CGImageSourceCreateImageAtIndex(source,0,nil) else{fatalError("Missing rank2 plate")}
var base=[UInt8](repeating:0,count:w*h*4)
base.withUnsafeMutableBytes{bytes in
    let c=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:bitmapInfo)!
    c.interpolationQuality = .high
    c.draw(sourceImage,in:CGRect(x:0,y:0,width:w,height:h))
}
let clean=base
func sample(_ p:[UInt8],_ x:Double,_ y:Double,_ c:Int)->Double{
    let xx=clamp(x,0,Double(w-2)),yy=clamp(y,0,Double(h-2))
    let ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
    return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
}
typealias Point=(Double,Double)
func polygonMask(_ x:Double,_ y:Double,_ vertices:[Point],feather:Double)->Double{
    var inside=false,distance=Double.greatestFiniteMagnitude
    for j in vertices.indices{
        let a=vertices[j],b=vertices[(j+1)%vertices.count]
        if (a.1>y) != (b.1>y), x<(b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0{inside.toggle()}
        let dx=b.0-a.0,dy=b.1-a.1
        let t=clamp(((x-a.0)*dx+(y-a.1)*dy)/max(0.001,dx*dx+dy*dy))
        distance=min(distance,hypot(x-a.0-t*dx,y-a.1-t*dy))
    }
    return inside ? smooth(distance/feather):0
}
let basin:[Point]=[(478,796),(557,783),(630,782),(699,788),(772,799),(829,819),
    (878,846),(895,875),(882,901),(839,915),(800,932),(765,957),(732,981),
    (700,993),(644,990),(588,978),(537,966),(478,946),(424,924),(375,899),
    (349,878),(354,856),(384,836),(431,818)]
let pond:[Point]=[(83,883),(28,894),(8,909),(32,926),(83,938),(115,957),(85,977),
    (37,993),(11,1020),(20,1046),(65,1061),(117,1071),(128,1098),(174,1120),
    (194,1155),(219,1184),(232,1207),(271,1223),(291,1254),(357,1263),
    (415,1257),(482,1240),(514,1243),(538,1258),(594,1274),(636,1270),
    (662,1268),(706,1285),(754,1284),(801,1270),(824,1266),(871,1240),
    (907,1232),(955,1227),(997,1207),(1046,1180),(1053,1147),(1034,1125),
    (1049,1101),(1042,1079),(1037,1047),(1045,1003),(1032,976),(1046,948),
    (1040,921),(1007,912),(1003,935),(962,960),(914,984),(858,1007),
    (815,1018),(794,1041),(803,1056),(781,1079),(739,1087),(696,1085),
    (655,1090),(593,1083),(524,1087),(457,1076),(378,1070),(294,1054),
    (226,1038),(169,1006),(119,965),(93,930),(83,903)]
struct Flow{let start:Point;let end:Point;let width:Double;let bend:Double}
let flows=[
    Flow(start:(493,727),end:(493,822),width:2.6,bend:0.45),
    Flow(start:(604,684),end:(604,796),width:2.5,bend:0.35),
    Flow(start:(744,990),end:(780,1062),width:24,bend:5)
]
let waterX0=0,waterX1=w-1,waterY0=Int(675*scale),waterY1=Int(1294*scale)
let cloudY1=Int(276*scale)
let x0=0,x1=w-1,y0=0,y1=waterY1
var basinMask=[Double](repeating:0,count:w*h),pondMask=basinMask,permittedWater=basinMask
for y in waterY0...waterY1{for x in 0..<w{
    let px=Double(x)/scale,py=Double(y)/scale,p=y*w+x
    basinMask[p]=polygonMask(px,py,basin,feather:6)
    pondMask[p]=polygonMask(px,py,pond,feather:7)
    permittedWater[p]=max(basinMask[p],pondMask[p])
    for f in flows{
        if py>=f.start.1-5,py<=f.end.1+8{
            let t=clamp((py-f.start.1)/(f.end.1-f.start.1))
            let cx=f.start.0+(f.end.0-f.start.0)*t+f.bend*sin(.pi*t)
            if abs(px-cx)<max(18,f.width*0.85){permittedWater[p]=1}
        }
    }
    for f in flows where abs(py-f.end.1)<13 && abs(px-f.end.0)<26{permittedWater[p]=1}
}}
func colorBlend(_ p:inout[UInt8],_ x:Int,_ y:Int,_ color:[Double],_ alpha:Double){
    guard x>=0,y>=0,x<w,y<h else{return}
    let i=(y*w+x)*4,a=clamp(alpha)
    for c in 0..<3{p[i+c]=UInt8(clamp(Double(p[i+c])*(1-a)+color[c]*a,0,255))}
}
func frame(_ time:Double)->[UInt8]{
    var pixels=clean
    let phase=tau*time/duration
    // Same sky movement and phase as rank1, allowing continuity at a rank change.
    for y in 0...cloudY1{for x in 0..<w{
        let fade=smooth(Double(cloudY1-y)/18),edge=smooth(Double(min(x,w-1-x))/24)
        let depth=0.78+0.22*cos(Double(y)*0.025)
        let drift=(24*sin(phase)+3*sin(phase*2))*scale*depth*fade*edge
        let i=(y*w+x)*4
        for c in 0..<3{pixels[i+c]=UInt8(clamp(sample(clean,Double(x)-drift,Double(y),c),0,255))}
    }}
    for y in waterY0...waterY1{for x in 0..<w{
        let p=y*w+x,i=p*4,px=Double(x)/scale,py=Double(y)/scale
        let im=basinMask[p],om=pondMask[p],mask=max(im,om)
        guard mask>0 else{continue}
        var sx=0.75*sin(px*0.047+py*0.055-phase*3)
        var sy=0.52*sin(px*0.041-py*0.031-phase*4)
        var light=1.6*sin(px*0.082+py*0.13-phase*3)
        for (j,f) in flows.enumerated(){
            let dx=px-f.end.0,dy=(py-f.end.1)/0.30
            let r=max(1,hypot(dx,dy))
            let extent=j==2 ? 250.0:150.0
            let envelope=exp(-r/(j==2 ? 130:80))*smooth(r/7)*smooth((extent-r)/45)
            let wave=tau*r/(j==2 ? 31:26)-phase*Double(j==2 ? 24:18)
            let crest=pow(max(0,cos(wave)),8)
            let strength=j==2 ? 1.0:0.75
            sx += dx/r*sin(wave)*envelope*strength
            sy += dy/r*sin(wave)*envelope*strength*0.30
            light += (crest*11-sin(wave)*2.5)*envelope*strength
        }
        if om>0{
            let radial=hypot((px-780)*0.72,(py-1062)*2)
            light += sin(radial*0.08-phase*7)*0.9
        }
        for c in 0..<3{
            let warped=sample(clean,Double(x)+sx*scale*mask,Double(y)+sy*scale*mask,c)
            pixels[i+c]=UInt8(clamp(Double(clean[i+c])*(1-mask)+(warped+light*[0.68,0.88,1.0][c])*mask,0,255))
        }
    }}
    for (j,f) in flows.enumerated(){
        let broad=j==2
        let startY=Int((f.start.1-1)*scale),endY=Int((f.end.1+3)*scale)
        for y in startY...endY{
            let py=Double(y)/scale,t=clamp((py-f.start.1)/(f.end.1-f.start.1))
            let cx=f.start.0+(f.end.0-f.start.0)*t+f.bend*sin(.pi*t)
            let edgeTaper=broad ? 1.0-0.12*t:1.0-0.28*t
            let half=f.width*0.5*edgeTaper
            for x in Int((cx-half-3)*scale)...Int((cx+half+3)*scale){
                let dx=Double(x)/scale-cx
                let body=smooth((half-abs(dx))/max(1,broad ? 2:0.9))
                guard body>0 else{continue}
                let travel=t*32-phase*Double(broad ? 72:84)+Double(j)
                let shimmer=0.5+0.5*sin(travel)
                // Modulate original translucent flow; do not paint an opaque stripe.
                let sheen=(sin(dx*(broad ? 0.8:1.4)+travel)*0.5+0.5)*0.30+0.12
                let highlight=pow(max(0,cos(dx*0.72+travel*0.7)),8)
                colorBlend(&pixels,x,y,[99+shimmer*21,131+shimmer*20,159+shimmer*20],body*sheen)
                colorBlend(&pixels,x,y,[163,186,204],body*highlight*(broad ? 0.24:0.20))
            }
        }
        // Small churning patch where each flow meets its own receiving surface.
        for y in Int((f.end.1-4)*scale)...Int((f.end.1+5)*scale){
            for x in Int((f.end.0-18)*scale)...Int((f.end.0+19)*scale){
                let dx=(Double(x)/scale-f.end.0)/18,dy=(Double(y)/scale-f.end.1)/4.5
                let alpha=clamp(1-dx*dx-dy*dy)*(0.12+0.07*sin(phase*48+dx*8+Double(j)))
                colorBlend(&pixels,x,y,[144,167,184],alpha)
            }
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
while boxes.count<255 {
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
var palette:[[Int]]=[[0,0,0]]+boxes.map {box in
    let total=box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 {palette.append(palette.last!)}
var colorCache=[Int](repeating:-1,count:32768)
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
    let key=(Int(r)>>3)<<10 | (Int(g)>>3)<<5 | (Int(b)>>3)
    if colorCache[key]>=0{return UInt8(colorCache[key])}
    let rr=((key>>10)&31)*8+4,gg=((key>>5)&31)*8+4,bb=(key&31)*8+4
    var best=1,distance=Int.max
    for j in 1..<256 {
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
var cloudSnapshots:[[UInt8]]=[]
var previousIndices=[UInt8](repeating:0,count:w*h)
var cloudChanged=Set<Int>(),waterChanged=Set<Int>()
for index in 0..<frameCount {
    let pixels=frame(Double(index)/Double(fps))
    if index==0{first=pixels}
    if [0,17,38,75,119,225].contains(index){snapshots.append(pixels)}
    if [0,75,225].contains(index){cloudSnapshots.append(pixels)}
    var delta=0.0
    if !previous.isEmpty {
        for y in 0..<h{for x in 0..<w{
            let i=(y*w+x)*4
            for c in 0..<3 where pixels[i+c] != first[i+c] {
                changingPixels.insert(y*w+x)
                let inWater=permittedWater[y*w+x] > 0
                if y<=cloudY1 {cloudChanged.insert(y*w+x)}
                if inWater {waterChanged.insert(y*w+x)}
                if y>cloudY1 && !inWater {outsideChanges += 1}
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
        let p=y*w+x,i=p*4
        let value=paletteIndex(pixels[i],pixels[i+1],pixels[i+2])
        indices.append(index>0 && previousIndices[p]==value ? 0:value)
        previousIndices[p]=value
    }}
    gif.append(contentsOf:[0x21,0xF9,4,UInt8(index==0 ? 4:5),4,0,0,0,0x2C])
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
precondition(outsideChanges==0,"Motion leaked outside sky/water regions")
precondition(waterChanged.count>200,"Water should animate")
precondition(cloudChanged.count>1000,"Clouds should move")
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
let cropW=waterX1-waterX0+1,cropH=waterY1-waterY0+1,zoom=2
let sheetW=cropW*zoom*2,sheetH=cropH*zoom*3
let sheet=CGContext(data:nil,width:sheetW,height:sheetH,bitsPerComponent:8,bytesPerRow:sheetW*4,space:space,bitmapInfo:bitmapInfo)!
sheet.interpolationQuality = .none
for (j,pixels) in snapshots.enumerated(){
    let crop=makeImage(pixels).cropping(to:CGRect(x:waterX0,y:waterY0,width:cropW,height:cropH))!
    sheet.draw(crop,in:CGRect(x:(j%2)*cropW*zoom,y:(2-j/2)*cropH*zoom,width:cropW*zoom,height:cropH*zoom))
}
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-2-water-motion-check-v1.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
let cloudSheet=CGContext(data:nil,width:w,height:cloudY1*3,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:bitmapInfo)!
cloudSheet.interpolationQuality = .none
for (j,pixels) in cloudSnapshots.enumerated() {
    let crop=makeImage(pixels).cropping(to:CGRect(x:0,y:0,width:w,height:cloudY1))!
    cloudSheet.draw(crop,in:CGRect(x:0,y:(2-j)*cloudY1,width:w,height:cloudY1))
}
let cloudPreview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-2-cloud-motion-check-v1.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(cloudPreview,cloudSheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(cloudPreview))
let report="""
Rank2 shell: \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
Clouds drift with the rank1 timing. Two inner trickles and a broad front spill feed the growing outer pond.
Water patch bounds: \(waterX0),\(waterY0) to \(waterX1),\(waterY1). Outer pond shoreline remains fixed inside this rank's loop.
Changed cloud pixels: \(cloudChanged.count); changed water pixels: \(waterChanged.count).
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette and transparent delta frames.
GIF has no audio. Shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-2-growing-sea-animation-v1-report.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
