import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/ember-workshop/stages-v1")
let w=720,h=788,fps=25,n=400
let tau=Double.pi*2
let space=CGColorSpaceCreateDeviceRGB()
let info=CGImageAlphaInfo.premultipliedLast.rawValue
let src=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-5-mechanical-v1.png") as CFURL,nil)!
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

let scale=Double(w)/Double(original.width)
let ps=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-5-mechanical-cleanplate-v1.png") as CFURL,nil)!
var plate=[UInt8](repeating:0,count:w*h*4)
plate.withUnsafeMutableBytes{b in
 let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:info)!
 c.interpolationQuality = .high;c.draw(CGImageSourceCreateImageAtIndex(ps,0,nil)!,in:CGRect(x:0,y:0,width:w,height:h))
}
typealias Point=(Double,Double)
func bounds(_ x:Double,_ y:Double,_ width:Double,_ height:Double)->(ClosedRange<Int>,ClosedRange<Int>){
 (max(0,Int(x*scale))...min(w-1,Int(ceil((x+width)*scale))),max(0,Int(y*scale))...min(h-1,Int(ceil((y+height)*scale))))
}
func sample(_ p:[UInt8],_ x:Double,_ y:Double,_ c:Int)->Double{
 let xx=min(Double(w-2),max(0,x*scale)),yy=min(Double(h-2),max(0,y*scale)),ix=Int(xx),iy=Int(yy)
 let fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
 return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
}
func polygon(_ x:Double,_ y:Double,_ pts:[Point])->Double{
 var inside=false,d=1000.0
 for j in pts.indices{
  let a=pts[j],b=pts[(j+1)%pts.count]
  if (a.1>y) != (b.1>y),x<(b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0{inside.toggle()}
  let dx=b.0-a.0,dy=b.1-a.1,t=clamp(((x-a.0)*dx+(y-a.1)*dy)/(dx*dx+dy*dy))
  d=min(d,hypot(x-a.0-t*dx,y-a.1-t*dy))
 }
 return inside ? clamp(d/0.85):0
}
struct Wheel{let x:Double,y:Double,rx:Double,ry:Double,period:Double}
let wheels=[Wheel(x:650,y:610,rx:72,ry:78,period:4),Wheel(x:464,y:786,rx:17.5,ry:23,period:2),Wheel(x:720,y:367,rx:16.3,ry:20.3,period:3.2)]
let heads:[[Point]]=[[(367,758),(378,756),(386,760),(386,778),(382,782),(382,789),(373,788),(373,781),(367,778)],[(629,337),(638,335),(647,338),(647,350),(642,354),(642,360),(634,359),(634,354),(629,351)]]
let headBoxes:[(Double,Double,Double,Double)]=[(364,747,26,46),(626,329,25,34)]
let awning:[Point]=[(951,360),(1014,372),(1069,381),(1118,389),(1159,414),(1162,448),(1153,462),(1131,463),(1120,469),(1100,463),(1080,469),(1064,463),(1051,465),(1034,458),(1015,465),(1001,453),(988,446),(977,417) ]
var clean=base
for box in headBoxes{
 let (xr,yr)=bounds(box.0,box.1,box.2,box.3)
 for y in yr{for x in xr{let i=(y*w+x)*4,px=Double(x)/scale,py=Double(y)/scale
  let a=clamp(min(px-box.0,box.0+box.2-px,py-box.1,box.1+box.3-py)/2)
  for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
for (j,wh) in wheels.enumerated(){
 let (xr,yr)=bounds(wh.x-wh.rx-2,wh.y-wh.ry-2,wh.rx*2+4,wh.ry*2+4)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,r=hypot((px-wh.x)/wh.rx,(py-wh.y)/wh.ry),a=clamp((1-r)*14),i=(y*w+x)*4
  for c in 0..<3{
   let background=j==0 ? [36.0,27.0,27.0][c]+sin(px*0.12)*2+cos(py*0.09)*2 : Double(plate[i+c])
   clean[i+c]=UInt8(max(0,Double(base[i+c])*(1-a)+background*a))
  }
 }}
}
do{
 let (xr,yr)=bounds(950,360,215,111)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
  let a=clamp(min(px-950,1165-px,py-360,471-py)/2)
  for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
for b in [(110.0,240.0,130.0,125.0),(330.0,0.0,145.0,75.0),(970.0,115.0,150.0,125.0)]{
 let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
 for y in yr{for x in xr{let i=(y*w+x)*4;for c in 0..<3{clean[i+c]=0}}}
}
func distanceToSegment(_ px:Double,_ py:Double,_ a:Point,_ b:Point)->Double{
 let dx=b.0-a.0,dy=b.1-a.1,t=clamp(((px-a.0)*dx+(py-a.1)*dy)/(dx*dx+dy*dy))
 return hypot(px-a.0-t*dx,py-a.1-t*dy)
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
 let t=Double(f)/Double(fps),phase=tau*t/16
 var p=clean
 // Three wheels with independently paced spokes; outer rims stay circular.
 for (j,wh) in wheels.enumerated(){
  let angle=tau*t/wh.period
  let (xr,yr)=bounds(wh.x-wh.rx-2,wh.y-wh.ry-2,wh.rx*2+4,wh.ry*2+4)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,nx=(px-wh.x)/wh.rx,ny=(py-wh.y)/wh.ry,r=hypot(nx,ny)
   if r>0.20 && r<1{
    let a=atan2(ny,nx),d=abs(sin((a-angle)*3))*r
    let width=j==0 ? 0.25:0.16
    let alpha=clamp((width-d)/0.035)*clamp((1-r)/0.06)
    let bevel=clamp((width-d)/width),light=0.85+0.15*cos(a+2)
    let wear=sin(px*2.3+py*3.7)*3
    let color=j==0 ? [129+bevel*64+wear,86+bevel*49+wear,46+bevel*28+wear] : [98+bevel*49+wear,65+bevel*36+wear,42+bevel*24+wear]
    blend(&p,x,y,color.map{$0*light},alpha)
   }
   // Original fixed hubs and supports overlap the moving spoke layer.
   if r<0.26{let i=(y*w+x)*4;for c in 0..<3{p[i+c]=base[i+c]}}
  }}
 }
 // Drive belts cross the central wheel in the foreground.
 let belts:[(Point,Point,Double)]=[((650,609),(714,377),5.5),((637,619),(448,768),5),((658,624),(809,751),5)]
 do{
  let (xr,yr)=bounds(438,373,378,405)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
   for (a,b,width) in belts where distanceToSegment(px,py,a,b)<width{
    let r=Double(base[i]),g=Double(base[i+1]),bb=Double(base[i+2])
    let leather=clamp((r-g*1.15)/20)*clamp((g-bb*1.2)/15)
    if leather>0{
     let seam=pow(max(0,cos(hypot(px-a.0,py-a.1)*0.12-phase*32)),20)*0.20
     for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-leather)+Double(base[i+c])*(1-seam)*leather)}
    }
   }
  }}
 }
 // Two rigid piston sprites: different cycles, both contact the iron exactly.
 for j in 0..<2{
  let period=j==0 ? 2.0:3.2,shift=j==0 ? 0.0:0.6
  let dt=(t+shift).truncatingRemainder(dividingBy:period)
  let down=pow(0.5+0.5*cos(tau*dt/period),4)
  let offset=j==0 ? -10+24*down : -8+17*down
  let b=headBoxes[j],(xr,yr)=bounds(b.0-1,b.1-12,b.2+2,b.3+30)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,sy=py-offset,a=polygon(px,sy,heads[j]),i=(y*w+x)*4
   if a>0{for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,px,sy,c)*a)}}
  }}
  let hx=j==0 ? 378.0:640.0,hy=j==0 ? 803.0:369.0
  if dt<0.7{
   let (fx,fy)=bounds(hx-18,hy-8,36,16)
   for y in fy{for x in fx{
    let px=Double(x)/scale,py=Double(y)/scale,d=pow((px-hx)/14,2)+pow((py-hy)/5,2)
    blend(&p,x,y,[255,208,80],exp(-d*2)*exp(-dt*24)*0.85)
   }}
   for k in 0..<18{
    let seed=Double(k)+Double(j)*0.7,vx=sin(seed*2.4)*90,vy = -38-65*(0.5+0.5*sin(seed*5.8))
    let xx=hx+vx*dt,yy=hy-4+vy*dt+105*dt*dt,a=pow(1-dt/0.7,0.8)
    let (sx,sy)=bounds(xx-3,yy-3,6,6)
    for y in sy{for x in sx{
     let d=hypot(Double(x)/scale-xx,Double(y)/scale-yy)
     blend(&p,x,y,[255,153,35],clamp(2.1-d)*a)
    }}
   }
  }
 }
 // Broad fabric movement, anchored along the upper seam. Background is repaired.
 do{
  let (xr,yr)=bounds(945,356,230,150)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,u=clamp((py-367)/94)
   let dy=16*u*u*sin(phase*3+px*0.014)+4*u*sin(phase*5+px*0.025)
   let dx=3.5*u*sin(phase*2+py*0.018)
   let sx=px-dx,sy=py-dy,a=polygon(sx,sy,awning),i=(y*w+x)*4
   if a>0{for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,sx,sy,c)*a)}}
  }}
 }
 // Hanging cloth ripples, each at its own phase and speed.
 for (j,b) in [(440.0,844.0,47.0,48.0),(830.0,879.0,47.0,68.0),(578.0,442.0,33.0,43.0),(630.0,442.0,29.0,35.0)].enumerated(){
  let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,u=clamp((py-b.1)/b.3)
   let edge=clamp(min(px-b.0,b.0+b.2-px)/5)*sin(Double.pi*u)
   let dx=3.5*u*sin(phase*Double(j%2+2)+u*4+Double(j))*edge,i=(y*w+x)*4
   for c in 0..<3{p[i+c]=UInt8(sample(base,px-dx,py,c))}
  }}
 }
 // Rotating grinding-wheel pores. Keep fixed shaft, lighting and stand untouched.
 do{
  let (xr,yr)=bounds(956,733,72,84),angle=tau*t/1.6,cg=cos(angle),sg=sin(angle)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
   let nx=(px-993)/31,ny=(py-776)/45,r=hypot(nx,ny),r0=Double(base[i]),g0=Double(base[i+1]),b0=Double(base[i+2])
   let stone=clamp((b0-g0*0.67)/14)*clamp((g0-62)/22)*clamp((g0*1.7-r0)/20)
   let a=stone*clamp((0.99-r)/0.09)
   if a>0{
    let u=nx*cg+ny*sg,v = -nx*sg+ny*cg
    var pores=0.0
    for k in 0..<42{
     let seed=Double(k),px=sin(seed*71.7)*0.95,py=sin(seed*37.3+2)*0.95,size=0.035+0.014*(1+sin(seed*4))
     pores += exp(-(pow((u-px)/size,2)+pow((v-py)/size,2)))*26
    }
    for c in 0..<3{
     let light=(sample(base,px-3,py,c)+sample(base,px+3,py,c)+sample(base,px,py-3,c)+sample(base,px,py+3,c))/4
     p[i+c]=UInt8(Double(p[i+c])*(1-a)+min(255,max(0,light+3-pores))*a)
    }
   }
  }}
 }
 // Furnace glow spills softly; the scene itself never changes exposure.
 do{
  let pulse=0.5+0.25*sin(phase*9)+0.14*sin(phase*23+1)+0.08*sin(phase*41)
  let (xr,yr)=bounds(238,680,118,118)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
   let hot=clamp((Double(base[i])-Double(base[i+1])*1.3-8)/80)
   let m=exp(-pow((px-292)/43,4)-pow((py-741)/35,4))
   for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])+hot*m*(pulse-0.3)*[116.0,54.0,8.0][c])))}
  }}
 }
 // Three drifting chimney plumes; large enough to read at phone size.
 for (j,origin) in [(150.0,368.0),(375.0,80.0),(1015.0,244.0)].enumerated(){
  for k in 0..<10{
   let u=(t/8+Double(k)/10+Double(j)*0.13).truncatingRemainder(dividingBy:1)
   let yy=origin.1-u*(j==1 ? 80:115)
   let xx=origin.0+sin(u*8-phase*2+Double(j)*1.7+Double(k)*0.2)*(5+u*21)
   let rx=5+u*16,ry=10+u*21,a=pow(sin(Double.pi*u),1.3)*0.40
   let (xr,yr)=bounds(xx-rx*2,yy-ry*2,rx*4,ry*4)
   for y in yr{for x in xr{
    let px=Double(x)/scale,py=Double(y)/scale,d=pow((px-xx)/rx,2)+pow((py-yy)/ry,2)
    blend(&p,x,y,[118,108,132],exp(-d*2)*a)
   }}
  }
 }
 // Warm floating cinders over the open forge.
 for k in 0..<23{
  let seed=Double(k),u=(t/4+seed*0.61803398875).truncatingRemainder(dividingBy:1)
  let xx=292+sin(seed*7)*24+sin(seed*3+u*5)*(10+u*20),yy=744-u*(55+36*(1+sin(seed*5))/2)
  let a=pow(sin(Double.pi*u),0.6),radius=k%5==0 ? 2.5:1.6,(xr,yr)=bounds(xx-4,yy-4,8,8)
  for y in yr{for x in xr{
   blend(&p,x,y,[255,136,30],clamp(radius-hypot(Double(x)/scale-xx,Double(y)/scale-yy))*a)
  }}
 }
 // Quench-vat waves expand continuously, with a generous steam plume.
 do{
  let (xr,yr)=bounds(351,987,123,31)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,dx=(px-406)/58,dy=(py-1003)/12,r=hypot(dx,dy),i=(y*w+x)*4
   let a=clamp((1-r)*7),wave=sin(r*21-phase*16)*5*a
   for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(base[i+c])+wave*[0.65,0.86,1.0][c])))}
  }}
  for k in 0..<8{
   let u=(t/4+Double(k)/8).truncatingRemainder(dividingBy:1)
   let yy=998-u*105,xx=403+sin(u*8-phase*3+Double(k)*0.3)*(4+u*20)
   let rx=4+u*14,ry=8+u*16,a=sin(Double.pi*u)*0.22,(sx,sy)=bounds(xx-rx*2,yy-ry*2,rx*4,ry*4)
   for y in sy{for x in sx{
    let d=pow((Double(x)/scale-xx)/rx,2)+pow((Double(y)/scale-yy)/ry,2)
    blend(&p,x,y,[170,163,171],exp(-d*2)*a)
   }}
  }
 }
 // Separate ivy patches sway at different times; structural timber remains fixed.
 for (j,b) in [(174.0,973.0,83.0,121.0),(1056.0,883.0,103.0,125.0),(908.0,499.0,142.0,118.0),(775.0,236.0,75.0,91.0)].enumerated(){
  let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4,r=Double(base[i]),g=Double(base[i+1]),bb=Double(base[i+2])
   let leaf=clamp((g-bb*1.35)/20)*clamp((g*1.7-r)/25)
   let edge=clamp(min(px-b.0,b.0+b.2-px,py-b.1,b.1+b.3-py)/8)
   let dx=3.7*sin(phase*Double(j%2+2)+px*0.055+Double(j)*2)*leaf*edge
   let dy=1.5*cos(phase*3+py*0.065+Double(j))*leaf*edge
   if leaf>0{for c in 0..<3{p[i+c]=UInt8(sample(base,px-dx,py-dy,c))}}
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
 let left=0,top=0,width=w,height=h
 var indices:[UInt8]=[]
 for y in top..<(top+height){for x in left..<(left+width){let k=y*w+x,i=k*4,v=idx(p[i],p[i+1],p[i+2]);indices.append(f>0 && previous[k]==v ? 0:v);previous[k]=v}}
 // Transparency uses index 0 only on delta frames; black is opaque on first.
 gif.append(contentsOf:[0x21,0xF9,4,UInt8(f==0 ? 4:5),4,0,0,0,0x2C]);word(left);word(top);word(width);word(height);byte(0);byte(8)
 let data=lzw(indices)
 for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 if f%50==0{print("Rendered \(f)/\(n)")}
}
byte(0x3B)
let out=folder.appendingPathComponent("rank-5-mechanical-animation-v1.gif")
try gif.write(to:out)
let check=CGImageSourceCreateWithURL(out as CFURL,nil)!
precondition(CGImageSourceGetCount(check)==n)

for (j,f) in [0,17,39,91].enumerated(){
 let dest=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-5-animation-check-\(j).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(dest,image(frame(f)),nil);precondition(CGImageDestinationFinalize(dest))
}
let first=frame(0),last=frame(n-1)
var seam=0.0
for i in stride(from:0,to:first.count,by:4){for c in 0..<3{seam += abs(Double(first[i+c])-Double(last[i+c]))}}
print("Verified: \(w)x\(h), \(n) frames, 25fps, 16 seconds, infinite loop. \(gif.count) bytes; seam MAE \(seam/Double(w*h*3))")
print(out.path)
