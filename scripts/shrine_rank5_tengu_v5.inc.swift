// Whole transparent artwork; only the connected lower legs are displaced.
// Every sample comes from the character RGBA, never from the shrine backdrop.
let tenguRaw=Raster("rank5-v5/tengu-seated.png")
let tengu:Raster={
 var p=tenguRaw.p
 for i in stride(from:0,to:p.count,by:4) {
  let old=Double(p[i+3])/255,a=smooth((old-0.08)/0.66)
  if old>0 {for c in 0..<3 {p[i+c]=UInt8(clamp(Double(p[i+c])*a/old,0,255))}}
  p[i+3]=UInt8(255*a)
 }
 return Raster(tenguRaw.w,tenguRaw.h,p)
}()
let tenguSeat:Point=(491,502)
let tenguScale=44.0/(1272-114)
let tenguOrigin:Point=(tenguSeat.0-526*tenguScale,tenguSeat.1-835*tenguScale)
func tenguDisplacement(_ x:Double,_ y:Double,_ time:Double)->Point {
 let left=x<520,knee:Point=left ? (399,954):(638,956)
 if y<=knee.1 {return (0,0)}
 let pinned=smooth((y-knee.1)/65)
 let phase=tau*time/3+(left ? 0:Double.pi)
 let angle=0.18*sin(phase)*pinned,dx=x-knee.0,dy=y-knee.1
 return ((cos(angle)*dx-sin(angle)*dy)-dx,(sin(angle)*dx+cos(angle)*dy)-dy)
}
func drawTengu(_ pixels:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 if !transparent {
  for y in 501...504 {for x in 483...499 {
   let e=pow((Double(x)-491)/7.5,2)+pow((Double(y)-502.3)/1.3,2),a=clamp(1-e)*0.20,i=(y*w+x)*4
   for c in 0..<3 {pixels[i+c]=UInt8(Double(pixels[i+c])*(1-a))}
  }}
 }
 let x0=Int(floor(tenguOrigin.0))-4,x1=Int(ceil(tenguOrigin.0+Double(tengu.w)*tenguScale))+4
 let y0=Int(floor(tenguOrigin.1)),y1=Int(ceil(tenguOrigin.1+Double(tengu.h)*tenguScale))+3
 // Each calf samples its own source domain, so a swinging foot cannot be
 // remapped to the other leg when it approaches the transparent center gap.
 for pass in 0..<3 {for y in max(0,y0)...min(h-1,y1) {for x in max(0,x0)...min(w-1,x1) {
  let tx=(Double(x)-tenguOrigin.0)/tenguScale,ty=(Double(y)-tenguOrigin.1)/tenguScale
  var sx=tx,sy=ty,coverage=1.0
  if pass<2 {
   let left=pass==0,knee:Point=left ? (399,954):(638,956)
   let angle=0.18*sin(tau*time/3+(left ? 0:Double.pi)),dx=tx-knee.0,dy=ty-knee.1
   sx=knee.0+cos(angle)*dx+sin(angle)*dy
   sy=knee.1-sin(angle)*dx+cos(angle)*dy
   if (sx<520) != left {continue}
   coverage=smooth((sy-knee.1+18)/18)
  } else {
   let kneeY=sx<520 ? 954.0:956.0
   coverage=1-smooth((sy-kneeY-8)/18)
  }
  guard sx>=0 && sy>=0 && sx<Double(tengu.w-1) && sy<Double(tengu.h-1) else{continue}
  let a=tengu.at(sx,sy,3)/255*coverage
  if a<0.01 {continue}
  let i=(y*w+x)*4
  for c in 0..<3 {pixels[i+c]=UInt8(clamp(tengu.at(sx,sy,c)*coverage+Double(pixels[i+c])*(1-a),0,255))}
  if transparent {pixels[i+3]=UInt8(clamp(255*a+Double(pixels[i+3])*(1-a),0,255))}
 }}}
}
