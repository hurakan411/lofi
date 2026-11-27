// Newly revealed sacred-tree and distant-torii ornaments, registered to the
// approved painting. Primary rank-four ornaments keep their exact old cels.
let upperHangingConfigs:[HangingConfig]=[
 ("left_tree_paper_left",22,318,18,29,(31,319),false,3.5,6,0.6,0,[]),
 ("left_tree_paper_right",48,302,18,38,(56,303),false,4.0,12,2.1,0,[]),
 ("right_tree_paper_left",480,404,18,36,(488,405),false,3.8,6,3.8,1,[]),
 ("right_tree_paper_middle",507,408,20,42,(516,409),false,4.4,12,1.3,1,[]),
 ("right_tree_paper_right",546,401,19,41,(554,402),false,3.7,4,4.8,1,[]),
 ("distant_torii_paper_left",465,540,13,27,(471,541),false,2.5,6,2.7,2,[]),
 ("distant_torii_paper_right",488,540,14,26,(495,541),false,2.8,4,0.7,2,[]),
 ("distant_torii_bell",475,537,9,9,(478,538),true,0.18,6,1.5,2,[(477,538),(479,538),(479,541),(481,542),(480,544),(476,544),(475,542),(477,541)])
]
let upperHanging=makeHangingObjects(upperHangingConfigs,35)
let allHanging=hanging+upperHanging
let upperClean=Raster("rank5-v1/upper-clean-atlas.png")
func cleanUpperShrine(_ input:[UInt8])->[UInt8] {
 var p=input
 let origins:[Point]=[(0,242),(440,335),(385,480),(45,95)]
 for object in upperHanging {
  let r=object.image,origin=origins[object.panel],cw=Double(upperClean.w/2),ch=Double(upperClean.h/2)
  for y in max(Int(object.anchor.1),object.y-4)...(object.y+r.h+3) {for x in max(0,object.x-4)...min(w-1,object.x+r.w+3) {
   var erase=0.0
   for yy in max(0,y-object.y-4)...min(r.h-1,y-object.y+4) {for xx in max(0,x-object.x-4)...min(r.w-1,x-object.x+4) {
    let d=hypot(Double(xx+object.x-x),Double(yy+object.y-y))
    erase=max(erase,Double(r.p[(yy*r.w+xx)*4+3])/255*(1-smooth((d-1)/3)))
   }}
   if erase<0.001 {continue}
   let sx=(Double(x)-origin.0)/160*cw+Double(object.panel%2)*cw
   let sy=(Double(y)-origin.1)/160*ch+Double(object.panel/2)*ch
   let i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(Double(p[i+c])*(1-erase)+upperClean.at(sx,sy,c)*erase,0,255))}
  }}
 }
 return p
}
let shrinePlate=cleanUpperShrine(inheritedShrinePlate)

let canopySheet=Raster("rank5-v1/canopy-sprites.png")
let canopyCels=[cropAlpha(canopySheet,CGRect(x:0,y:0,width:760,height:887)),cropAlpha(canopySheet,CGRect(x:760,y:0,width:1014,height:887))]
struct CanopyBough {let cel:Int,root:Point,height:Double,amplitude:Double,period:Double,phase:Double,mirrored:Bool}
let canopyBoughs=[
 CanopyBough(cel:0,root:(-42,165),height:132,amplitude:6.5,period:12,phase:1.7,mirrored:false),
 CanopyBough(cel:1,root:(635,152),height:84,amplitude:7.5,period:6,phase:4.3,mirrored:true)
]
func drawUpperCanopy(_ p:inout[UInt8],_ time:Double,_ transparent:Bool=false) {
 for source in canopyBoughs {
  let r=canopyCels[source.cel],rootX=source.mirrored ? Double(w-1)-source.root.0:source.root.0
  let b=MapleBough(cel:0,root:(rootX,source.root.1),height:source.height,amplitude:source.amplitude,period:source.period,phase:source.phase)
  let scale=b.height/Double(r.h),width=Double(r.w)*scale,left=b.root.0-boughRoot(r)*scale,top=b.root.1-b.height,pad=b.amplitude+4
  let x0=Int(floor(left-pad)),y0=Int(floor(top-pad*0.25)),x1=Int(ceil(left+width+pad)),y1=Int(ceil(b.root.1+pad*0.25))
  let cell=5.0,nx=Int(ceil(Double(x1-x0)/cell))+1,ny=Int(ceil(Double(y1-y0)/cell))+1
  var gx=[Double](repeating:0,count:nx*ny),gy=gx
  for j in 0..<ny {for i in 0..<nx {
   let tx=Double(x0)+Double(i)*cell-left,ty=Double(y0)+Double(j)*cell-top
   var sx=tx,sy=ty
   for _ in 0..<4 {let d=boughDisplacement(b,sx,sy,width,time);sx=tx-d.0;sy=ty-d.1}
   gx[j*nx+i]=sx/scale;gy[j*nx+i]=sy/scale
  }}
  for y in max(0,y0)...min(h-1,y1) {for cx in max(0,x0)...min(w-1,x1) {
   let fx=Double(cx-x0)/cell,fy=Double(y-y0)/cell,ix=min(nx-2,Int(fx)),iy=min(ny-2,Int(fy)),u=fx-Double(ix),v=fy-Double(iy),n=iy*nx+ix
   let sx=gx[n]*(1-u)*(1-v)+gx[n+1]*u*(1-v)+gx[n+nx]*(1-u)*v+gx[n+nx+1]*u*v
   let sy=gy[n]*(1-u)*(1-v)+gy[n+1]*u*(1-v)+gy[n+nx]*(1-u)*v+gy[n+nx+1]*u*v
   guard sx>=0,sy>=0,sx<Double(r.w-1),sy<Double(r.h-1) else{continue}
   let a=r.at(sx,sy,3)/255
   if a<0.01 {continue}
   let x=source.mirrored ? w-1-cx:cx,i=(y*w+x)*4
   for c in 0..<3 {p[i+c]=UInt8(clamp(r.at(sx,sy,c)+Double(p[i+c])*(1-a),0,255))}
   if transparent {p[i+3]=UInt8(clamp(255*a+Double(p[i+3])*(1-a),0,255))}
  }}
 }
}
