import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shrine")
let output=folder.appendingPathComponent("rank-2-office-v8.gif")
let w=600,h=1300,fps=20,frameCount=2400
let duration=12.0 // The inherited water keeps its approved twelve-second period.
let loopDuration=120.0,tau=2*Double.pi
let colorSpace=CGColorSpaceCreateDeviceRGB()
let bitmapInfo=CGImageAlphaInfo.premultipliedLast.rawValue
func clamp(_ v:Double,_ lo:Double=0,_ hi:Double=1)->Double { min(hi,max(lo,v)) }
func smooth(_ v:Double)->Double { let x=clamp(v);return x*x*(3-2*x) }
func mix(_ a:Double,_ b:Double,_ t:Double)->Double { a+(b-a)*smooth(t) }
typealias Point=(Double,Double)
struct Raster {
 let w:Int,h:Int,p:[UInt8]
 init(_ name:String) {
  let s=CGImageSourceCreateWithURL(folder.appendingPathComponent(name) as CFURL,nil)!
  let im=CGImageSourceCreateImageAtIndex(s,0,nil)!
  let ww=im.width,hh=im.height
  w=ww;h=hh
  var data=[UInt8](repeating:0,count:ww*hh*4)
  data.withUnsafeMutableBytes { b in
   let c=CGContext(data:b.baseAddress,width:ww,height:hh,bitsPerComponent:8,bytesPerRow:ww*4,space:colorSpace,bitmapInfo:bitmapInfo)!
   c.draw(im,in:CGRect(x:0,y:0,width:ww,height:hh))
  };p=data
 }
 init(_ ww:Int,_ hh:Int,_ data:[UInt8]) { w=ww;h=hh;p=data }
 func at(_ x:Double,_ y:Double,_ c:Int)->Double {
  let xx=clamp(x,0,Double(w-2)),yy=clamp(y,0,Double(h-2)),ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
  return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
 }
}
func readPlate(_ name:String)->[UInt8] {
 let r=Raster(name);var p=[UInt8](repeating:255,count:w*h*4)
 for y in 0..<h { for x in 0..<w { for c in 0..<3 {p[(y*w+x)*4+c]=UInt8(clamp(r.at(Double(x)*Double(r.w)/Double(w),Double(y)*Double(r.h)/Double(h),c),0,255))} }}
 return p
}
let base=readPlate("rank-1-base.png")
let closed=Raster("v4/office-clean.png"),opened=Raster("v4/office-open.png"),noTools=Raster("v4/office-no-tools.png")
let origin:Point=(555*600.0/852,1210*1300.0/1846)
let officeSize:Point=(297*600.0/852,450*1300.0/1846)
let officeLeft=380,officeTop=842,officeBottom=1178
func officeSample(_ r:Raster,_ x:Double,_ y:Double,_ c:Int)->Double {
 r.at((x-origin.0)/officeSize.0*Double(r.w),(y-origin.1)/officeSize.1*Double(r.h),c)
}
func worldPoint(_ x:Double,_ y:Double)->Point { (origin.0+x/1019*officeSize.0,origin.1+y/1544*officeSize.1) }
func contains(_ p:Point,_ poly:[Point])->Bool {
 var inside=false,j=poly.count-1
 for i in poly.indices {let a=poly[i],b=poly[j];if ((a.1>p.1) != (b.1>p.1)) && p.0<(b.0-a.0)*(p.1-a.1)/(b.1-a.1)+a.0 {inside.toggle()};j=i};return inside
}
let railPolys:[[Point]]=[
 [(10,903),(1019,973),(1019,1045),(8,972)],
 [(168,976),(222,981),(222,1116),(167,1108)],
 [(490,998),(550,1003),(550,1160),(490,1150)],
 [(786,1020),(833,1023),(833,1205),(786,1194)],
 [(1001,1038),(1019,1040),(1019,1218),(1001,1216)]
].map{$0.map{worldPoint($0.0,$0.1)}}
var railMask=[Bool](repeating:false,count:w*h)
for y in 1035..<1110 {for x in 391..<w {railMask[y*w+x]=railPolys.contains{contains((Double(x)+0.5,Double(y)+0.5),$0)}}}


struct Cel {
 let image:Raster
 let footX:Double,footY:Double,height:Double
 let hair:[Double]
 let hairTop:Double,hairHeight:Double
}
func hairField(_ r:Raster,_ footX:Double,_ refHeight:Double)->([Double],Double,Double) {
 var mask=[Double](repeating:0,count:r.w*r.h),minY=r.h,maxY=0
 for y in 0..<r.h {for x in 0..<r.w {
  let i=(y*r.w+x)*4,a=Double(r.p[i+3])/255
  if a<0.5 || Double(x)<footX+refHeight*0.15 || Double(y)>Double(r.h)*0.78 {continue}
  let rr=Double(r.p[i])/a,gg=Double(r.p[i+1])/a,bb=Double(r.p[i+2])/a
  if max(rr,max(gg,bb))<145 && rr<gg*1.6 && bb>gg*0.55 {
   mask[y*r.w+x]=1;minY=min(minY,y);maxY=max(maxY,y)
  }
 }}
 // Expand before blurring so the opaque hair outline moves as a whole, rather
 // than leaving its old edge behind. The field remains continuous in empty alpha.
 var tmp=mask,out=mask
 for y in 0..<r.h {for x in 0..<r.w {
  var v=0.0;for xx in max(0,x-7)...min(r.w-1,x+7) {v=max(v,mask[y*r.w+xx])};tmp[y*r.w+x]=v
 }}
 for y in 0..<r.h {for x in 0..<r.w {
  var v=0.0;for yy in max(0,y-7)...min(r.h-1,y+7) {v=max(v,tmp[yy*r.w+x])};out[y*r.w+x]=v
 }}
 for _ in 0..<2 {
  for y in 0..<r.h {for x in 0..<r.w {
   var v=0.0,n=0.0;for xx in max(0,x-5)...min(r.w-1,x+5) {v+=out[y*r.w+xx];n+=1};tmp[y*r.w+x]=v/n
  }}
  for y in 0..<r.h {for x in 0..<r.w {
   var v=0.0,n=0.0;for yy in max(0,y-5)...min(r.h-1,y+5) {v+=tmp[yy*r.w+x];n+=1};out[y*r.w+x]=v/n
  }}
 }
 return (out,Double(minY),Double(max(1,maxY-minY)))
}
func cels(_ name:String,_ cols:Int,_ rows:Int)->[Cel] {
 let r=Raster(name),cw=r.w/cols,ch=r.h/rows
 var result:[Cel]=[],refHeight=0.0
 for n in 0..<(cols*rows) {
  let ox=n%cols*cw,oy=n/cols*ch
  var minX=cw,minY=ch,maxX=0,maxY=0
  for y in 0..<ch {for x in 0..<cw {if r.p[((oy+y)*r.w+ox+x)*4+3]>16 {minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)}}}
  let ww=maxX-minX+5,hh=maxY-minY+5
  var p=[UInt8](repeating:0,count:ww*hh*4),footSum=0.0,footWeight=0.0
  for y in 0..<hh {for x in 0..<ww {
   let sx=ox+minX+x-2,sy=oy+minY+y-2
   if sx<ox || sx>=ox+cw || sy<oy || sy>=oy+ch {continue}
   let i=(sy*r.w+sx)*4,j=(y*ww+x)*4
   if r.p[i+3]<8 {continue}
   for c in 0..<4 {p[j+c]=r.p[i+c]}
   if y>hh-13 {let a=Double(p[j+3])/255;footSum+=Double(x)*a;footWeight+=a}
  }}
  if n==0 {refHeight=Double(hh-4)}
  let footX=footSum/max(1,footWeight),raster=Raster(ww,hh,p)
  let (hair,top,height)=hairField(raster,footX,refHeight)
  result.append(Cel(image:raster,footX:footX,footY:Double(hh-3),height:refHeight,hair:hair,hairTop:top,hairHeight:height))
 }
 return result
}
let writingPose=cels("v4/clerk-poses.png",4,3)[0]
let pausePoses=cels("v7/pause-sheet.png",4,2)
let napPoses=cels("v7/nap-sheet.png",3,2)
struct State {
 let cel:Cel
 let action:String
 let brushHeld:Bool
 let writing:Bool
 let asleep:Bool
}
func pauseState(_ n:Int,_ action:String)->State {State(cel:pausePoses[n],action:action,brushHeld:[0,1,7].contains(n),writing:false,asleep:false)}
func napState(_ n:Int,_ action:String,_ asleep:Bool=false)->State {State(cel:napPoses[n],action:action,brushHeld:false,writing:false,asleep:asleep)}
func thoughtState(_ e:Double)->State {
 switch e {
 case 0..<0.4:return pauseState(0,"lower_brush")
 case 0.4..<0.85:return pauseState(1,"put_brush_on_rest")
 case 0.85..<1.2:return pauseState(2,"release_brush")
 case 1.2..<1.6:return pauseState(3,"fold_arms")
 case 1.6..<3.1:return pauseState(Int(e*2)%2==0 ? 4:5,"think_arms_crossed")
 case 3.1..<3.5:return pauseState(3,"unfold_arms")
 case 3.5..<3.9:return pauseState(6,"reach_for_brush")
 case 3.9..<4.35:return pauseState(7,"pick_up_brush")
 default:return pauseState(0,"return_to_writing")
 }
}
func state(_ time:Double)->State {
 let tick=Int((time*Double(fps)).rounded()) % frameCount
 let q=Double(tick % (40*fps))/Double(fps)
 let thought=Double((tick-4*fps+15*fps) % (15*fps))/Double(fps)
 let thoughtActive=thought<4.8
 // Sleeping has priority over a timer cue. Already crossed arms can become
 // the pillow without repeating the put-down gesture immediately beforehand.
 if q>=27 && q<37 {return napState(2,"asleep_face_down",true)}
 if q>=26.2 && q<27 {return napState(q<26.55 ? 0:1,"lean_down_to_desk")}
 if q>=37 && q<37.55 {return napState(4,"wake_and_raise_head")}
 if q>=37.55 && q<38 {return napState(5,"sit_upright_after_nap")}
 if q>=38 && q<38.4 {return pauseState(6,"reach_for_brush_after_nap")}
 if q>=38.4 && q<38.9 {return pauseState(7,"pick_up_brush_after_nap")}
 if q>=38.9 && q<39.4 {return pauseState(0,"resume_after_nap")}
 if q>=25.2 && q<26.2 {
  if thoughtActive {return thoughtState(thought)}
  return pauseState(q<25.7 ? 1:2,q<25.7 ? "put_brush_down_before_nap":"release_brush_before_nap")
 }
 if thoughtActive {return thoughtState(thought)}
 return State(cel:writingPose,action:"write_diagonally_down_right",brushHeld:true,writing:true,asleep:false)
}
struct PenMotion {let dx:Double,dy:Double,writing:Bool,progress:Double}
func penMotion(_ t:Double)->PenMotion {
 let q=t.truncatingRemainder(dividingBy:3)
 if q<2.4 {
  let u=q/2.4,p=u+0.007*sin(tau*7*u)
  return PenMotion(dx:-3+6*p+0.12*sin(tau*7*u)*sin(Double.pi*u),dy:-5+7*p,writing:true,progress:p)
 }
 let u=(q-2.4)/0.6,p=1-smooth(u)
 return PenMotion(dx:-3+6*p+0.5*sin(Double.pi*u),dy:-5+7*p-1.2*sin(Double.pi*u),writing:false,progress:p)
}
func maskSample(_ mask:[Double],_ r:Raster,_ x:Double,_ y:Double)->Double {
 guard x>=0,y>=0,x<Double(r.w-1),y<Double(r.h-1) else{return 0}
 let ix=Int(x),iy=Int(y),fx=x-Double(ix),fy=y-Double(iy),i=iy*r.w+ix
 return mask[i]*(1-fx)*(1-fy)+mask[i+1]*fx*(1-fy)+mask[i+r.w]*(1-fx)*fy+mask[i+r.w+1]*fx*fy
}
func strokeWeight(_ x:Double,_ y:Double)->Double {
 // Coordinates of the original intact writing cel; no arm masks or erased
 // pixels. A smooth connected field moves fingers/brush together, blending
 // through the sleeve into a stationary shoulder and torso.
 let sx=x+100,sy=y+40
 let upper=132+0.9*(sx-145)
 // Follow the writing forearm only. The old broad vertical falloff included
 // the supporting hand, hakama and knee below it.
 let lower=192+0.36*(sx-145)+32*(1-smooth((sx-125)/15))
 return smooth((225-sx)/80)*smooth((sy-upper+18)/18)*smooth((lower-sy)/12)*smooth((212-sy)/12)
}
func deformation(_ cel:Cel,_ x:Double,_ y:Double,_ t:Double,_ s:State)->Point {
 let scale=134/cel.height
 var dx=0.0,dy=0.0
 if s.writing {
  let weight=strokeWeight(x,y),pen=penMotion(t)
  dx=pen.dx/scale*weight;dy=pen.dy/scale*weight
 }
 let hair=maskSample(cel.hair,cel.image,x,y)
 if hair>0.001 {
  let depth=smooth((y-cel.hairTop)/cel.hairHeight)
  let wind=3.8*sin(tau*t/4+x*0.045)+2.0*sin(tau*t/6+y*0.06)+0.9*sin(tau*t/2.4+x*0.12)
  dx+=hair*depth*depth*wind
  dy+=hair*depth*depth*0.8*sin(tau*t/3+y*0.04)
 }
 if s.asleep {
  let upper=smooth((cel.footY-y)/cel.height*2)
  dy+=0.65*sin(tau*t/3)*upper
 }
 // Pin the lower body even when a dark hakama pixel enters the hair mask.
 // The zero boundary lands on the deformation mesh (native y=172).
 if s.writing {
  let upperBody=smooth((172-y)/12)
  dx *= upperBody;dy *= upperBody
 }
 return (dx,dy)
}
func draw(_ s:State,_ pixels:inout[UInt8],_ time:Double,_ alphaOnly:Bool=false) {
 let cel=s.cel,r=cel.image,scale=134/cel.height
 let left=508-cel.footX*scale,top=1080-cel.footY*scale
 let step=4,gw=(r.w+step-1)/step+1,gh=(r.h+step-1)/step+1
 var gx=[Double](repeating:0,count:gw*gh),gy=gx
 for yy in 0..<gh {for xx in 0..<gw {
  let d=deformation(cel,Double(xx*step),Double(yy*step),time,s)
  gx[yy*gw+xx]=d.0;gy[yy*gw+xx]=d.1
 }}
 func field(_ x:Double,_ y:Double)->Point {
  let px=clamp(x/Double(step),0,Double(gw-2)),py=clamp(y/Double(step),0,Double(gh-2))
  let xx=Int(px),yy=Int(py),fx=px-Double(xx),fy=py-Double(yy),i=yy*gw+xx
  let a=(1-fx)*(1-fy),b=fx*(1-fy),c=(1-fx)*fy,d=fx*fy
  return (gx[i]*a+gx[i+1]*b+gx[i+gw]*c+gx[i+gw+1]*d,gy[i]*a+gy[i+1]*b+gy[i+gw]*c+gy[i+gw+1]*d)
 }
 let x0=max(0,Int(floor(left))-8),x1=min(w-1,Int(ceil(left+Double(r.w)*scale))+8)
 let y0=max(0,Int(floor(top))-8),y1=min(h-1,Int(ceil(top+Double(r.h)*scale))+8)
 for y in y0...y1 {for x in x0...x1 {
  let tx=(Double(x)-left)/scale,ty=(Double(y)-top)/scale
  var sx=tx,sy=ty
  // Invert the same continuous full-figure surface; no isolated limb layers.
  for _ in 0..<7 {let d=field(sx,sy);sx=tx-d.0;sy=ty-d.1}
  guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else {continue}
  let a=r.at(sx,sy,3)/255
  if a<0.015 {continue}
  let i=(y*w+x)*4
  if alphaOnly {for c in 0..<4 {pixels[i+c]=UInt8(clamp(r.at(sx,sy,c),0,255))}}
  else {for c in 0..<3 {pixels[i+c]=UInt8(clamp(r.at(sx,sy,c)+Double(pixels[i+c])*(1-a),0,255))}}
 }}
}
// Solid textured cloth quads. Their complete interior is drawn; gaps cannot
// appear within a panel when its edge moves away from the original silhouette.
struct Cloth {let tl:Point,tr:Point,bl:Point,br:Point,amp:Double,cycles:Double,offset:Double}
let cloths=[
 Cloth(tl:worldPoint(697,142),tr:worldPoint(812,125),bl:worldPoint(698,348),br:worldPoint(817,337),amp:2.6,cycles:2,offset:0.2),
 Cloth(tl:worldPoint(832,126),tr:worldPoint(950,106),bl:worldPoint(835,339),br:worldPoint(955,330),amp:2.3,cycles:3,offset:1.1),
 Cloth(tl:worldPoint(972,107),tr:worldPoint(1019,101),bl:worldPoint(978,332),br:worldPoint(1019,326),amp:2.7,cycles:2,offset:2.3)
]
func drawCloth(_ pixels:inout[UInt8],_ time:Double) {
 let phase=tau*time/12
 for p in cloths {
  let top=min(p.tl.1,p.tr.1),bottom=max(p.bl.1,p.br.1)
  for y in Int(top-1)...Int(bottom+1) {for x in max(0,Int(min(p.tl.0,p.bl.0)-5))..<min(w,Int(max(p.tr.0,p.br.0)+6)) {
   let py=Double(y)+0.5,px=Double(x)+0.5
   var v=clamp((py-(p.tl.1+p.tr.1)/2)/((p.bl.1+p.br.1-p.tl.1-p.tr.1)/2))
   var u=0.0,sx=0.0,sy=0.0
   for _ in 0..<3 {
    let bend=p.amp*v*v*(sin(phase*p.cycles+p.offset-v*0.5)+0.12*sin(phase*5+p.offset))
    let l=p.tl.0+(p.bl.0-p.tl.0)*v,r=p.tr.0+(p.br.0-p.tr.0)*v
    u=(px-bend-l)/(r-l)
    let yt=p.tl.1+(p.tr.1-p.tl.1)*u,yb=p.bl.1+(p.br.1-p.bl.1)*u
    v=(py-yt)/(yb-yt)
   }
   guard u>=0,u<=1,v>=0,v<=1 else{continue}
   sx=(p.tl.0*(1-u)+p.tr.0*u)*(1-v)+(p.bl.0*(1-u)+p.br.0*u)*v
   sy=(p.tl.1*(1-u)+p.tr.1*u)*(1-v)+(p.bl.1*(1-u)+p.br.1*u)*v
   let edge=clamp(min(u,1-u)*22)*clamp(min(v,1-v)*44)
   let shade=1+0.018*v*sin(phase*p.cycles+p.offset)
   let i=(y*w+x)*4
   for c in 0..<3 {pixels[i+c]=UInt8(clamp(Double(pixels[i+c])*(1-edge)+officeSample(closed,sx,sy,c)*shade*edge,0,255))}
  }}
 }
}
func addOffice(_ water:[UInt8],_ time:Double)->[UInt8] {
 var pixels=water
 let scene=state(time)
 for y in officeTop...officeBottom {for x in officeLeft..<w {
  let px=Double(x),py=Double(y),i=(y*w+x)*4
  guard px>=origin.0,py>=origin.1,py<origin.1+officeSize.1 else{continue}
  let edge=smooth((px-origin.0)/4)*smooth((py-origin.1)/5)*smooth((origin.1+officeSize.1-py)/5)
  for c in 0..<3 {pixels[i+c]=UInt8(clamp(Double(water[i+c])*(1-edge)+officeSample(closed,px,py,c)*edge,0,255))}
  // The same clean background is always behind the noren, never a partial
  // erased mask of the original cloth. Moving panels have no static duplicates.
  if x>=531 && y>=869 && y<=926 {for c in 0..<3 {pixels[i+c]=UInt8(clamp(officeSample(opened,px,py,c),0,255))}}
  // Remove only held props from their actual bare-wood resting places.
  if scene.brushHeld && x>=445 && x<=479 && y>=1019 && y<=1025 {
   for c in 0..<3 {pixels[i+c]=UInt8(clamp(officeSample(noTools,px,py,c),0,255))}
  }
  // The closed shoji panel slides into the right-hand pocket. Jambs stay fixed.
  let dl=worldPoint(840,340).0,dr=worldPoint(987,340).0,dt=worldPoint(840,340).1,db=worldPoint(840,967).1
  if px>=dl && px<dr && py>=dt && py<db {
   let offset=0.0 // Door stays closed throughout.
   for c in 0..<3 {
    let value=px>=dl+offset ? officeSample(closed,px-offset,py,c):officeSample(opened,px,py,c)
    pixels[i+c]=UInt8(clamp(value,0,255))
   }
  }
  // The light breathes gently within its own glass.
  let lamp=clamp(1-pow((px-484)/13,2)-pow((py-911)/19,2))
  let gain=1+lamp*(0.035*sin(tau*time/4)+0.012*sin(tau*time/1.714285714))
  for c in 0..<3 {pixels[i+c]=UInt8(clamp(Double(pixels[i+c])*gain,0,255))}
 }}
 draw(scene,&pixels,time)
 // Front rail and posts correctly hide the lower body; they never deform.
 for y in 1035..<1110 {for x in 391..<w {if railMask[y*w+x] {let i=(y*w+x)*4;for c in 0..<3 {pixels[i+c]=UInt8(clamp(officeSample(closed,Double(x),Double(y),c),0,255))}}}}
 drawCloth(&pixels,time)
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
    let waterTick=Int((time*Double(fps)).rounded()) % (12*fps)
    let phase = tau*(Double(waterTick)/Double(fps))/duration
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


func cgImage(_ pixels:[UInt8])->CGImage {
 let data=Data(pixels)
 return CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:colorSpace,bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
func savePNG(_ image:CGImage,_ name:String) {
 let d=CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(d,image,nil);precondition(CGImageDestinationFinalize(d))
}
let previewTimes:[Double]=[0,1.0,2.2,4.6,5.0,6.0,7.7,25.5,26.8,28.0,37.2,38.6]
func saveConnectivityFixtures() {
for (j,t) in [0.0,0.6,1.2,1.8,2.35,2.7].enumerated() {
 var p=[UInt8](repeating:0,count:w*h*4)
 let s=State(cel:writingPose,action:"connectivity_fixture",brushHeld:true,writing:true,asleep:false)
 draw(s,&p,t,true)
 savePNG(cgImage(p),"v8/connected-writing-\(j).png")
}
}
func savePreviews() {
 saveConnectivityFixtures()
 let sw=1680,sh=1920
 let ctx=CGContext(data:nil,width:sw,height:sh,bitsPerComponent:8,bytesPerRow:sw*4,space:colorSpace,bitmapInfo:bitmapInfo)!
 ctx.interpolationQuality = .none
 for (j,t) in previewTimes.enumerated() {
  let im=cgImage(frame(t))
  let crop=im.cropping(to:CGRect(x:390,y:850,width:210,height:320))!
  ctx.draw(crop,in:CGRect(x:(j%4)*420,y:(2-j/4)*640,width:420,height:640))
 }
 savePNG(ctx.makeImage()!,"rank-2-motion-check-v8.png")
 savePNG(cgImage(frame(0)),"rank-2-first-frame-v8.png")
 let hands=CGContext(data:nil,width:1760,height:704,bitsPerComponent:8,bytesPerRow:1760*4,space:colorSpace,bitmapInfo:bitmapInfo)!
 hands.interpolationQuality = .none
 for (j,t) in [0.0,0.4,0.8,1.2,1.6,2.0,2.35,2.75].enumerated() {
  let crop=cgImage(frame(t)).cropping(to:CGRect(x:486,y:983,width:55,height:44))!
  hands.draw(crop,in:CGRect(x:(j%4)*440,y:(1-j/4)*352,width:440,height:352))
 }
 savePNG(hands.makeImage()!,"rank-2-writing-check-v8.png")

}
if CommandLine.arguments.contains("--preview") {savePreviews();print("Preview complete");exit(0)}
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
    if index%200==0 { print("rendering \(index)/\(frameCount)") }
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


savePreviews()



var trajectory:[[String:Any]]=[]
for i in 0..<frameCount {
 let t=Double(i)/Double(fps),s=state(t),p=penMotion(t)
 trajectory.append(["time":t,"action":s.action,"brushHeld":s.brushHeld,"asleep":s.asleep,"writing":s.writing,"penStrokeDownRight":p.writing,"penDx":p.dx,"penDy":p.dy])
}
try JSONSerialization.data(withJSONObject:trajectory,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("rank-2-timeline-v8.json"))
// Save actual rendered full-figure alpha fixtures at writing extrema so limb
// connectivity can be checked on the delivered raster, rather than just a timer.
saveConnectivityFixtures()
let report="""
Rank 2 v8: \(w)x\(h), \(frameCount) frames at \(fps) fps, \(loopDuration)s infinite GIF.
GIF bytes: \(gif.count). Loop boundary mean delta \(seamDelta), max adjacent \(maximumFrameDelta).
Writing: upper-left to lower-right, 6px right and 7px down per stroke; brush lifts on return. Only the connected writing hand and sleeve deform; knees, legs and feet are pinned; no erased arm, detached forearm sprite or cut cuff.
Hair: independent spatial wind phases, tied roots steady, hair tips move; transparent foreground only, fixed backdrop.
Thought cue every 15s (4+15k): puts brush on desk, releases it, crosses arms in front of chest thoughtfully, uncrosses and picks brush up. Sleep overrides conflicting thought cues.
Nap every 40s: preparation at 25.2+40k, head lowers 26.2+40k, asleep face down on folded sleeves on desk 27+40k through 37+40k (ten seconds), wakes and retrieves brush by 39.4+40k. No standing, entry, exit or stamping.
Noren, lantern, water and leaf inherited. Door, desk, paper and foreground rail remain fixed.
Pose artwork generated with built-in imagegen, source and prompts under v7/. Writing uses intact v4 cel with continuous connected deformation. Nap and thought poses are whole connected drawn cels.
"""
try report.write(to:folder.appendingPathComponent("rank-2-animation-report-v8.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
