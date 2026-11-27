import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/ember-workshop/stages-v1")
let w=600,h=656,fps=25,n=300
let tau=Double.pi*2
let space=CGColorSpaceCreateDeviceRGB()
let info=CGImageAlphaInfo.premultipliedLast.rawValue
let src=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-3-mechanical-v2-compact.png") as CFURL,nil)!
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
let ps=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-3-mechanical-v2-cleanplate.png") as CFURL,nil)!
var plate=[UInt8](repeating:0,count:w*h*4)
plate.withUnsafeMutableBytes{b in
 let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:info)!
 c.interpolationQuality = .high;c.draw(CGImageSourceCreateImageAtIndex(ps,0,nil)!,in:CGRect(x:0,y:0,width:w,height:h))
}
func sample(_ p:[UInt8],_ x:Double,_ y:Double,_ c:Int)->Double{
 let xx=min(Double(w-2),max(0,x)),yy=min(Double(h-2),max(0,y)),ix=Int(xx),iy=Int(yy)
 let fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
 return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
}
typealias Point=(Double,Double)
let hammer:[Point]=[(260,347),(268,345),(277,348),(277,362),(271,365),(271,373),(265,373),(265,365),(260,363)]
func mask(_ x:Double,_ y:Double)->Double{
 var inside=false,d=1000.0
 for j in hammer.indices{
  let a=hammer[j],b=hammer[(j+1)%hammer.count]
  if (a.1>y) != (b.1>y),x<(b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0{inside.toggle()}
  let dx=b.0-a.0,dy=b.1-a.1,t=clamp(((x-a.0)*dx+(y-a.1)*dy)/(dx*dx+dy*dy))
  d=min(d,hypot(x-a.0-t*dx,y-a.1-t*dy))
 }
 return inside ? clamp(d/0.65):0
}
var clean=base
// Motion-only plate patches retain the original image everywhere else.
for y in 335..<377{for x in 257..<281{
 let i=(y*w+x)*4,a=clamp(Double(min(x-257,280-x,y-335,376-y))/2)
 for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
}}
for y in 344..<389{for x in 329..<367{
 let r=hypot((Double(x)-349.4)/17.6,(Double(y)-366.3)/22.2)
 let a=clamp((1-r)*12)
 let i=(y*w+x)*4
 for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
}}
for y in 10..<88{for x in 184..<273{let i=(y*w+x)*4;for c in 0..<3{clean[i+c]=0}}}
for y in 161..<222{for x in 261..<287{
 let i=(y*w+x)*4
 if base[i]>130 && Double(base[i])>Double(base[i+1])*1.4{
  for yy in (y-3)...(y+3){for xx in (x-3)...(x+3){
   let a=clamp((3.8-hypot(Double(xx-x),Double(yy-y)))/1.6)
   for c in 0..<3{
    let neighbors=[base[(yy*w+xx-5)*4+c],base[(yy*w+xx+5)*4+c],base[((yy-5)*w+xx)*4+c],base[((yy+5)*w+xx)*4+c]].sorted()
    let value=(Double(neighbors[1])+Double(neighbors[2]))/2
    let j=(yy*w+xx)*4+c
    clean[j]=UInt8(Double(clean[j])*(1-a)+value*a)
   }
  }}
 }
}}
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
 let wheel=tau*t/2
 // Six metal spokes revolve in the wheel's original elliptical plane.
 for y in 344..<389{for x in 329..<369{
  let nx=(Double(x)-349.4)/17.6,ny=(Double(y)-366.3)/22.2
  let r=hypot(nx,ny),a=atan2(ny,nx)
  if r>0.18 && r<0.98{
   let spoke=abs(sin((a-wheel)*3))*r
   let alpha=clamp((0.15-spoke)/0.045)*clamp((0.98-r)/0.10)
   let bevel=clamp((0.15-spoke)/0.15)
   let wear=sin(Double(x)*2.9+Double(y)*1.7)*4
   blend(&p,x,y,[95+bevel*42+wear,67+bevel*31+wear,50+bevel*22+wear],alpha)
  }
 }}
 // Keep the original hub and the belt in FRONT of the rotating spokes.
 for y in 344..<389{for x in 329..<369{
  let dx=Double(x)-349.4,dy=Double(y)-366.3
  let hub=hypot(dx/7,dy/8)
  let belt=abs((Double(y)-331.5)-0.65*(Double(x)-297))/sqrt(1+0.65*0.65)
  if hub<1 || (belt<2.4 && x<352 && y<368){
   let i=(y*w+x)*4;for c in 0..<3{p[i+c]=base[i+c]}
  }
 }}
 // Vertical sliding head is one rigid sprite; no frame, bench or ground warps.
 let down=pow(0.5+0.5*cos(wheel),3)
 let offset = -7+14*down
 for y in 337..<383{for x in 257..<280{
  let sy=Double(y)-offset,a=mask(Double(x),sy)
  if a>0{let i=(y*w+x)*4;for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,Double(x),sy,c)*a)}}
 }}
 // Belt seams travel along both straight runs, with restrained contrast.
 for y in 326..<367{for x in 294..<351{
  let line=Double(y)-331.5-0.65*(Double(x)-297)
  if abs(line)<1.8{
   let u=(Double(x)-297)/52
   let seam=pow(max(0,cos(tau*u*3-wheel*3)),18)*0.22
   blend(&p,x,y,[91,44,25],seam)
  }
 }}
 let pulse=0.50+0.23*sin(phase*7)+0.13*sin(phase*19+1)+0.07*sin(phase*31)
 for y in 227..<344{for x in 173..<303{
  let i=(y*w+x)*4
  let hot=clamp((Double(clean[i])-Double(clean[i+1])*1.4-8)/75)
  let cavity=exp(-pow((Double(x)-221)/38,4)-pow((Double(y)-278)/29,4))
  for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])+hot*cavity*(pulse-0.4)*[100.0,46.0,9.0][c])))}
 }}
 let dt=t.truncatingRemainder(dividingBy:2)
 if dt<0.55{
  let flash=exp(-dt*28)
  for y in 373..<387{for x in 251..<284{
   let d=pow((Double(x)-269)/12,2)+pow((Double(y)-380)/4,2)
   blend(&p,x,y,[255,210,93],exp(-d*2)*flash*0.75)
  }}
  for k in 0..<13{
   let seed=Double(k),vx=sin(seed*2.4)*53,vy = -24-40*(0.5+0.5*sin(seed*5.8))
   let x=269+vx*dt,y=378+vy*dt+80*dt*dt,a=pow(1-dt/0.55,0.7)
   for yy in Int(y-2)...Int(y+2){for xx in Int(x-2)...Int(x+2){
    blend(&p,xx,yy,[255,155,43],clamp(1.4-hypot(Double(xx)-x,Double(yy)-y))*a)
   }}
  }
 }
 // Wispy continuous smoke: packets rise, broaden, sway and fade smoothly.
 for k in 0..<9{
  let u=(t/6.0+Double(k)/9).truncatingRemainder(dividingBy:1)
  let yy=94-u*82
  let xx=188+sin(u*9-phase*2+Double(k)*0.5)*(4+u*13)
  let rx=3+u*10,ry=5+u*12
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
  let x=221+sin(seed*7.3)*22+sin(seed*3.1+u*5)*(8+u*17)
  let y=284-u*(48+38*(0.5+0.5*sin(seed*5.1)))
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
 let left=f==0 ? 0:155,top=f==0 ? 0:0,width=f==0 ? w:216,height=f==0 ? h:393
 var indices:[UInt8]=[]
 for y in top..<(top+height){for x in left..<(left+width){let k=y*w+x,i=k*4,v=idx(p[i],p[i+1],p[i+2]);indices.append(f>0 && previous[k]==v ? 0:v);previous[k]=v}}
 // Transparency uses index 0 only on delta frames; black is opaque on first.
 gif.append(contentsOf:[0x21,0xF9,4,UInt8(f==0 ? 4:5),4,0,0,0,0x2C]);word(left);word(top);word(width);word(height);byte(0);byte(8)
 let data=lzw(indices)
 for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 if f%50==0{print("Rendered \(f)/\(n)")}
}
byte(0x3B)
let out=folder.appendingPathComponent("rank-3-mechanical-animation-v1.gif")
try gif.write(to:out)
let check=CGImageSourceCreateWithURL(out as CFURL,nil)!
precondition(CGImageSourceGetCount(check)==n)
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-3-mechanical-animation-v1-check.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,image(frame(22)),nil);precondition(CGImageDestinationFinalize(preview))
let sheet=CGContext(data:nil,width:660,height:350,bitsPerComponent:8,bytesPerRow:660*4,space:space,bitmapInfo:info)!
sheet.interpolationQuality = .none
for (j,f) in [0,8,18,27,39,49].enumerated(){
 let crop=image(frame(f)).cropping(to:CGRect(x:250,y:324,width:125,height:72))!
 sheet.draw(crop,in:CGRect(x:(j%3)*220,y:(1-j/3)*175,width:218,height:150))
}
let sd=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-3-mechanical-motion-sheet.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(sd,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(sd))
print("Verified: \(w)x\(h), \(n) frames, 25fps, 12 seconds, infinite loop. \(gif.count) bytes")
print(out.path)
