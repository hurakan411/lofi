import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/ember-workshop/stages-v1")
let w=512,h=768,fps=20,n=1440
let tau=Double.pi*2
let space=CGColorSpaceCreateDeviceRGB()
let info=CGImageAlphaInfo.premultipliedLast.rawValue
let src=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-5-clocktower-v2-lofi.png") as CFURL,nil)!
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
let ps=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-5-clocktower-cleanplate-v2-lofi.png") as CFURL,nil)!
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

struct Gear{let x:Double,y:Double,rx:Double,ry:Double,period:Double,dir:Double;let hub:Point}
let gears=[Gear(x:450,y:692,rx:108,ry:112,period:8,dir:1,hub:(464,696)),Gear(x:583,y:622,rx:50,ry:57,period:4,dir:-1,hub:(584,623)),Gear(x:611,y:774,rx:72,ry:77,period:6,dir:-1,hub:(612,778))]
let bell:[Point]=[(532,98),(550,98),(557,109),(561,129),(565,140),(577,151),(574,159),(558,164),(546,163),(539,169),(532,163),(513,158),(506,152),(518,140),(525,119),(526,106)]
let hammer:[Point]=[(433,1155),(443,1152),(453,1157),(454,1173),(449,1179),(449,1192),(440,1192),(439,1180),(433,1175)]
let hour:[Point]=[(563,382),(552,373),(506,338),(499,330),(474,321),(491,346),(503,350),(548,387),(557,393)]
let minute:[Point]=[(553,381),(599,344),(605,335),(640,320),(628,345),(617,349),(563,392)]
func pendulumMask(_ x:Double,_ y:Double)->Double{
 let rod=y>=529 && y<=898 ? clamp((4.1-abs(x-543.5))/1.1):0
 let collar=polygon(x,y,[(538,891),(550,891),(550,899),(554,904),(550,910),(553,918),(548,925),(537,925),(532,920),(536,911),(533,904),(537,898)])
 let r=hypot((x-543)/43,(y-967)/46)
 let bob=clamp((1-r)*18)
 let finial=clamp((6-hypot(x-543,y-1015))/1.2)
 return max(rod,collar,bob,finial)
}
func rectMask(_ x:Double,_ y:Double,_ bx:Double,_ by:Double,_ bw:Double,_ bh:Double)->Double{
 clamp(min(x-bx,bx+bw-x,y-by,by+bh-y)/2)
}
var clean=base
// Replace only the moving-part footprints from the prepared background.
for g in gears{
 let eraseRX=max(g.rx,g.x==583 ? 59:0),eraseRY=max(g.ry,g.x==583 ? 67:0)
 let (xr,yr)=bounds(g.x-eraseRX-3,g.y-eraseRY-3,eraseRX*2+6,eraseRY*2+6)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,a=clamp((1.04-hypot((px-g.x)/eraseRX,(py-g.y)/eraseRY))*18),i=(y*w+x)*4
  for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
for b in [(497.0,92.0,87.0,82.0),(430.0,1148.0,28.0,49.0)]{
 let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
 for y in yr{for x in xr{
  let i=(y*w+x)*4,a=rectMask(Double(x)/scale,Double(y)/scale,b.0,b.1,b.2,b.3)
  for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
do{
 let (xr,yr)=bounds(496,523,95,503)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale
  let a=rectMask(px,py,496,523,95,503)
  let i=(y*w+x)*4
  for c in 0..<3{clean[i+c]=UInt8(Double(clean[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
do{
 let (xr,yr)=bounds(445,271,220,234)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,a=clamp((1-hypot((px-558)/108,(py-387)/117))*25),i=(y*w+x)*4
  for c in 0..<3{clean[i+c]=UInt8(Double(base[i+c])*(1-a)+Double(plate[i+c])*a)}
 }}
}
do{
 let (xr,yr)=bounds(232,0,146,143)
 for y in yr{for x in xr{let i=(y*w+x)*4;for c in 0..<3{clean[i+c]=0}}}
}
func gearMask(_ x:Double,_ y:Double,_ g:Gear)->Double{
 let r=hypot((x-g.x)/g.rx,(y-g.y)/g.ry)
 if r>1.035{return 0}
 let red=sample(base,x,y,0),green=sample(base,x,y,1),blue=sample(base,x,y,2)
 let gold=clamp((red-green*1.03-5)/19)*clamp((green-blue*1.10)/19)
 var diff=0.0
 for c in 0..<3{diff += abs(sample(base,x,y,c)-sample(plate,x,y,c))}
 return gold*clamp((diff-16)/38)*clamp((1.035-r)/0.025)
}
// Rigid rotation in the wheel's projected elliptical plane.
func drawGear(_ p:inout [UInt8],_ g:Gear,_ angle:Double){
 let (xr,yr)=bounds(g.x-g.rx-4,g.y-g.ry-4,g.rx*2+8,g.ry*2+8)
 let teeth=g.rx>80 ? 32.0 : (g.rx>60 ? 24.0:16.0)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,nx=(px-g.x)/g.rx,ny=(py-g.y)/g.ry,r=hypot(nx,ny),a=atan2(ny,nx)
  let outer=0.91+0.105*clamp((cos((a-angle)*teeth)+0.12)*4)
  let ring=clamp((r-0.72)/0.018)*clamp((outer-r)/0.018)
  let spokeDistance=abs(sin((a-angle)*3))*r
  let spokes=clamp((0.15-spokeDistance)/0.025)*clamp((0.77-r)/0.025)
  let hub=clamp((0.235-r)/0.02),alpha=max(ring,spokes,hub)
  if alpha>0{
   let bevel=max(exp(-pow((r-0.75)/0.021,2)),exp(-pow((r-0.895)/0.020,2)))
   let edge=clamp((0.15-spokeDistance)/0.15)
   let grain=sin(floor(px/2)*2.1+floor(py/2)*3.3)*4+sin(px*0.23-py*0.4)*4
   let light=0.83+0.17*cos(a+2.2)
   let color=[(134+bevel*28+edge*9+grain)*light,(88+bevel*23+edge*7+grain)*light,(57+bevel*15+edge*5+grain)*light]
   blend(&p,x,y,color,alpha)
  }
 }}
 // Bearing cap is fixed on the axle, separate from the rotating cog body.
 let (hx,hy)=bounds(g.hub.0-18,g.hub.1-18,36,36)
 for y in hy{for x in hx{
  let px=Double(x)/scale,py=Double(y)/scale,a=clamp((17-hypot(px-g.hub.0,py-g.hub.1))/1.6),i=(y*w+x)*4
  for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+Double(base[i+c])*a)}
 }}
}
func drawRigid(_ p:inout [UInt8],_ box:(Double,Double,Double,Double),_ pivot:Point,_ angle:Double,_ mask:(Double,Double)->Double){
 let (xr,yr)=bounds(box.0,box.1,box.2,box.3),ca=cos(angle),sa=sin(angle)
 for y in yr{for x in xr{
  let px=Double(x)/scale,py=Double(y)/scale,dx=px-pivot.0,dy=py-pivot.1
  let sx=pivot.0+ca*dx+sa*dy,sy=pivot.1-sa*dx+ca*dy,a=mask(sx,sy),i=(y*w+x)*4
  if a>0{for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,sx,sy,c)*a)}}
 }}
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
 let t=Double(f)/Double(fps),phase=tau*t/24
 var p=clean
 for g in gears{
  let teeth=g.rx>80 ? 32.0 : (g.rx>60 ? 24.0:16.0)
  var offset=0.0
  if g.x != 450{
   let main=gears[0]
   let mainContact=atan2((g.y-main.y)/main.ry,(g.x-main.x)/main.rx)
   let contact=atan2((main.y-g.y)/g.ry,(main.x-g.x)/g.rx)
   offset=(32*mainContact+teeth*contact-Double.pi)/teeth
  }
  drawGear(&p,g,tau*t/g.period*g.dir+offset)
 }
 // Fixed axles, foreground railings and belt run over the spinning gears.
 do{
  let (xr,yr)=bounds(334,671,333,177)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
   let rail=(py>779 && py<798 && px>353 && px<669) || (py>830 && py<845)
   let belt=distanceToSegment(px,py,(451,708),(390,834))<12
   let axle=distanceToSegment(px,py,(462,696),(557,706))<7
   let hub=hypot((px-464)/20,(py-696)/20)<1 || hypot((px-612)/17,(py-778)/17)<1
   if rail || axle{for c in 0..<3{p[i+c]=plate[i+c]}}
   if belt || hub{for c in 0..<3{p[i+c]=base[i+c]}}
  }}
 }
 // Each window flickers briefly at its own sparse interval; timber stays unchanged.
 for (j,b) in [(350.0,354.0,46.0,82.0),(686.0,373.0,49.0,77.0)].enumerated(){
  let local=(t-(j==0 ? 4.0:14.0)+24).truncatingRemainder(dividingBy:24)
  var dip=0.0
  for beat in [0.14,0.39,0.70]{dip += exp(-pow((local-beat)/0.055,2))}
  let flicker=1-min(0.68,dip*0.62)
  if local<1.0{
   let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
   for y in yr{for x in xr{
    let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4
    let red=Double(base[i]),green=Double(base[i+1]),blue=Double(base[i+2])
    let lit=clamp((red-115)/50)*clamp((green-blue*1.5)/40)*rectMask(px,py,b.0,b.1,b.2,b.3)
    for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-lit+lit*flicker))}
   }}
  }
 }
 // Minute hand completes an accelerated turn; hour hand preserves its original pose.
 drawRigid(&p,(446,274,224,230),(558,385),0,{polygon($0,$1,hour)})
 let minuteAngle=floor(t/1.5+0.000001)*(tau/48)
 drawRigid(&p,(446,274,224,230),(558,385),minuteAngle,{polygon($0,$1,minute)})
 do{
  let (xr,yr)=bounds(545,372,27,27)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,a=clamp((12-hypot(px-558,py-385))/1.2),i=(y*w+x)*4
   for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+Double(base[i+c])*a)}
  }}
 }
 // Big anchored pendulum swing: all brass parts move together, including the rod.
 let swing=0.145*sin(tau*t/4)
 drawRigid(&p,(422,525,244,505),(543.5,529),swing,pendulumMask)
 // Bell rings briefly twice per loop rather than swinging continuously.
 let bellTime=t.truncatingRemainder(dividingBy:8)
 let bellAngle=bellTime<2.5 ? 0.20*sin(tau*bellTime*2)*pow(sin(Double.pi*bellTime/2.5),2):0
 drawRigid(&p,(490,92,105,91),(542,96),bellAngle,{polygon($0,$1,bell)})
 // Original tabletop machine: visible small rotating flywheel and piston strokes.
 do{
  let angle=tau*t/2,ca=cos(angle),sa=sin(angle),(xr,yr)=bounds(515,1157,46,63)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,nx=(px-538)/19,ny=(py-1187)/27,r=hypot(nx,ny)
   if r<0.80 && r>0.21{
    let sx=538+(nx*ca+ny*sa)*19,sy=1187+(-nx*sa+ny*ca)*27,a=clamp((0.80-r)/0.08)*clamp((r-0.21)/0.08),i=(y*w+x)*4
    for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,sx,sy,c)*a)}
   }
  }}
  let offset = -9+22*pow(0.5+0.5*cos(angle),4)
  let (hx,hy)=bounds(429,1135,29,75)
  for y in hy{for x in hx{
   let px=Double(x)/scale,py=Double(y)/scale,sy=py-offset,a=polygon(px,sy,hammer),i=(y*w+x)*4
   if a>0{for c in 0..<3{p[i+c]=UInt8(Double(p[i+c])*(1-a)+sample(base,px,sy,c)*a)}}
  }}
  let dt=t.truncatingRemainder(dividingBy:2)
  if dt<0.65{
   for k in 0..<17{
    let seed=Double(k),xx=444+sin(seed*2.4)*90*dt,yy=1204-(35+60*(1+sin(seed*5.8))/2)*dt+105*dt*dt
    let a=pow(1-dt/0.65,0.7),(sx,sy)=bounds(xx-3,yy-3,6,6)
    for y in sy{for x in sx{blend(&p,x,y,[255,157,38],clamp(2.0-hypot(Double(x)/scale-xx,Double(y)/scale-yy))*a)}}
   }
  }
 }
 // Hearth glow and rising cinders.
 do{
  let pulse=0.5+0.25*sin(phase*9)+0.14*sin(phase*23+1)+0.07*sin(phase*41),(xr,yr)=bounds(335,1020,122,117)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4,hot=clamp((Double(base[i])-Double(base[i+1])*1.3-8)/80)
   let m=exp(-pow((px-391)/43,4)-pow((py-1098)/32,4))
   for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])+hot*m*(pulse-0.35)*[115.0,51.0,8.0][c])))}
  }}
  for k in 0..<22{
   let seed=Double(k),u=(t/4+seed*0.61803398875).truncatingRemainder(dividingBy:1)
   let xx=389+sin(seed*7)*20+sin(seed*3+u*5)*(8+u*20),yy=1102-u*(50+30*(1+sin(seed*5))/2)
   let a=pow(sin(Double.pi*u),0.6),(sx,sy)=bounds(xx-3,yy-3,6,6)
   for y in sy{for x in sx{blend(&p,x,y,[255,134,31],clamp(2.0-hypot(Double(x)/scale-xx,Double(y)/scale-yy))*a)}}
  }
 }
 // Slowly drifting chimney smoke in the empty background.
 for k in 0..<11{
  let u=(t/8+Double(k)/11).truncatingRemainder(dividingBy:1),yy=146-u*135
  let xx=273+sin(u*8-phase*2+Double(k)*0.2)*(5+u*26),rx=5+u*18,ry=10+u*24,a=pow(sin(Double.pi*u),1.3)*0.38
  let (xr,yr)=bounds(xx-rx*2,yy-ry*2,rx*4,ry*4)
  for y in yr{for x in xr{
   let d=pow((Double(x)/scale-xx)/rx,2)+pow((Double(y)/scale-yy)/ry,2)
   blend(&p,x,y,[117,106,130],exp(-d*2)*a)
  }}
 }
 // Subtle separate cloth ripples, pinned along the upper hems.
 for (j,b) in [(496.0,1250.0,44.0,51.0),(695.0,1142.0,37.0,43.0)].enumerated(){
  let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,u=clamp((py-b.1)/b.3),edge=clamp(min(px-b.0,b.0+b.2-px)/5)*sin(Double.pi*u)
   let dx=3.7*u*sin(phase*Double(j+2)+u*4+Double(j))*edge,i=(y*w+x)*4
   for c in 0..<3{p[i+c]=UInt8(sample(base,px-dx,py,c))}
  }}
 }
 // Grindstone moving pores; static shaft and timber stand remain undistorted.
 do{
  let (xr,yr)=bounds(764,1167,60,81),angle=tau*t/1.6,cg=cos(angle),sg=sin(angle)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4,nx=(px-794)/26,ny=(py-1208)/38,r=hypot(nx,ny)
   let red=Double(base[i]),green=Double(base[i+1]),blue=Double(base[i+2])
   let stone=clamp((blue-green*0.67)/13)*clamp((green-62)/22)*clamp((green*1.7-red)/20),a=stone*clamp((0.99-r)/0.10)
   if a>0{
    let u=nx*cg+ny*sg,v = -nx*sg+ny*cg
    var pores=0.0
    for k in 0..<36{
     let seed=Double(k),xx=sin(seed*71.7)*0.95,yy=sin(seed*37.3+2)*0.95,size=0.04+0.014*(1+sin(seed*4))
     pores += exp(-(pow((u-xx)/size,2)+pow((v-yy)/size,2)))*26
    }
    for c in 0..<3{
     let light=(sample(base,px-3,py,c)+sample(base,px+3,py,c)+sample(base,px,py-3,c)+sample(base,px,py+3,c))/4
     p[i+c]=UInt8(Double(p[i+c])*(1-a)+min(255,max(0,light+3-pores))*a)
    }
   }
  }}
 }
 // Ivy at different heights moves independently.
 for (j,b) in [(170.0,479.0,133.0,137.0),(741.0,875.0,83.0,104.0),(174.0,1001.0,46.0,148.0)].enumerated(){
  let (xr,yr)=bounds(b.0,b.1,b.2,b.3)
  for y in yr{for x in xr{
   let px=Double(x)/scale,py=Double(y)/scale,i=(y*w+x)*4,red=Double(base[i]),green=Double(base[i+1]),blue=Double(base[i+2])
   let leaf=clamp((green-blue*1.35)/20)*clamp((green*1.7-red)/25),edge=clamp(min(px-b.0,b.0+b.2-px,py-b.1,b.1+b.3-py)/8)
   let dx=3.5*sin(phase*Double(j%2+2)+px*0.05+Double(j)*2)*leaf*edge,dy=1.3*cos(phase*3+py*0.06+Double(j))*leaf*edge
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
 gif.append(contentsOf:[0x21,0xF9,4,UInt8(f==0 ? 4:5),5,0,0,0,0x2C]);word(left);word(top);word(width);word(height);byte(0);byte(8)
 let data=lzw(indices)
 for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 if f%50==0{print("Rendered \(f)/\(n)")}
}
byte(0x3B)
let out=folder.appendingPathComponent("rank-5-clocktower-animation-v4-lofi.gif")
try gif.write(to:out)
let check=CGImageSourceCreateWithURL(out as CFURL,nil)!
precondition(CGImageSourceGetCount(check)==n)
var decodedDuration=0.0
for f in 0..<n{
 let props=CGImageSourceCopyPropertiesAtIndex(check,f,nil)! as NSDictionary
 let gifProps=props[kCGImagePropertyGIFDictionary] as! NSDictionary
 decodedDuration += (gifProps[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gifProps[kCGImagePropertyGIFDelayTime] as! Double)
}
precondition(abs(decodedDuration-72)<0.001)


for (j,f) in [0,17,39,91].enumerated(){
 let dest=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-5-clock-v4-animation-check-\(j).png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(dest,image(frame(f)),nil);precondition(CGImageDestinationFinalize(dest))
}
let first=frame(0),last=frame(n-1)
var seam=0.0
for i in stride(from:0,to:first.count,by:4){for c in 0..<3{seam += abs(Double(first[i+c])-Double(last[i+c]))}}
print("Verified: \(w)x\(h), \(n) frames, 20fps, 72 seconds, infinite loop. \(gif.count) bytes; seam MAE \(seam/Double(w*h*3))")
print(out.path)
