// Source-matched bell and paper cels; clean plates touch only their old silhouettes.
let approvedShrinePlate=readPlate("rank-5-redrawn-v16.png")
let entranceClean=Raster("rank4-v5/entrances-clean-atlas.png")
struct HangingObject {
 let name:String, image:Raster, x:Int, y:Int, anchor:Point
 let bell:Bool, amplitude:Double,period:Double,phase:Double,panel:Int
}
func hangingObjects()->[HangingObject] {
 let configs:[(String,Int,Int,Int,Int,Point,Bool,Double,Double,Double,Int,[Point])]=[
  ("hall_bell",186,551,30,34,(201,552),true,0.11,6,0.4,0,[(199,552),(204,552),(204,557),(206,559),(208,572),(210,576),(214,578),(213,582),(188,582),(186,579),(191,575),(194,560),(198,557)]),
  ("hall_paper_left",160,537,20,43,(170,538),false,4.8,4,1.0,0,[]),
  ("hall_paper_right",224,548,20,43,(232,549),false,5.8,6,3.4,0,[]),
  ("torii_bell",219,827,38,42,(237,828),true,0.14,4,2.1,1,[(234,828),(240,828),(240,833),(243,835),(246,851),(249,855),(253,858),(254,863),(250,866),(224,866),(220,863),(222,859),(226,855),(229,836),(234,833)]),
  ("torii_paper_left",177,814,23,49,(188,815),false,7.0,6,2.3,1,[]),
  ("torii_paper_right",271,821,23,49,(281,822),false,6.2,4,4.4,1,[])
 ]
 var result=[HangingObject]()
 for (name,x0,y0,ww,hh,anchor,bell,amp,period,phase,panel,poly) in configs {
  var alpha=[Double](repeating:0,count:ww*hh)
  if bell {
   for y in 0..<hh {for x in 0..<ww {
    var coverage=0.0
    for dy in [0.25,0.75] {for dx in [0.25,0.75] {if contains((Double(x0+x)+dx,Double(y0+y)+dy),poly){coverage+=0.25}}}
    alpha[y*ww+x]=coverage
   }}
  } else {
   // Select the connected white paper, not rectangular background around it.
   var remaining=Set<Int>()
   for y in 0..<hh {for x in 0..<ww {
    let i=((y0+y)*w+x0+x)*4,r=Double(approvedShrinePlate[i]),g=Double(approvedShrinePlate[i+1]),b=Double(approvedShrinePlate[i+2])
    if min(r,min(g,b))>125 && max(r,max(g,b))-min(r,min(g,b))<88 {remaining.insert(y*ww+x)}
   }}
   var best=Set<Int>()
   while let first=remaining.first {
    remaining.remove(first);var queue=[first],component=Set([first]),head=0
    while head<queue.count {
     let q=queue[head];head+=1;let x=q%ww,y=q/ww
     for yy in max(0,y-1)...min(hh-1,y+1) {for xx in max(0,x-1)...min(ww-1,x+1) {
      let n=yy*ww+xx;if remaining.remove(n) != nil {queue.append(n);component.insert(n)}
     }}
    }
    if component.count>best.count {best=component}
   }
   precondition(best.count>100,"Missing paper: \(name)")
   for y in 0..<hh {for x in 0..<ww {
    var distance=10.0
    for yy in max(0,y-2)...min(hh-1,y+2) {for xx in max(0,x-2)...min(ww-1,x+2) {
     if best.contains(yy*ww+xx){distance=min(distance,hypot(Double(xx-x),Double(yy-y)))}
    }}
    let i=((y0+y)*w+x0+x)*4,r=Double(approvedShrinePlate[i]),g=Double(approvedShrinePlate[i+1]),b=Double(approvedShrinePlate[i+2])
    let low=min(r,min(g,b)),high=max(r,max(g,b))
    alpha[y*ww+x]=smooth((1.8-distance)/1.15)*smooth((low-75)/55)*smooth((112-high+low)/40)
   }}
  }
  var rgba=[UInt8](repeating:0,count:ww*hh*4)
  for y in 0..<hh {for x in 0..<ww {
   let a=alpha[y*ww+x],i=((y0+y)*w+x0+x)*4,j=(y*ww+x)*4
   for c in 0..<3 {rgba[j+c]=UInt8(Double(approvedShrinePlate[i+c])*a)};rgba[j+3]=UInt8(255*a)
  }}
  result.append(HangingObject(name:name,image:Raster(ww,hh,rgba),x:x0,y:y0,anchor:anchor,bell:bell,amplitude:amp,period:period,phase:phase,panel:panel))
 }
 return result
}
let hanging=hangingObjects()
func cleanShrinePlate()->[UInt8] {
 var p=approvedShrinePlate
 let origins:[Point]=[(122,510),(140,765)]
 for object in hanging {
  let r=object.image,origin=origins[object.panel]
  for y in max(Int(object.anchor.1),object.y-4)...(object.y+r.h+3) {for x in (object.x-4)...(object.x+r.w+3) {
   var erase=0.0
   for yy in max(0,y-object.y-4)...min(r.h-1,y-object.y+4) {for xx in max(0,x-object.x-4)...min(r.w-1,x-object.x+4) {
    let d=hypot(Double(xx+object.x-x),Double(yy+object.y-y))
    erase=max(erase,Double(r.p[(yy*r.w+xx)*4+3])/255*(1-smooth((d-1)/3)))
   }}
   if erase<0.001 {continue}
   let sx=(Double(x)-origin.0)/160*Double(entranceClean.w/2)+Double(object.panel*entranceClean.w/2)
   let sy=(Double(y)-origin.1)/160*Double(entranceClean.h)
   let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(Double(p[i+c])*(1-erase)+entranceClean.at(sx,sy,c)*erase,0,255))}
  }}
 }
 return p
}
let shrinePlate=cleanShrinePlate()

func drawHanging(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 for object in hanging {
  let r=object.image,phase=tau*time/object.period+object.phase
  let angle=object.amplitude*(sin(phase)+0.14*sin(2*phase+0.6)),cs=cos(angle),sn=sin(angle)
  let padding=object.bell ? 9:12
  for y in max(0,object.y-padding)...min(h-1,object.y+r.h+padding) {for x in max(0,object.x-padding)...min(w-1,object.x+r.w+padding) {
   let px=Double(x),py=Double(y)
   var sx=px,sy=py
   if object.bell {
    let dx=px-object.anchor.0,dy=py-object.anchor.1
    sx=object.anchor.0+cs*dx+sn*dy;sy=object.anchor.1-sn*dx+cs*dy
   } else {
    // Continuous material surface: pinned attachment, flexible lower folds.
    for _ in 0..<4 {
     let v=clamp((sy-object.anchor.1)/Double(r.h-2))
     let dx=object.amplitude*pow(v,1.45)*(sin(phase-v*0.50)+0.20*sin(2*phase+v*1.4))
     let dy=0.75*v*v*sin(2*phase+v*1.8)
     sx=px-dx;sy=py-dy
    }
   }
   sx-=Double(object.x);sy-=Double(object.y)
   guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else{continue}
   let a=r.at(sx,sy,3)/255,visibility=transparent ? 1:shrineAlpha[y*w+x]
   if a*visibility<0.01 {continue}
   let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(r.at(sx,sy,c)*visibility+Double(p[i+c])*(1-a*visibility),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*a+Double(p[i+3])*(1-a),0,255))}
  }}
 }
}

func cropAlpha(_ r:Raster,_ rect:CGRect)->Raster {
 let x0=Int(rect.minX),y0=Int(rect.minY),ww=Int(rect.width),hh=Int(rect.height)
 var minX=ww,minY=hh,maxX=0,maxY=0
 for y in 0..<hh {for x in 0..<ww {
  if r.p[((y0+y)*r.w+x0+x)*4+3]>24 {minX=min(minX,x);maxX=max(maxX,x);minY=min(minY,y);maxY=max(maxY,y)}
 }}
 precondition(minX<maxX && minY<maxY)
 let width=maxX-minX+5,height=maxY-minY+5
 var p=[UInt8](repeating:0,count:width*height*4)
 for y in 0..<height {for x in 0..<width {
  let sx=x0+minX+x-2,sy=y0+minY+y-2
  guard sx>=x0,sy>=y0,sx<x0+ww,sy<y0+hh else{continue}
  let i=(sy*r.w+sx)*4,j=(y*width+x)*4
  if r.p[i+3]<18 {continue};for c in 0..<4 {p[j+c]=r.p[i+c]}
 }}
 return Raster(width,height,p)
}
let mapleSheet=Raster("rank4-v5/maple-sprites.png")
let mapleBoughs=[cropAlpha(mapleSheet,CGRect(x:0,y:0,width:610,height:887)),cropAlpha(mapleSheet,CGRect(x:610,y:0,width:850,height:887))]
let airborneCels=[cropAlpha(mapleSheet,CGRect(x:1460,y:0,width:314,height:310)),cropAlpha(mapleSheet,CGRect(x:1460,y:310,width:314,height:250)),cropAlpha(mapleSheet,CGRect(x:1460,y:560,width:314,height:327))]
struct MapleBough {let cel:Int,root:Point,height:Double,amplitude:Double,period:Double,phase:Double}
let mapleBoughInstances=[
 MapleBough(cel:0,root:(-27,590),height:194,amplitude:21,period:6,phase:0.7),
 MapleBough(cel:1,root:(-58,940),height:195,amplitude:28,period:12,phase:2.9),
 MapleBough(cel:0,root:(-38,1085),height:270,amplitude:30,period:12,phase:5.0)
]
func boughRoot(_ r:Raster)->Double {
 var sum=0.0,weight=0.0
 for y in max(0,r.h-12)..<r.h {for x in 0..<r.w {
  let a=Double(r.p[(y*r.w+x)*4+3])/255;sum+=Double(x)*a;weight+=a
 }}
 return sum/max(1,weight)
}
func boughDisplacement(_ b:MapleBough,_ x:Double,_ y:Double,_ width:Double,_ time:Double)->Point {
 let v=clamp(1-y/b.height),u=x/width,phase=tau*time/b.period+b.phase
 let bend=pow(v,1.65)
 return (b.amplitude*bend*(0.78*sin(phase)+0.22*sin(2*phase+u*3.1-v*1.8)),b.amplitude*0.22*bend*sin(phase+u*4.3+v))
}
func drawMaples(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 for b in mapleBoughInstances {
  let r=mapleBoughs[b.cel],scale=b.height/Double(r.h),width=Double(r.w)*scale
  let left=b.root.0-boughRoot(r)*scale,top=b.root.1-b.height,pad=b.amplitude+4
  let x0=Int(floor(left-pad)),y0=Int(floor(top-pad*0.25)),x1=Int(ceil(left+width+pad)),y1=Int(ceil(b.root.1+pad*0.25))
  let cell=6.0,nx=Int(ceil(Double(x1-x0)/cell))+1,ny=Int(ceil(Double(y1-y0)/cell))+1
  var gx=[Double](repeating:0,count:nx*ny),gy=gx
  for j in 0..<ny {for i in 0..<nx {
   let tx=Double(x0)+Double(i)*cell-left,ty=Double(y0)+Double(j)*cell-top
   var sx=tx,sy=ty
   for _ in 0..<4 {let d=boughDisplacement(b,sx,sy,width,time);sx=tx-d.0;sy=ty-d.1}
   gx[j*nx+i]=sx/scale;gy[j*nx+i]=sy/scale
  }}
  for y in max(0,y0)...min(h-1,y1) {for x in max(0,x0)...min(w-1,x1) {
   let fx=Double(x-x0)/cell,fy=Double(y-y0)/cell,ix=min(nx-2,Int(fx)),iy=min(ny-2,Int(fy)),u=fx-Double(ix),v=fy-Double(iy),n=iy*nx+ix
   let sx=gx[n]*(1-u)*(1-v)+gx[n+1]*u*(1-v)+gx[n+nx]*(1-u)*v+gx[n+nx+1]*u*v
   let sy=gy[n]*(1-u)*(1-v)+gy[n+1]*u*(1-v)+gy[n+nx]*(1-u)*v+gy[n+nx+1]*u*v
   guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else{continue}
   let a=r.at(sx,sy,3)/255,visibility=transparent ? 1:shrineAlpha[y*w+x]
   if a*visibility<0.01 {continue}
   let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(r.at(sx,sy,c)*visibility+Double(p[i+c])*(1-a*visibility),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*a+Double(p[i+3])*(1-a),0,255))}
  }}
 }
}
func drawAirborneMaples(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 for n in 0..<16 {
  let r=airborneCels[n%3],u=(time/12+Double(n)*0.61803398875).truncatingRemainder(dividingBy:1)
  let opacity=smooth(u/0.12)*(1-smooth((u-0.82)/0.18))*0.90
  let seed=Double(n),startY=420+Double((n*67)%365)
  let cx = -10+u*(250+Double((n*37)%165))+25*sin(tau*u+seed*1.7)
  let cy=startY+155*u-90*sin(Double.pi*u)+13*sin(tau*u*3+seed)
  let size=7.0+Double((n*7)%8),scale=size/Double(r.w)
  let angle=seed+tau*u*(n%2==0 ? 1.25:-1.1),cs=cos(angle),sn=sin(angle)
  let flip=0.40+0.60*abs(cos(tau*u*3+seed)),pad=Int(ceil(size*1.5))
  let x0=max(0,Int(cx)-pad),x1=min(w-1,Int(cx)+pad),y0=max(0,Int(cy)-pad),y1=min(h-1,Int(cy)+pad)
  if x0>x1 || y0>y1 || opacity<0.005 {continue}
  for y in y0...y1 {for x in x0...x1 {
   let dx=Double(x)-cx,dy=Double(y)-cy
   let sx=(cs*dx+sn*dy)/scale/flip+Double(r.w)*0.5,sy=(-sn*dx+cs*dy)/scale+Double(r.h)*0.5
   guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else{continue}
   let a=r.at(sx,sy,3)/255*opacity
   if a<0.01 {continue};let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(r.at(sx,sy,c)*opacity+Double(p[i+c])*(1-a),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*a+Double(p[i+3])*(1-a),0,255))}
  }}
 }
}
