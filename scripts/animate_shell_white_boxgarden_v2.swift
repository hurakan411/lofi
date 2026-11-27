import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// White circular-platform boxgarden, rank1 or rank2; only contained water moves.
// Coordinates are in the 1070x1470 approved plate, output at sixty percent.
let rank=Int(CommandLine.arguments.dropFirst().first ?? "1")!
precondition(rank==1 || rank==2)
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shell-harbor/white-boxgarden-v1")
let input=folder.appendingPathComponent("rank-\(rank).png")
let output=folder.appendingPathComponent("rank-\(rank)-animation-v2.gif")
let w=642,h=882,fps=25,frameCount=rank==1 ? 300:400
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
var clean=base
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
let basin:[Point] = rank==1
    ? [(547,936),(588,934),(628,939),(668,946),(701,957),(724,973),
       (735,990),(726,1003),(695,1009),(658,1006),(616,997),(575,981),(555,959)]
    : [(477,804),(539,791),(607,786),(671,791),(730,801),(785,820),
       (827,843),(847,864),(835,884),(805,900),(775,914),(752,933),
       (711,949),(671,955),(619,949),(568,935),(512,925),(469,907),
       (428,883),(398,863),(383,847),(408,830),(439,815)]
let pond:[Point] = rank==1
    ? [(520,1021),(572,1020),(623,1026),(670,1026),(708,1027),(740,1033),
       (779,1038),(807,1046),(824,1060),(818,1076),(784,1090),(750,1098),
       (718,1114),(659,1127),(597,1131),(541,1127),(501,1118),(458,1103),
       (428,1087),(411,1074),(405,1056),(428,1044),(469,1036)]
    : [(314,958),(295,969),(264,989),(235,1006),(210,1028),(205,1049),
       (229,1066),(266,1080),(307,1096),(354,1114),(411,1136),(473,1142),
       (540,1147),(608,1150),(677,1143),(744,1131),(789,1117),(826,1101),
       (856,1086),(897,1078),(924,1062),(927,1043),(902,1027),(906,1004),
       (900,982),(878,966),(854,953),(834,937),(804,951),(778,966),(753,980),
       (756,1011),(756,1027),(735,1037),(706,1022),(687,1004),(655,1009),
       (605,1005),(558,999),(503,995),(446,981),(396,971),(352,966)]
struct Flow{let start:Point;let end:Point;let width:Double;let bend:Double}
let flows:[Flow] = rank==1
    ? [Flow(start:(699,1017),end:(699,1062),width:15,bend:0.6)]
    : [Flow(start:(494,740),end:(494,831),width:2.6,bend:0.45),
       Flow(start:(610,704),end:(610,806),width:2.5,bend:0.35),
       Flow(start:(704,948),end:(739,1024),width:29,bend:3)]
let waterX0=Int((rank==1 ? 398.0:196.0)*scale)
let waterX1=Int((rank==1 ? 834.0:936.0)*scale)
let waterY0=Int((rank==1 ? 930.0:696.0)*scale)
let waterY1=Int((rank==1 ? 1140.0:1160.0)*scale)
let x0=waterX0,x1=waterX1,y0=waterY0,y1=waterY1
// Replace the baked rank1 droplet locally before rendering unbroken water.
if rank==1 {
    let patch:[Point]=[(687,1027),(711,1027),(715,1036),(715,1053),(685,1053),(685,1038)]
    for y in Int(1026*scale)...Int(1055*scale) {
        for x in Int(683*scale)...Int(717*scale) {
            let px=Double(x)/scale,py=Double(y)/scale
            let a=polygonMask(px,py,patch,feather:4)
            if a>0 {
                let mix=clamp((px-677)/47),i=(y*w+x)*4
                for c in 0..<3 {
                    let background=sample(base,677*scale,Double(y),c)*(1-mix)+sample(base,724*scale,Double(y),c)*mix
                    clean[i+c]=UInt8(clamp(Double(base[i+c])*(1-a)+background*a,0,255))
                }
            }
        }
    }
}
var basinMask=[Double](repeating:0,count:w*h),pondMask=basinMask,permittedWater=basinMask
struct FishJump {
    let start:Double
    let from:Point
    let to:Point
    let height:Double
    let length:Double
    let color:[Double]
    let flight=1.12
}
let fishJumps:[FishJump] = rank==2 ? [
    FishJump(start:3.5,from:(524,877),to:(585,886),height:55,length:22,color:[181,199,205]),
    FishJump(start:4.12,from:(669,873),to:(718,889),height:47,length:19,color:[206,174,159]),
    FishJump(start:10.3,from:(457,1086),to:(521,1097),height:43,length:21,color:[174,194,204])
] : []
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
    // Explicitly allow only the short fish arcs and their landing splashes.
    for f in fishJumps {
        if px>=min(f.from.0,f.to.0)-40 && px<=max(f.from.0,f.to.0)+52 &&
           py>=min(f.from.1,f.to.1)-f.height-18 && py<=max(f.from.1,f.to.1)+18 {permittedWater[p]=1}
    }
}}
func colorBlend(_ p:inout[UInt8],_ x:Int,_ y:Int,_ color:[Double],_ alpha:Double){
    guard x>=0,y>=0,x<w,y<h else{return}
    let i=(y*w+x)*4,a=clamp(alpha)
    for c in 0..<3{p[i+c]=UInt8(clamp(Double(p[i+c])*(1-a)+color[c]*a,0,255))}
}
// Small native fish silhouettes follow a continuous ballistic arc. Body, tail,
// fin and eye share one transform so they cannot separate during rotation.
func drawFishJump(_ pixels:inout[UInt8],_ fish:FishJump,_ time:Double) {
    let elapsed=time-fish.start
    guard elapsed>=0 && elapsed<fish.flight+1.55 else{return}
    func splash(_ at:Point,_ age:Double,_ strength:Double) {
        guard age>=0 && age<1.55 else{return}
        let radius=5+age*24
        let fade=pow(1-age/1.55,1.5)*strength
        for y in Int((at.1-17)*scale)...Int((at.1+18)*scale) {
            for x in Int((at.0-45)*scale)...Int((at.0+45)*scale) {
                guard x>=0,y>=0,x<w,y<h else{continue}
                let water=max(basinMask[y*w+x],pondMask[y*w+x])
                guard water>0 else{continue}
                let r=hypot(Double(x)/scale-at.0,(Double(y)/scale-at.1)/0.30)
                let ring=exp(-pow((r-radius)/1.9,2)) + 0.5*exp(-pow((r-radius*0.68)/1.3,2))
                colorBlend(&pixels,x,y,[207,221,226],ring*fade*0.72*water)
            }
        }
        if age<0.58 {
            for k in 0..<6 {
                let t=age/0.58
                let spread=(Double(k)-2.5)*7.2
                let xx=at.0+spread*t
                let yy=at.1-(18+Double(k%3)*6)*4*t*(1-t)
                for y in Int((yy-2)*scale)...Int((yy+2)*scale) {
                    for x in Int((xx-2)*scale)...Int((xx+2)*scale) {
                        let d=hypot(Double(x)/scale-xx,(Double(y)/scale-yy)*0.8)
                        colorBlend(&pixels,x,y,[203,221,231],clamp(1.5-d)*strength*(1-t)*0.8)
                    }
                }
            }
        }
    }
    splash(fish.from,elapsed,0.60)
    splash(fish.to,elapsed-fish.flight,1.0)
    guard elapsed<fish.flight else{return}
    let t=elapsed/fish.flight
    let cx=fish.from.0+(fish.to.0-fish.from.0)*t
    let cy=fish.from.1+(fish.to.1-fish.from.1)*t-fish.height*4*t*(1-t)
    let vx=fish.to.0-fish.from.0
    let vy=fish.to.1-fish.from.1-fish.height*4*(1-2*t)
    let angle=atan2(vy,vx),ca=cos(angle),sa=sin(angle)
    let visibility=smooth(t/0.075)*smooth((1-t)/0.08)
    let half=fish.length*0.5,bodyH=fish.length*0.17
    let flutter=sin(t*tau*5)*0.8
    for y in Int((cy-fish.length)*scale)...Int((cy+fish.length)*scale) {
        for x in Int((cx-fish.length)*scale)...Int((cx+fish.length)*scale) {
            let dx=Double(x)/scale-cx,dy=Double(y)/scale-cy
            let u=dx*ca+dy*sa,v=dy*ca-dx*sa
            let body=clamp((1-pow(u/half,2)-pow(v/bodyH,2))*3)
            let tailT=clamp((-u-half*0.55)/(half*0.70))
            let tail=(u < -half*0.55 && u > -half*1.25)
                ? smooth((bodyH*(0.3+tailT*1.15)-abs(v-flutter*tailT))/1.0):0
            let fin=(u > -half*0.45 && u < half*0.2 && v < 0)
                ? smooth((bodyH*1.4+v)/0.8)*smooth((-v-bodyH*0.55)/0.8):0
            let shade=clamp((v/bodyH+1)*0.5)
            let color=fish.color.map{$0+13-28*shade}
            colorBlend(&pixels,x,y,color,max(body,max(tail*0.85,fin*0.65))*visibility)
            let eye=hypot(u-half*0.58,v+bodyH*0.16)
            if eye<1.05 {colorBlend(&pixels,x,y,[54,68,77],clamp(1.2-eye)*visibility)}
        }
    }
}
func frame(_ time:Double)->[UInt8]{
    var pixels=clean
    let phase=tau*time/duration
    for y in waterY0...waterY1{for x in 0..<w{
        let p=y*w+x,i=p*4,px=Double(x)/scale,py=Double(y)/scale
        let im=basinMask[p],om=pondMask[p],mask=max(im,om)
        guard mask>0 else{continue}
        let movement=rank==1 ? 2.5:1.7
        var sx=movement*0.75*sin(px*0.047+py*0.055-phase*3)
        var sy=movement*0.52*sin(px*0.041-py*0.031-phase*4)
        var light=movement*2.3*sin(px*0.082+py*0.13-phase*3)
        for (j,f) in flows.enumerated(){
            let dx=px-f.end.0,dy=(py-f.end.1)/0.30
            let r=max(1,hypot(dx,dy))
            let large=rank==1 || j==2
            let extent=large ? 235.0:150.0
            let envelope=exp(-r/(large ? 125:80))*smooth(r/7)*smooth((extent-r)/45)
            let wave=tau*r/(large ? 32:26)-phase*Double(large ? 20:18)
            let crest=pow(max(0,cos(wave)),8)
            let strength=rank==1 ? 2.7:(j==2 ? 1.6:1.0)
            sx += dx/r*sin(wave)*envelope*strength
            sy += dy/r*sin(wave)*envelope*strength*0.30
            light += (crest*15-sin(wave)*3.0)*envelope*strength
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
        let broad=f.width>10
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
                let sheen=(sin(dx*(broad ? 0.8:1.4)+travel)*0.5+0.5)*(rank==1 ? 0.45:0.35)+0.16
                let highlight=pow(max(0,cos(dx*0.72+travel*0.7)),8)
                colorBlend(&pixels,x,y,[99+shimmer*21,131+shimmer*20,159+shimmer*20],body*sheen)
                colorBlend(&pixels,x,y,[186,209,221],body*highlight*(rank==1 ? 0.65:0.34))
            }
        }
        // Small churning patch where each flow meets its own receiving surface.
        for y in Int((f.end.1-4)*scale)...Int((f.end.1+5)*scale){
            for x in Int((f.end.0-18)*scale)...Int((f.end.0+19)*scale){
                let dx=(Double(x)/scale-f.end.0)/18,dy=(Double(y)/scale-f.end.1)/4.5
                let alpha=clamp(1-dx*dx-dy*dy)*(rank==1 ? 0.35+0.17*sin(phase*48+dx*8):0.18+0.1*sin(phase*48+dx*8+Double(j)))
                colorBlend(&pixels,x,y,[144,167,184],alpha)
            }
        }
    }
    for fish in fishJumps { drawFishJump(&pixels,fish,time) }
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
histogram.removeValue(forKey:32767)
var boxes=[histogram.map { key,count in ColorBin(r:((key>>10)&31)*8+4,g:((key>>5)&31)*8+4,b:(key&31)*8+4,count:count) }]
func spread(_ box:[ColorBin]) -> (Int,Int) {
    let ranges=[box.map(\.r).max()!-box.map(\.r).min()!,box.map(\.g).max()!-box.map(\.g).min()!,box.map(\.b).max()!-box.map(\.b).min()!]
    let axis=ranges.enumerated().max(by:{$0.element<$1.element})!.offset
    return (axis,ranges[axis])
}
while boxes.count<254 {
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
var palette:[[Int]]=[[0,0,0],[255,255,255]]+boxes.map {box in
    let total=box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 {palette.append(palette.last!)}
var colorCache=[Int](repeating:-1,count:32768)
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
    if r>=253 && g>=253 && b>=253 {return 1}
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
var previousIndices=[UInt8](repeating:0,count:w*h)
var waterChanged=Set<Int>()
for index in 0..<frameCount {
    let pixels=frame(Double(index)/Double(fps))
    if index==0{first=pixels}
    let previewFrames=rank==1 ? [0,17,38,75,119,225]:[0,94,103,117,267,292]
    if previewFrames.contains(index){snapshots.append(pixels)}
    var delta=0.0
    if !previous.isEmpty {
        for y in 0..<h{for x in 0..<w{
            let i=(y*w+x)*4
            for c in 0..<3 where pixels[i+c] != first[i+c] {
                changingPixels.insert(y*w+x)
                let inWater=permittedWater[y*w+x] > 0
                if inWater {waterChanged.insert(y*w+x)}
                if !inWater {outsideChanges += 1}
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
precondition(outsideChanges==0,"Motion leaked onto platform or background")
precondition(waterChanged.count>200,"Water should animate")
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
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-\(rank)-motion-check-v2.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
let report="""
White platform rank \(rank): \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
Stronger water refraction, flowing highlights and expanding ripples. Rank2 adds three fish jumps at 3.5, 4.12 and 10.3 seconds, with takeoff/landing splashes. White disk and background remain static.
Water patch bounds: \(waterX0),\(waterY0) to \(waterX1),\(waterY1). Outer pond shoreline remains fixed inside this rank's loop.
Changed water pixels: \(waterChanged.count).
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette and transparent delta frames.
GIF has no audio. Shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-\(rank)-animation-report-v2.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
