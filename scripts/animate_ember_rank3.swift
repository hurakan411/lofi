import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/ember-workshop/stages-v1")
let w=512,h=768,fps=25,n=300
let tau=Double.pi*2
let space=CGColorSpaceCreateDeviceRGB()
let info=CGImageAlphaInfo.premultipliedLast.rawValue
let src=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-3-grandfather-v1.png") as CFURL,nil)!
let original=CGImageSourceCreateImageAtIndex(src,0,nil)!
var base=[UInt8](repeating:0,count:w*h*4)
base.withUnsafeMutableBytes{b in
 let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:info)!
 c.interpolationQuality = .high
 c.draw(original,in:CGRect(x:0,y:0,width:w,height:h))
}
func clamp(_ x:Double)->Double { min(1,max(0,x)) }
func blend(_ p:inout [UInt8],_ x:Int,_ y:Int,_ color:[Double],_ a:Double){
 if x<0 || y<0 || x>=w || y>=h {return}
 let i=(y*w+x)*4,alpha=clamp(a)
 for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])*(1-alpha)+color[c]*alpha)))}
}
func image(_ p:[UInt8])->CGImage{
 CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:info),provider:CGDataProvider(data:Data(p) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
// The original arm+hammer is a rigid articulated sprite, never an image warp.
let plateSource=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-3-grandfather-cleanplate-v1.png") as CFURL,nil)!
let plateImage=CGImageSourceCreateImageAtIndex(plateSource,0,nil)!
var plate=[UInt8](repeating:0,count:w*h*4)
plate.withUnsafeMutableBytes{b in
 let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:info)!
 c.interpolationQuality = .high;c.draw(plateImage,in:CGRect(x:0,y:0,width:w,height:h))
}
typealias Point=(Double,Double)
let shapes:[[Point]]=[
 [(247,413),(254,416),(254,424),(249,435),(242,446),(245,447),(245,452),(239,458),(233,457),(228,452),(230,447),(237,434),(241,421)],
 [(211,455),(246,441),(251,442),(252,447),(217,465)],
 [(205,449),(212,447),(219,450),(220,466),(215,474),(205,472)]
]
func polygon(_ x:Double,_ y:Double,_ pts:[Point])->Double{
 var inside=false,d=1000.0
 for j in pts.indices{
  let a=pts[j],b=pts[(j+1)%pts.count]
  if (a.1>y) != (b.1>y),x<(b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0{inside.toggle()}
  let dx=b.0-a.0,dy=b.1-a.1,t=clamp(((x-a.0)*dx+(y-a.1)*dy)/(dx*dx+dy*dy))
  d=min(d,hypot(x-a.0-t*dx,y-a.1-t*dy))
 }
 return inside ? clamp(d/0.6):0
}
func armMask(_ x:Double,_ y:Double)->Double{shapes.map{polygon(x,y,$0)}.max()!}
func sample(_ p:[UInt8],_ x:Double,_ y:Double,_ c:Int)->Double{
 let xx=min(Double(w-2),max(0,x)),yy=min(Double(h-2),max(0,y)),ix=Int(xx),iy=Int(yy)
 let fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
 return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
}
var clean=base
// Use only local background repair, keep all other original pixels unchanged.
for y in 410..<476{for x in 166..<258{
 let i=(y*w+x)*4
 let edge=Double(min(x-166,257-x,y-410,475-y))
 let a=clamp(edge/2)
 for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
}}
// Remove frozen forge sparks, then replace them with traveling ember motes.
for y in 205..<316{for x in 176..<248{
 let i=(y*w+x)*4
 if base[i]>140 && Double(base[i])>Double(base[i+1])*1.5 && base[i+2]<70{
  for yy in max(0,y-2)...min(h-1,y+2){for xx in max(0,x-2)...min(w-1,x+2){for c in 0..<3{clean[(yy*w+xx)*4+c]=base[(yy*w+xx+5)*4+c]}}}
 }
}}
func smooth(_ x:Double)->Double{let u=clamp(x);return u*u*(3-2*u)}
func hammerAngle(_ time:Double)->Double{
 let t=time.truncatingRemainder(dividingBy:4)
 for start in [0.0,1.35]{
  let x=t-start
  if x>=0 && x<0.80{return 1.25*smooth(x/0.8)}
  if x>=0.8 && x<1.05{return 1.25*(1-pow((x-0.8)/0.25,2))}
  if x>=1.05 && x<1.24{return 0.10*sin((x-1.05)/0.19*Double.pi)}
 }
 return 0
}
// A small fixed palette eliminates frame-to-frame dithering on the stone.
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
func idx(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
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
func frame(_ f:Int)->[UInt8]{
 let t=Double(f)/Double(fps),phase=tau*t/12
 var p=clean
 let angle=hammerAngle(t),ca=cos(angle),sa=sin(angle),pivotX=249.0,pivotY=419.0
 for y in 356..<478{for x in 170..<266{
  let dx=Double(x)-pivotX,dy=Double(y)-pivotY
  let sx=pivotX+ca*dx+sa*dy,sy=pivotY-sa*dx+ca*dy
  let a=armMask(sx,sy)
  if a>0{let i=(y*w+x)*4;for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,sx,sy,c)*a)}}
 }}
 let pulse=0.50+0.22*sin(phase*7)+0.13*sin(phase*19)+0.08*sin(phase*31)
 for y in 267..<378{for x in 150..<255{
  let i=(y*w+x)*4
  let hot=clamp((Double(clean[i])-Double(clean[i+1])*1.4-8)/75)
  let mask=exp(-pow((Double(x)-190)/37,4)-pow((Double(y)-317)/29,4))
  for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])+hot*mask*(pulse-0.4)*[95.0,42.0,8.0][c])))}
 }}
 // Two strikes, then a brief inspection pause. Sparks follow each actual impact.
 for hit in [1.05,2.40]{
  let dt=(t-hit+12).truncatingRemainder(dividingBy:4)
  if dt<0.55{
   let flash=exp(-dt*27)
   for yy in 465..<483{for xx in 190..<225{
    let d=pow((Double(xx)-209)/14,2)+pow((Double(yy)-475)/6,2)
    blend(&p,xx,yy,[255,204,81],exp(-d*2)*flash*0.8)
   }}
   for k in 0..<15{
    let seed=Double(k),vx=sin(seed*2.4)*73,vy = -25-55*(0.5+0.5*sin(seed*5.8))
    let x=210+vx*dt,y=473+vy*dt+90*dt*dt
    let a=pow(1-dt/0.55,0.7)
    for yy in Int(y-2)...Int(y+2){for xx in Int(x-2)...Int(x+2){
     let d=hypot(Double(xx)-x,Double(yy)-y)
     blend(&p,xx,yy,[255,148,39],clamp(1.6-d)*a)
    }}
   }
  }
 }
 // Wispy continuous smoke: packets rise, broaden, sway and fade smoothly.
 for k in 0..<9{
  let u=(t/6.0+Double(k)/9).truncatingRemainder(dividingBy:1)
  let yy=142-u*110
  let xx=156+sin(u*9-phase*2+Double(k)*0.5)*(7+u*26)
  let rx=4+u*14,ry=8+u*17
  let a=pow(sin(Double.pi*u),1.5)*0.32
  for y in max(0,Int(yy-ry*2))...min(h-1,Int(yy+ry*2)){
   for x in max(0,Int(xx-rx*2))...min(w-1,Int(xx+rx*2)){
    let dx=(Double(x)-xx)/rx,dy=(Double(y)-yy)/ry
    let alpha=exp(-2*(dx*dx+dy*dy))*a
    blend(&p,x,y,[115,111,128],alpha)
   }
  }
 }
 // Clearly visible ember motes: periodic flights from the coal to a soft fade.
 for k in 0..<19 {
  let cycle=3.0
  let u=(t/cycle+Double(k)*0.61803398875).truncatingRemainder(dividingBy:1)
  let seed=Double(k)
  let x=190+sin(seed*7.3)*22+sin(seed*3.1+u*5)*(8+u*17)
  let y=324-u*(48+38*(0.5+0.5*sin(seed*5.1)))
  let a=pow(sin(Double.pi*u),0.6)*(0.7+0.3*sin(seed+u*20))
  let radius=k%4==0 ? 1.7:1.0
  for yy in Int(y-3)...Int(y+3){for xx in Int(x-3)...Int(x+3){
   let d=hypot(Double(xx)-x,(Double(yy)-y)*0.7)
   blend(&p,xx,yy,[255,116+45*u,31],a*clamp((radius+0.7-d)/1.0))
  }}
 }
 return p
}
func lzw(_ bytes:[UInt8])->[UInt8]{
 var out:[UInt8]=[],acc=0,bits=0
 func emit(_ c:Int){acc |= c<<bits;bits += 9;while bits>=8{out.append(UInt8(acc&255));acc >>= 8;bits -= 8}}
 var table:[Int:Int]=[:],next=258,prefix=Int(bytes[0]);emit(256)
 for v in bytes.dropFirst(){let b=Int(v),key=(prefix<<8)|b
  if let code=table[key]{prefix=code}else{emit(prefix);table[key]=next;next += 1;prefix=b;if next>=500{emit(256);table.removeAll(keepingCapacity:true);next=258}}
 }
 emit(prefix);emit(257);if bits>0{out.append(UInt8(acc&255))};return out
}
var gif=Data("GIF89a".utf8)
func byte(_ x:Int){gif.append(UInt8(x))}
func word(_ x:Int){byte(x&255);byte((x>>8)&255)}
word(w);word(h);byte(0xF7);byte(0);byte(0)
for color in palette {for c in color {byte(c)}}
gif.append(contentsOf:[0x21,0xFF,11]);gif.append(Data("NETSCAPE2.0".utf8));gif.append(contentsOf:[3,1,0,0,0])
var previous=[UInt8](repeating:0,count:w*h)
for f in 0..<n{
 let p=frame(f)
 let left=f==0 ? 0:108,top=f==0 ? 0:12,width=f==0 ? w:164,height=f==0 ? h:483
 var indices:[UInt8]=[]
 for y in top..<(top+height){for x in left..<(left+width){let k=y*w+x,i=k*4,v=idx(p[i],p[i+1],p[i+2]);indices.append(f>0 && previous[k]==v ? 0:v);previous[k]=v}}
 // Transparency uses index 0 only on delta frames; black is opaque on first.
 gif.append(contentsOf:[0x21,0xF9,4,UInt8(f==0 ? 4:5),4,0,0,0,0x2C]);word(left);word(top);word(width);word(height);byte(0);byte(8)
 let data=lzw(indices)
 for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 if f%50==0{print("Rendered \(f)/\(n)")}
}
byte(0x3B)
let out=folder.appendingPathComponent("rank-3-animation-v1.gif")
try gif.write(to:out)
let check=CGImageSourceCreateWithURL(out as CFURL,nil)!
precondition(CGImageSourceGetCount(check)==n)
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-3-animation-check.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,image(frame(19)),nil);precondition(CGImageDestinationFinalize(preview))
let sheet=CGContext(data:nil,width:512,height:450,bitsPerComponent:8,bytesPerRow:512*4,space:space,bitmapInfo:info)!
for (j,f) in [0,10,19,25,29,60].enumerated(){
 let crop=image(frame(f)).cropping(to:CGRect(x:165,y:355,width:170,height:150))!
 sheet.draw(crop,in:CGRect(x:(j%3)*170,y:(1-j/3)*225,width:170,height:225))
}
let sd=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-3-motion-sheet.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(sd,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(sd))
print("Verified: \(w)x\(h), \(n) frames, 25fps, 12 seconds, infinite loop. \(gif.count) bytes")
print(out.path)
