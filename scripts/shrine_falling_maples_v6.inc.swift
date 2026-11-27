// Every loose leaf has a real landing point. Only leaves already resting
// on a roof/stone surface may fade out; flying leaves stay fully visible.
let fallingMapleCount=40
struct MapleLanding {let point:Point,surface:String}
let roofLandings:[Point]=[(361,840),(390,831),(419,822),(447,814)]
let stairLandings:[Point]=[(228,1013),(273,1029),(326,1046),(299,1073),(258,1088),(335,1096),(274,1112),(353,1120)]
let pavingLandings:[Point]=[(252,1155),(355,1154),(383,1130),(250,1202),(290,1210),(312,1251),(452,1214),(485,1242),(530,1217),(552,1258),(458,1273),(372,1270),(320,1287),(410,1260),(512,1285)]
func mapleLanding(_ n:Int)->MapleLanding {
 if n%5==0 {return MapleLanding(point:roofLandings[(n/5)%roofLandings.count],surface:"office_roof")}
 if n%5==1 {return MapleLanding(point:stairLandings[(n/5)%stairLandings.count],surface:"stone_steps")}
 return MapleLanding(point:pavingLandings[(n*7)%pavingLandings.count],surface:"stone_paving")
}
struct FallingMaple {
 let index:Int,age:Double,flight:Double,landed:Bool,fading:Bool
 let x:Double,y:Double,size:Double,angle:Double,flip:Double,flatten:Double,opacity:Double
 let target:MapleLanding
}
func fallingMaple(_ n:Int,_ time:Double)->FallingMaple {
 let age=(time+Double(n)*12/Double(fallingMapleCount)).truncatingRemainder(dividingBy:12)
 let flight=7.2+Double((n*11)%12)*0.10,target=mapleLanding(n),seed=Double(n)
 let high=target.surface=="office_roof" || n%3==0
 let startX=20+Double((n*19)%100)
 let startY=high ? 430+Double((n*13)%110):(n%3==1 ? 765+Double((n*7)%105):870+Double((n*11)%95))
 let f=clamp(age/flight),travel=smooth(f),landed=age>=flight,rest=max(0,age-flight)
 var y=startY+(target.point.1-startY)*travel
 var x=startX+(target.point.0-startX)*travel
 // Leaves heading to the right foreground stay left of the girl's office
 // until they have descended below the veranda, then fan out over the paving.
 if target.surface=="stone_paving" && target.point.0>410 {
  let early=startX+(360-startX)*travel
  let fan=smooth((y-1110)/(target.point.1-1110))
  x=early+(target.point.0-early)*fan
 }
 let flutter=sin(Double.pi*f)
 x+=flutter*(14*sin(tau*2*f+seed)+10*sin(tau*f+seed*0.7))
 y+=flutter*(-22*sin(Double.pi*f)+7*sin(tau*4*f+seed))
 if landed {
  let bounce=clamp(rest/0.42)
  x=target.point.0+1.1*sin(tau*bounce)*(1-bounce)
  y=target.point.1-1.6*sin(Double.pi*bounce)
 }
 let touchdown=smooth((f-0.92)/0.08),rotation=n%2==0 ? 1.25:-1.1
 let angle=seed+tau*f*rotation+0.18*sin(tau*f*4+seed)*flutter
 let flip=(0.42+0.58*abs(cos(tau*f*3+seed)))*(1-touchdown)+touchdown
 let flatten=1-touchdown*0.62
 let fading=rest>1.5
 let fade=landed ? 1-smooth((rest-1.5)/1.3):1.0
 // Birth happens within the red canopy, not as a disappearing mid-air leaf.
 let opacity=0.95*smooth(age/0.18)*fade
 return FallingMaple(index:n,age:age,flight:flight,landed:landed,fading:fading,x:x,y:y,size:8+Double((n*7)%8),angle:angle,flip:flip,flatten:flatten,opacity:opacity,target:target)
}
func drawAirborneMaples(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false,_ only:Int?=nil) {
 let indices=only.map{[$0]} ?? Array(0..<fallingMapleCount)
 for n in indices {
  let s=fallingMaple(n,time),r=airborneCels[n%3],scale=s.size/Double(r.w),cs=cos(s.angle),sn=sin(s.angle),pad=Int(ceil(s.size*1.5))
  let x0=max(0,Int(s.x)-pad),x1=min(w-1,Int(s.x)+pad),y0=max(0,Int(s.y)-pad),y1=min(h-1,Int(s.y)+pad)
  if x0>x1 || y0>y1 || s.opacity<0.005 {continue}
  if s.landed && !transparent {
   // A small contact shadow keeps the resting leaf attached to its surface.
   for y in max(0,Int(s.target.point.1)-2)...min(h-1,Int(s.target.point.1)+2) {
    for x in max(0,Int(s.target.point.0)-9)...min(w-1,Int(s.target.point.0)+9) {
     let e=pow((Double(x)-s.target.point.0)/(s.size*0.49),2)+pow((Double(y)-s.target.point.1)/1.3,2)
     let alpha=clamp(1-e)*0.13*s.opacity,i=(y*w+x)*4
     for c in 0..<3 {p[i+c]=UInt8(Double(p[i+c])*(1-alpha))}
    }
   }
  }
  for y in y0...y1 {for x in x0...x1 {
   let dx=Double(x)-s.x,dy=(Double(y)-s.y)/s.flatten
   let sx=(cs*dx+sn*dy)/scale/s.flip+Double(r.w)*0.5,sy=(-sn*dx+cs*dy)/scale+Double(r.h)*0.5
   guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else{continue}
   let a=r.at(sx,sy,3)/255*s.opacity
   if a<0.01 {continue};let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(r.at(sx,sy,c)*s.opacity+Double(p[i+c])*(1-a),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*a+Double(p[i+3])*(1-a),0,255))}
  }}
 }
}
