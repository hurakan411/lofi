// Whole generated walk cels, aligned by torso/paw root. No detached limb sprites.
struct WalkCel {let image:Raster,anchor:Point,referenceHeight:Double}
func walkCels(_ name:String,_ columns:Int,_ rows:Int)->[WalkCel] {
 let sheet=Raster(name);var out=[WalkCel]()
 for row in 0..<rows {for column in 0..<columns {
  let x0=column*sheet.w/columns,x1=(column+1)*sheet.w/columns,y0=row*sheet.h/rows,y1=(row+1)*sheet.h/rows
  let ww=x1-x0,hh=y1-y0
  var p=[UInt8](repeating:0,count:ww*hh*4),minY=hh,maxY=0,minX=ww,maxX=0
  for y in 0..<hh {for x in 0..<ww {
   let s=((y0+y)*sheet.w+x0+x)*4,i=(y*ww+x)*4,old=Double(sheet.p[s+3])/255
   let a=smooth((old-0.10)/0.60)
   if a>0.4 {minY=min(minY,y);maxY=max(maxY,y);minX=min(minX,x);maxX=max(maxX,x)}
   if old>0 {for c in 0..<3 {p[i+c]=UInt8(clamp(Double(sheet.p[s+c])*a/old,0,255))}};p[i+3]=UInt8(255*a)
  }}
  // Register people at the stable torso, rather than the swinging foot extremity.
  var sx=0.0,weight=0.0
  let a0=minY+Int(Double(maxY-minY)*0.35),a1=minY+Int(Double(maxY-minY)*0.55)
  for y in a0...a1 {for x in 0..<ww {let a=Double(p[(y*ww+x)*4+3]);sx+=Double(x)*a;weight+=a}}
  let anchorX=name.contains("people") ? sx/max(1,weight):Double(minX+maxX)*0.5
  out.append(WalkCel(image:Raster(ww,hh,p),anchor:(anchorX,Double(maxY)),referenceHeight:Double(maxY-minY)))
 }}
 return out
}
let walkingPeople=walkCels("rank5-v2/people-walk-atlas.png",8,3)
let walkingFoxes=walkCels("rank5-v2/fox-walk-grid.png",4,4)
struct WalkRoute {let name:String,points:[Point],kind:String,height:Double,mirrored:Bool}
let walkRoutes=[
 WalkRoute(name:"upper_open_bridge",points:[(339,187),(475,143)],kind:"bridge_upper",height:22,mirrored:false),
 WalkRoute(name:"covered_bridge",points:[(248,420),(472,339)],kind:"bridge_middle",height:26,mirrored:false),
 WalkRoute(name:"central_stone_steps",points:[(375,365),(373,338),(365,320),(351,306),(349,294),(334,279),(321,266),(303,251),(290,242),(269,231)],kind:"stairs_middle",height:19,mirrored:true),
 WalkRoute(name:"upper_stone_steps",points:[(430,263),(421,246),(411,231),(403,221),(402,208),(390,196),(384,181),(372,160),(361,153)],kind:"stairs_upper",height:15,mirrored:true)
]
struct Walker {let name:String,route:Int,fox:Bool,variant:Int,phase:Double,pace:Double}
let walkers=[
 Walker(name:"upper_indigo",route:0,fox:false,variant:0,phase:0.6,pace:1.2),
 Walker(name:"upper_russet",route:0,fox:false,variant:1,phase:4.6,pace:1.2),
 Walker(name:"upper_second_indigo",route:0,fox:false,variant:0,phase:8.6,pace:1.2),
 Walker(name:"middle_russet",route:1,fox:false,variant:1,phase:0.9,pace:0.8),
 Walker(name:"middle_indigo",route:1,fox:false,variant:0,phase:4.9,pace:0.8),
 Walker(name:"middle_second_russet",route:1,fox:false,variant:1,phase:8.9,pace:0.8),
 Walker(name:"stairs_moss",route:2,fox:false,variant:2,phase:2.0,pace:1.2),
 Walker(name:"stairs_white_fox",route:2,fox:true,variant:0,phase:5.0,pace:1.2),
 Walker(name:"stairs_gold_fox",route:2,fox:true,variant:1,phase:8.5,pace:1.2),
 Walker(name:"upper_stairs_moss",route:3,fox:false,variant:2,phase:5.5,pace:1.2),
 Walker(name:"upper_stairs_white_fox",route:3,fox:true,variant:0,phase:1.8,pace:1.2)
]
func routePoint(_ route:WalkRoute,_ progress:Double)->Point {
 let lengths=zip(route.points,route.points.dropFirst()).map{hypot($1.0-$0.0,$1.1-$0.1)},total=lengths.reduce(0,+)
 var d=progress*total
 for k in lengths.indices {if d<=lengths[k] || k==lengths.count-1 {let t=clamp(d/lengths[k]),a=route.points[k],b=route.points[k+1];return(a.0+(b.0-a.0)*t,a.1+(b.1-a.1)*t)};d-=lengths[k]}
 return route.points.last!
}
func walkerVisible(_ route:WalkRoute,_ x:Double,_ y:Double)->Bool {
 switch route.kind {
 case "bridge_upper":
  guard x>361 && x<453 else{return false}
  let floor=177.9-0.3235*(x-370),rail=floor-15.0
  if y>floor+1 || abs(y-rail)<1.4 || abs(y-(floor-5))<1.1 {return false}
  if [374.0,396,417,438,451].contains(where:{abs(x-$0)<1.25}) && y>rail-3 {return false}
  if x<379 && y<159 {return false}
  return true
 case "bridge_middle":
  guard x>278 && x<439 else{return false}
  let floor=401.2-0.3616*(x-300),roof=floor-40,rail=floor-16
  if y>floor+1 || y<roof+2 || abs(y-rail)<1.6 || abs(y-(floor-5))<1.35 {return false}
  if [291.0,315,341,369,396,423,438].contains(where:{abs(x-$0)<1.5}) && y>roof {return false}
  return true
 case "stairs_middle":
  // The covered bridge is in front of the foot of this stair flight.
  if x>274 && x<445 && y>362-0.385*(x-280) {return false}
  // The route ends behind the actual left torii pillar/crossbeam.
  if x<277 && y<243 {return false}
  if y<207 && x<310 {return false}
  return true
 default:
  // Enter from behind the large shrine's roof; leave behind the upper hall.
  if x>410 && y>242 {return false}
  if x>401 && y>258 {return false}
  if x<379 && y<173 {return false}
  return true
 }
}
func drawWalkers(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 // Draw the more distant routes first. Everything is clipped against fixed
 // front railings, roof edges and torii pillars, not faded in an open walkway.
 for actor in walkers.sorted(by:{walkRoutes[$0.route].height<walkRoutes[$1.route].height}) {
  let route=walkRoutes[actor.route],progress=(time+actor.phase).truncatingRemainder(dividingBy:12)/12
  let foot=routePoint(route,progress),height=route.height*(actor.fox ? 0.69:1.0)
  let walkPhase=(time+actor.phase)/actor.pace*8,index=Int(floor(walkPhase))%8,f=walkPhase-floor(walkPhase)
  let bank=actor.fox ? walkingFoxes:walkingPeople,first=bank[actor.variant*8+index],second=bank[actor.variant*8+(index+1)%8]
  // At this distance a registered whole-cel subpixel blend avoids hard pose
  // ticks without warping the nearby shrine, tails, legs or stairs.
  let scale=height/first.referenceHeight,pad=height*1.3
  let x0=max(0,Int(foot.0-pad)),x1=min(w-1,Int(foot.0+pad)),y0=max(0,Int(foot.1-height-2)),y1=min(h-1,Int(foot.1+2))
  let bob=actor.fox ? 0.12*sin(tau*walkPhase/4):0.18*sin(tau*walkPhase/4)
  for y in y0...y1 {for x in x0...x1 {
   guard walkerVisible(route,Double(x),Double(y)) else{continue}
   let dx=(Double(x)-foot.0)*(route.mirrored ? -1:1),dy=Double(y)-foot.1-bob
   var values=[Double](repeating:0,count:4)
   for (cel,weight) in [(first,1-f),(second,f)] {
    let s=height/cel.referenceHeight,sx=dx/s+cel.anchor.0,sy=dy/s+cel.anchor.1
    guard sx>=0 && sy>=0 && sx<Double(cel.image.w-1) && sy<Double(cel.image.h-1) else{continue}
    for c in 0..<4 {values[c]+=cel.image.at(sx,sy,c)*weight}
   }
   let alpha=values[3]/255
   if alpha<0.01 {continue}
   let i=(y*w+x)*4
   // Gentle depth haze uses the existing cool forest palette.
   let haze=route.kind=="bridge_upper" || route.kind=="stairs_upper" ? 0.22:0.10
   for c in 0..<3 {let foreground=values[c]*(1-haze)+[125.0,157,166][c]*alpha*haze;p[i+c]=UInt8(clamp(foreground+Double(p[i+c])*(1-alpha),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*alpha+Double(p[i+3])*(1-alpha),0,255))}
  }}
  _=scale
 }
}
