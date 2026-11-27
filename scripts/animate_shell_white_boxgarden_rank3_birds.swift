import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rank3: shell becomes a vegetated hill; localized wind, cascades and fish.
// Coordinates are in the 1070x1470 approved plate, output at sixty percent.
let rank=3
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shell-harbor/white-boxgarden-v1")
let input=folder.appendingPathComponent("rank-\(rank).png")
let output=folder.appendingPathComponent("rank-3-animation-v2-birds.gif")
let w=642,h=882,fps=25,frameCount=400
let duration=Double(frameCount)/Double(fps),scale=0.6,tau=2*Double.pi
let space=CGColorSpaceCreateDeviceRGB()
let bitmapInfo=CGImageAlphaInfo.premultipliedLast.rawValue
func clamp(_ v:Double,_ lo:Double=0,_ hi:Double=1)->Double{min(hi,max(lo,v))}
func smooth(_ v:Double)->Double{let t=clamp(v);return t*t*(3-2*t)}
guard let source=CGImageSourceCreateWithURL(input as CFURL,nil),
      let sourceImage=CGImageSourceCreateImageAtIndex(source,0,nil) else{fatalError("Missing rank2 plate")}
var base=[UInt8](repeating:0,count:w*h*4)
base.withUnsafeMutableBytes{bytes in
    let c=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:bitmapInfo)!
    c.interpolationQuality = .high
    c.draw(sourceImage,in:CGRect(x:0,y:0,width:w,height:h))
}
var clean=base
func sample(_ p:[UInt8],_ x:Double,_ y:Double,_ c:Int)->Double{
    let xx=clamp(x,0,Double(w-2)),yy=clamp(y,0,Double(h-2))
    let ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*w+ix)*4+c
    return Double(p[i])*(1-fx)*(1-fy)+Double(p[i+4])*fx*(1-fy)+Double(p[i+w*4])*(1-fx)*fy+Double(p[i+w*4+4])*fx*fy
}
typealias Point=(Double,Double)
func polygonMask(_ x:Double,_ y:Double,_ vertices:[Point],feather:Double)->Double{
    var inside=false,distance=Double.greatestFiniteMagnitude
    for j in vertices.indices{
        let a=vertices[j],b=vertices[(j+1)%vertices.count]
        if (a.1>y) != (b.1>y), x<(b.0-a.0)*(y-a.1)/(b.1-a.1)+a.0{inside.toggle()}
        let dx=b.0-a.0,dy=b.1-a.1
        let t=clamp(((x-a.0)*dx+(y-a.1)*dy)/max(0.001,dx*dx+dy*dy))
        distance=min(distance,hypot(x-a.0-t*dx,y-a.1-t*dy))
    }
    return inside ? smooth(distance/feather):0
}
let basin:[Point] = [(575,804),(613,797),(653,802),(681,806),(702,818),
    (732,822),(762,827),(790,839),(826,851),(846,864),(841,879),
    (814,896),(783,911),(752,929),(738,942),(706,942),(675,949),
    (632,952),(579,948),(543,939),(507,927),(471,907),(433,888),
    (417,873),(408,854),(424,837),(455,824),(489,814),(527,808)]
let pond:[Point] = [(298,995),(263,1004),(227,1024),(213,1042),(231,1060),
    (264,1075),(308,1094),(359,1111),(415,1131),(475,1140),(541,1146),
    (607,1146),(673,1140),(738,1129),(783,1114),(822,1098),(853,1081),
    (892,1071),(920,1058),(922,1042),(900,1027),(899,1007),(891,989),
    (873,974),(853,962),(835,948),(807,958),(779,970),(756,983),
    (756,1012),(752,1031),(732,1040),(706,1024),(685,1014),(650,1015),
    (602,1018),(555,1025),(505,1023),(455,1022),(408,1006),(366,1000),(329,1002)]
struct Flow{let start:Point;let end:Point;let width:Double;let bend:Double}
let flows:[Flow] = [Flow(start:(446,631),end:(455,657),width:10,bend:0.5),
    Flow(start:(484,681),end:(503,721),width:24,bend:1),
    Flow(start:(550,745),end:(580,804),width:35,bend:2),
    Flow(start:(704,955),end:(735,1024),width:31,bend:2)]
let waterX0=Int(196.0*scale),waterX1=Int(936.0*scale)
let waterY0=Int(420.0*scale),waterY1=Int(1160.0*scale)
let x0=0,x1=w-1,y0=Int(350.0*scale),y1=waterY1
// Replace the baked rank1 droplet locally before rendering unbroken water.
if rank==1 {
    let patch:[Point]=[(687,1027),(711,1027),(715,1036),(715,1053),(685,1053),(685,1038)]
    for y in Int(1026*scale)...Int(1055*scale) {
        for x in Int(683*scale)...Int(717*scale) {
            let px=Double(x)/scale,py=Double(y)/scale
            let a=polygonMask(px,py,patch,feather:4)
            if a>0 {
                let mix=clamp((px-677)/47),i=(y*w+x)*4
                for c in 0..<3 {
                    let background=sample(base,677*scale,Double(y),c)*(1-mix)+sample(base,724*scale,Double(y),c)*mix
                    clean[i+c]=UInt8(clamp(Double(base[i+c])*(1-a)+background*a,0,255))
                }
            }
        }
    }
}
var basinMask=[Double](repeating:0,count:w*h),pondMask=basinMask,permittedWater=basinMask
struct FishJump {
    let start:Double
    let from:Point
    let to:Point
    let height:Double
    let length:Double
    let color:[Double]
    let flight=1.12
}
let fishJumps:[FishJump] = [
    FishJump(start:3.5,from:(524,870),to:(585,879),height:48,length:22,color:[181,199,205]),
    FishJump(start:4.12,from:(664,872),to:(713,888),height:44,length:19,color:[206,174,159]),
    FishJump(start:10.3,from:(457,1086),to:(521,1097),height:43,length:21,color:[174,194,204])]
struct Bird {
    let start:Double
    let land:Double
    let leave:Double
    let end:Double
    let incoming:[Point]
    let outgoing:[Point]
    let heading:Double
    let phase:Double
    let color:[Double]
    let flyOnly:Bool
}
let birds:[Bird] = [
    Bird(start:1.0,land:3.6,leave:10.8,end:13.4,
         incoming:[(-35,588),(110,480),(318,552),(371,707)],
         outgoing:[(377,707),(430,630),(800,480),(1105,550)],
         heading:1,phase:0.4,color:[105,114,125],flyOnly:false),
    Bird(start:3.1,land:5.5,leave:12.4,end:15.1,
         incoming:[(1105,600),(942,494),(733,540),(656,696)],
         outgoing:[(650,696),(575,582),(210,478),(-35,550)],
         heading:-1,phase:2.3,color:[133,119,107],flyOnly:false),
    Bird(start:5.8,land:9.9,leave:9.9,end:9.9,
         incoming:[(1105,515),(810,349),(320,365),(-35,497)],outgoing:[],
         heading:-1,phase:4.6,color:[102,116,125],flyOnly:true)]
struct BirdPose {let center:Point;let heading:Double;let flying:Double;let peck:Double;let tilt:Double;let groundY:Double}
func bezier(_ p:[Point],_ t:Double)->Point {
    let a=1-t
    return (a*a*a*p[0].0+3*a*a*t*p[1].0+3*a*t*t*p[2].0+t*t*t*p[3].0,
            a*a*a*p[0].1+3*a*a*t*p[1].1+3*a*t*t*p[2].1+t*t*t*p[3].1)
}
func birdPose(_ bird:Bird,_ time:Double)->BirdPose? {
    guard time>=bird.start && time<bird.end else{return nil}
    let groundY=bird.incoming[3].1+9
    if time<bird.land || bird.flyOnly || time>=bird.leave {
        let entering=time<bird.land || bird.flyOnly
        let start=entering ? bird.start:bird.leave,end=entering ? bird.land:bird.end
        let t=clamp((time-start)/(end-start))
        let points=entering ? bird.incoming:bird.outgoing
        let center=bezier(points,t),a=bezier(points,max(0,t-0.005)),b=bezier(points,min(1,t+0.005))
        let folded=bird.flyOnly ? 1.0:(entering ? smooth((end-time)/0.35):smooth((time-start)/0.20))
        let tilt=clamp(atan2(b.1-a.1,abs(b.0-a.0)),-0.35,0.35)
        return BirdPose(center:center,heading:bird.heading,flying:folded,peck:0,tilt:tilt,groundY:groundY)
    }
    let age=time-bird.land
    let cycle=age.truncatingRemainder(dividingBy:2.4)
    let step=Int(age/2.4),direction=step%2==0 ? 1.0:-1.0
    let hop=clamp((cycle-1.55)/0.40)
    let offset=6*((step%2==0 ? 0.0:1.0)+direction*smooth(hop))
    let height=4*sin(.pi*hop)
    let peck=cycle>0.45 && cycle<1.15 ? pow(sin((cycle-0.45)/0.70*tau),2):0
    return BirdPose(center:(bird.incoming[3].0+offset*bird.heading,bird.incoming[3].1-height),
                    heading:bird.heading,flying:0,peck:peck,tilt:0,groundY:groundY)
}
struct WindPatch {
    let outline:[Point]
    let rootY:Double
    let amplitude:Double
    let frequency:Double
    let phase:Double
}
let windPatches:[WindPatch] = [
    WindPatch(outline:[(232,425),(383,425),(388,486),(345,495),(327,508),(310,508),(286,499),(235,501)],rootY:517,amplitude:4.5,frequency:2,phase:0.2),
    WindPatch(outline:[(499,532),(640,532),(645,605),(582,609),(559,622),(546,620),(534,607),(500,602)],rootY:631,amplitude:4.0,frequency:3,phase:2.4),
    WindPatch(outline:[(700,649),(830,649),(834,706),(785,718),(765,735),(751,729),(741,711),(700,708)],rootY:740,amplitude:4.3,frequency:2,phase:4.7),
    WindPatch(outline:[(279,705),(342,697),(354,723),(318,745),(275,734)],rootY:746,amplitude:2.3,frequency:5,phase:1.2),
    WindPatch(outline:[(258,846),(309,839),(336,868),(320,893),(274,889)],rootY:900,amplitude:2.6,frequency:3,phase:3.6),
    WindPatch(outline:[(365,913),(416,915),(434,938),(416,959),(370,948)],rootY:964,amplitude:2.3,frequency:4,phase:5.2),
    WindPatch(outline:[(695,747),(739,742),(760,768),(748,791),(708,785)],rootY:798,amplitude:2.5,frequency:3,phase:0.8),
    WindPatch(outline:[(791,811),(830,815),(840,839),(825,852),(796,842)],rootY:858,amplitude:2.1,frequency:4,phase:2.2)]
var windMasks=[[Double]]()
for patch in windPatches {
    var mask=[Double](repeating:0,count:w*h)
    for y in waterY0...waterY1 {for x in waterX0...waterX1 {
        mask[y*w+x]=polygonMask(Double(x)/scale,Double(y)/scale,patch.outline,feather:7)
    }}
    windMasks.append(mask)
}
for y in waterY0...waterY1{for x in 0..<w{
    let px=Double(x)/scale,py=Double(y)/scale,p=y*w+x
    basinMask[p]=polygonMask(px,py,basin,feather:6)
    for pool:[Point] in [
        [(445,652),(464,651),(482,664),(491,677),(479,681),(463,671)],
        [(493,720),(515,718),(541,733),(555,746),(538,750),(514,738),(494,732)]
    ] {basinMask[p]=max(basinMask[p],polygonMask(px,py,pool,feather:3))}
    pondMask[p]=polygonMask(px,py,pond,feather:7)
    permittedWater[p]=max(basinMask[p],pondMask[p])
    for mask in windMasks {permittedWater[p]=max(permittedWater[p],mask[p])}
    for f in flows{
        if py>=f.start.1-5,py<=f.end.1+8{
            let t=clamp((py-f.start.1)/(f.end.1-f.start.1))
            let cx=f.start.0+(f.end.0-f.start.0)*t+f.bend*sin(.pi*t)
            if abs(px-cx)<max(18,f.width*0.85){permittedWater[p]=1}
        }
    }
    for f in flows where abs(py-f.end.1)<13 && abs(px-f.end.0)<26{permittedWater[p]=1}
    // Explicitly allow only the short fish arcs and their landing splashes.
    for f in fishJumps {
        if px>=min(f.from.0,f.to.0)-40 && px<=max(f.from.0,f.to.0)+52 &&
           py>=min(f.from.1,f.to.1)-f.height-18 && py<=max(f.from.1,f.to.1)+18 {permittedWater[p]=1}
    }
}}
// Only the swept bird silhouettes may change outside the existing water/wind
// regions; flights start and finish beyond the canvas, never fading in midair.
for index in 0..<frameCount {for bird in birds {
    guard let pose=birdPose(bird,Double(index)/Double(fps)) else{continue}
    let left=max(0,Int((pose.center.0-34)*scale)),right=min(w-1,Int((pose.center.0+34)*scale))
    let top=max(0,Int((pose.center.1-34)*scale)),bottom=min(h-1,Int((pose.center.1+34)*scale))
    if left<=right && top<=bottom {for y in top...bottom {for x in left...right {permittedWater[y*w+x]=1}}}
}}
func colorBlend(_ p:inout[UInt8],_ x:Int,_ y:Int,_ color:[Double],_ alpha:Double){
    guard x>=0,y>=0,x<w,y<h else{return}
    let i=(y*w+x)*4,a=clamp(alpha)
    for c in 0..<3{p[i+c]=UInt8(clamp(Double(p[i+c])*(1-a)+color[c]*a,0,255))}
}
func drawBird(_ pixels:inout[UInt8],_ bird:Bird,_ time:Double) {
    guard let pose=birdPose(bird,time) else{return}
    let cx=pose.center.0,cy=pose.center.1
    let angle=pose.tilt*pose.heading,ca=cos(angle),sa=sin(angle)
    let flap=sin((time-bird.start)*tau*5.7+bird.phase)
    let tip = -3.0-(4+12*flap)*pose.flying
    let wing:[Point]=[(3,-1),(-1,-4),(-5,tip),(-10,tip+2),(-5,1)]
    let farWing:[Point]=[(1,-2),(-2,-4),(-3,-3+(tip+2)*0.70),(-8,-2+(tip+2)*0.65),(-4,0)]
    let headX=5+pose.peck*2.2,headY = -4.5+pose.peck*8
    func ellipse(_ u:Double,_ v:Double,_ x:Double,_ y:Double,_ rx:Double,_ ry:Double)->Double {
        clamp((1-pow((u-x)/rx,2)-pow((v-y)/ry,2))*min(rx,ry)*0.95)
    }
    func line(_ u:Double,_ v:Double,_ a:Point,_ b:Point,_ width:Double)->Double {
        let dx=b.0-a.0,dy=b.1-a.1
        let t=clamp(((u-a.0)*dx+(v-a.1)*dy)/max(0.001,dx*dx+dy*dy))
        return clamp(width-hypot(u-a.0-dx*t,v-a.1-dy*t))
    }
    let left=max(0,Int((cx-31)*scale)),right=min(w-1,Int((cx+31)*scale))
    let top=max(0,Int((cy-31)*scale)),bottom=min(h-1,Int((cy+31)*scale))
    guard left<=right && top<=bottom else{return}
    for y in top...bottom {for x in left...right {
        let dx=Double(x)/scale-cx,dy=Double(y)/scale-cy
        let u=(dx*ca+dy*sa)*pose.heading,v = -dx*sa+dy*ca
        if pose.flying<0.1 {
            let shadow=ellipse(Double(x)/scale,Double(y)/scale,cx,pose.groundY+0.6,9,2.4)
            colorBlend(&pixels,x,y,[75,75,78],shadow*0.18)
        }
        let legs=max(line(u,v,(-2,3),(-2,9),0.85),line(u,v,(2,3),(3,9),0.85))
        let toes=max(line(u,v,(-3,9),(0,9),0.85),line(u,v,(2,9),(5,9),0.85))
        colorBlend(&pixels,x,y,[118,104,88],max(legs,toes)*(1-pose.flying))
        let far=polygonMask(u,v,farWing,feather:0.65)
        colorBlend(&pixels,x,y,bird.color.map{$0+12},far*pose.flying)
        let tail=polygonMask(u,v,[(-5,-1),(-13,-2),(-12,3),(-5,2)],feather:0.5)
        colorBlend(&pixels,x,y,bird.color.map{$0-18},tail)
        let body=ellipse(u,v,pose.peck*0.6,0,6.5,4.5)
        let belly=clamp((v+1)/6)
        colorBlend(&pixels,x,y,bird.color.enumerated().map{j,c in c+(j==2 ? 20:33)*belly},body)
        let neck=ellipse(u,v,4.1,headY*0.30,3.4,3.3)
        let head=ellipse(u,v,headX,headY,3.5,3.2)
        colorBlend(&pixels,x,y,bird.color.map{$0+6},max(neck,head))
        let nearWing=polygonMask(u,v,wing,feather:0.65)
        let foldedWing=ellipse(u,v,-1.3,-0.1,4.4,2.7)
        colorBlend(&pixels,x,y,bird.color.map{$0-23},max(nearWing*pose.flying,foldedWing*(1-pose.flying)))
        let beak=polygonMask(u,v,[(headX+2.9,headY-0.3),(headX+6.3,headY+0.9),(headX+2.8,headY+1.5)],feather:0.45)
        colorBlend(&pixels,x,y,[152,129,92],beak)
        let eye=clamp(1.15-hypot(u-headX-1.3,v-headY+0.65))
        colorBlend(&pixels,x,y,[51,59,68],eye)
    }}
}
// Small native fish silhouettes follow a continuous ballistic arc. Body, tail,
// fin and eye share one transform so they cannot separate during rotation.
func drawFishJump(_ pixels:inout[UInt8],_ fish:FishJump,_ time:Double) {
    let elapsed=time-fish.start
    guard elapsed>=0 && elapsed<fish.flight+1.55 else{return}
    func splash(_ at:Point,_ age:Double,_ strength:Double) {
        guard age>=0 && age<1.55 else{return}
        let radius=5+age*24
        let fade=pow(1-age/1.55,1.5)*strength
        for y in Int((at.1-17)*scale)...Int((at.1+18)*scale) {
            for x in Int((at.0-45)*scale)...Int((at.0+45)*scale) {
                guard x>=0,y>=0,x<w,y<h else{continue}
                let water=max(basinMask[y*w+x],pondMask[y*w+x])
                guard water>0 else{continue}
                let r=hypot(Double(x)/scale-at.0,(Double(y)/scale-at.1)/0.30)
                let ring=exp(-pow((r-radius)/1.9,2)) + 0.5*exp(-pow((r-radius*0.68)/1.3,2))
                colorBlend(&pixels,x,y,[207,221,226],ring*fade*0.72*water)
            }
        }
        if age<0.58 {
            for k in 0..<6 {
                let t=age/0.58
                let spread=(Double(k)-2.5)*7.2
                let xx=at.0+spread*t
                let yy=at.1-(18+Double(k%3)*6)*4*t*(1-t)
                for y in Int((yy-2)*scale)...Int((yy+2)*scale) {
                    for x in Int((xx-2)*scale)...Int((xx+2)*scale) {
                        let d=hypot(Double(x)/scale-xx,(Double(y)/scale-yy)*0.8)
                        colorBlend(&pixels,x,y,[203,221,231],clamp(1.5-d)*strength*(1-t)*0.8)
                    }
                }
            }
        }
    }
    splash(fish.from,elapsed,0.60)
    splash(fish.to,elapsed-fish.flight,1.0)
    guard elapsed<fish.flight else{return}
    let t=elapsed/fish.flight
    let cx=fish.from.0+(fish.to.0-fish.from.0)*t
    let cy=fish.from.1+(fish.to.1-fish.from.1)*t-fish.height*4*t*(1-t)
    let vx=fish.to.0-fish.from.0
    let vy=fish.to.1-fish.from.1-fish.height*4*(1-2*t)
    let angle=atan2(vy,vx),ca=cos(angle),sa=sin(angle)
    let visibility=smooth(t/0.075)*smooth((1-t)/0.08)
    let half=fish.length*0.5,bodyH=fish.length*0.17
    let flutter=sin(t*tau*5)*0.8
    for y in Int((cy-fish.length)*scale)...Int((cy+fish.length)*scale) {
        for x in Int((cx-fish.length)*scale)...Int((cx+fish.length)*scale) {
            let dx=Double(x)/scale-cx,dy=Double(y)/scale-cy
            let u=dx*ca+dy*sa,v=dy*ca-dx*sa
            let body=clamp((1-pow(u/half,2)-pow(v/bodyH,2))*3)
            let tailT=clamp((-u-half*0.55)/(half*0.70))
            let tail=(u < -half*0.55 && u > -half*1.25)
                ? smooth((bodyH*(0.3+tailT*1.15)-abs(v-flutter*tailT))/1.0):0
            let fin=(u > -half*0.45 && u < half*0.2 && v < 0)
                ? smooth((bodyH*1.4+v)/0.8)*smooth((-v-bodyH*0.55)/0.8):0
            let shade=clamp((v/bodyH+1)*0.5)
            let color=fish.color.map{$0+13-28*shade}
            colorBlend(&pixels,x,y,color,max(body,max(tail*0.85,fin*0.65))*visibility)
            let eye=hypot(u-half*0.58,v+bodyH*0.16)
            if eye<1.05 {colorBlend(&pixels,x,y,[54,68,77],clamp(1.2-eye)*visibility)}
        }
    }
}
func frame(_ time:Double)->[UInt8]{
    var pixels=clean
    let phase=tau*time/duration
    // Feathered individual branches move around fixed roots, at different
    // phases. Rock, shell contours, disk and camera never move.
    for (j,patch) in windPatches.enumerated() {
        let mask=windMasks[j]
        for y in waterY0...waterY1 {for x in waterX0...waterX1 {
            let p=y*w+x,a=mask[p]
            guard a>0 else{continue}
            let py=Double(y)/scale,px=Double(x)/scale
            let height=smooth((patch.rootY-py)/55)
            let branch=sin(phase*patch.frequency+patch.phase)
            let flutter=sin(phase*7+px*0.095+py*0.06+patch.phase)
            let dx=patch.amplitude*height*(branch+0.20*flutter)
            let dy=height*(0.55*sin(phase*(patch.frequency+1)+patch.phase)+0.20*flutter)
            for c in 0..<3 {
                let original=Double(clean[p*4+c])
                let shifted=sample(clean,Double(x)-dx*scale,Double(y)-dy*scale,c)
                pixels[p*4+c]=UInt8(clamp(original*(1-a)+shifted*a,0,255))
            }
        }}
    }
    for y in waterY0...waterY1{for x in 0..<w{
        let p=y*w+x,i=p*4,px=Double(x)/scale,py=Double(y)/scale
        let im=basinMask[p],om=pondMask[p],mask=max(im,om)
        guard mask>0 else{continue}
        let movement=rank==1 ? 2.5:1.7
        var sx=movement*0.75*sin(px*0.047+py*0.055-phase*3)
        var sy=movement*0.52*sin(px*0.041-py*0.031-phase*4)
        var light=movement*2.3*sin(px*0.082+py*0.13-phase*3)
        for (j,f) in flows.enumerated(){
            let dx=px-f.end.0,dy=(py-f.end.1)/0.30
            let r=max(1,hypot(dx,dy))
            let large=j>=2
            let extent=large ? 235.0:150.0
            let envelope=exp(-r/(large ? 125:80))*smooth(r/7)*smooth((extent-r)/45)
            let wave=tau*r/(large ? 32:26)-phase*Double(large ? 20:18)
            let crest=pow(max(0,cos(wave)),8)
            let strength=j>=2 ? 1.6:0.65
            sx += dx/r*sin(wave)*envelope*strength
            sy += dy/r*sin(wave)*envelope*strength*0.30
            light += (crest*15-sin(wave)*3.0)*envelope*strength
        }
        if om>0{
            let radial=hypot((px-780)*0.72,(py-1062)*2)
            light += sin(radial*0.08-phase*7)*0.9
        }
        for c in 0..<3{
            let warped=sample(clean,Double(x)+sx*scale*mask,Double(y)+sy*scale*mask,c)
            pixels[i+c]=UInt8(clamp(Double(clean[i+c])*(1-mask)+(warped+light*[0.68,0.88,1.0][c])*mask,0,255))
        }
    }}
    for (j,f) in flows.enumerated(){
        let broad=f.width>10
        let startY=Int((f.start.1-1)*scale),endY=Int((f.end.1+3)*scale)
        for y in startY...endY{
            let py=Double(y)/scale,t=clamp((py-f.start.1)/(f.end.1-f.start.1))
            let cx=f.start.0+(f.end.0-f.start.0)*t+f.bend*sin(.pi*t)
            let edgeTaper=broad ? 1.0-0.12*t:1.0-0.28*t
            let half=f.width*0.5*edgeTaper
            for x in Int((cx-half-3)*scale)...Int((cx+half+3)*scale){
                let dx=Double(x)/scale-cx
                let body=smooth((half-abs(dx))/max(1,broad ? 2:0.9))
                guard body>0 else{continue}
                let travel=t*32-phase*Double(broad ? 72:84)+Double(j)
                let shimmer=0.5+0.5*sin(travel)
                // Modulate original translucent flow; do not paint an opaque stripe.
                let sheen=(sin(dx*(broad ? 0.8:1.4)+travel)*0.5+0.5)*(rank==1 ? 0.45:0.35)+0.16
                let highlight=pow(max(0,cos(dx*0.72+travel*0.7)),8)
                colorBlend(&pixels,x,y,[99+shimmer*21,131+shimmer*20,159+shimmer*20],body*sheen)
                colorBlend(&pixels,x,y,[186,209,221],body*highlight*(rank==1 ? 0.65:0.34))
            }
        }
        // Small churning patch where each flow meets its own receiving surface.
        for y in Int((f.end.1-4)*scale)...Int((f.end.1+5)*scale){
            for x in Int((f.end.0-18)*scale)...Int((f.end.0+19)*scale){
                let dx=(Double(x)/scale-f.end.0)/18,dy=(Double(y)/scale-f.end.1)/4.5
                let alpha=clamp(1-dx*dx-dy*dy)*(rank==1 ? 0.35+0.17*sin(phase*48+dx*8):0.18+0.1*sin(phase*48+dx*8+Double(j)))
                colorBlend(&pixels,x,y,[144,167,184],alpha)
            }
        }
    }
    for fish in fishJumps { drawFishJump(&pixels,fish,time) }
    for bird in birds {drawBird(&pixels,bird,time)}
    return pixels
}

// Fixed shared palette prevents static-shell or ground shimmer from per-frame
// GIF quantization. Quantization and LZW follow existing shrine GIF exporters.
struct ColorBin { let r:Int; let g:Int; let b:Int; let count:Int }
var histogram: [Int:Int] = [:]
for y in stride(from:0,to:h,by:2) { for x in stride(from:0,to:w,by:2) {
    let i=(y*w+x)*4
    let key=(Int(base[i])>>3)<<10 | (Int(base[i+1])>>3)<<5 | (Int(base[i+2])>>3)
    histogram[key,default:0] += 1
}}
histogram.removeValue(forKey:32767)
var boxes=[histogram.map { key,count in ColorBin(r:((key>>10)&31)*8+4,g:((key>>5)&31)*8+4,b:(key&31)*8+4,count:count) }]
func spread(_ box:[ColorBin]) -> (Int,Int) {
    let ranges=[box.map(\.r).max()!-box.map(\.r).min()!,box.map(\.g).max()!-box.map(\.g).min()!,box.map(\.b).max()!-box.map(\.b).min()!]
    let axis=ranges.enumerated().max(by:{$0.element<$1.element})!.offset
    return (axis,ranges[axis])
}
while boxes.count<254 {
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
var palette:[[Int]]=[[0,0,0],[255,255,255]]+boxes.map {box in
    let total=box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 {palette.append(palette.last!)}
var colorCache=[Int](repeating:-1,count:32768)
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
    if r>=253 && g>=253 && b>=253 {return 1}
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
func lzw(_ bytes:[UInt8])->[UInt8] {
    var encoded:[UInt8]=[],accumulator=0,bitCount=0
    func emit(_ code:Int) {
        accumulator |= code<<bitCount;bitCount += 9
        while bitCount>=8{encoded.append(UInt8(accumulator&255));accumulator >>= 8;bitCount -= 8}
    }
    var table:[Int:Int]=[:],next=258,prefix=Int(bytes[0]);emit(256)
    for value in bytes.dropFirst() {
        let byte=Int(value),key=(prefix<<8)|byte
        if let code=table[key]{prefix=code}
        else{emit(prefix);table[key]=next;next += 1;prefix=byte
            if next>=500{emit(256);table.removeAll(keepingCapacity:true);next=258}}
    }
    emit(prefix);emit(257);if bitCount>0{encoded.append(UInt8(accumulator&255))};return encoded
}
var gif=Data("GIF89a".utf8)
func byte(_ n:Int){gif.append(UInt8(n))}
func word(_ n:Int){byte(n&255);byte((n>>8)&255)}
word(w);word(h);byte(0xF7);byte(0);byte(0)
for color in palette{for value in color{byte(value)}}
gif.append(contentsOf:[0x21,0xFF,0x0B]);gif.append(Data("NETSCAPE2.0".utf8));gif.append(contentsOf:[3,1,0,0,0])
var first:[UInt8]=[],previous:[UInt8]=[],last:[UInt8]=[]
var maxDelta=0.0,changingPixels=Set<Int>(),outsideChanges=0
var snapshots:[[UInt8]]=[]
var previousIndices=[UInt8](repeating:0,count:w*h)
var waterChanged=Set<Int>()
for index in 0..<frameCount {
    let pixels=frame(Double(index)/Double(fps))
    if index==0{first=pixels}
    let previewFrames=[55,115,160,185,280,337]
    if previewFrames.contains(index){snapshots.append(pixels)}
    var delta=0.0
    if !previous.isEmpty {
        for y in 0..<h{for x in 0..<w{
            let i=(y*w+x)*4
            for c in 0..<3 where pixels[i+c] != first[i+c] {
                changingPixels.insert(y*w+x)
                let inWater=permittedWater[y*w+x] > 0
                if inWater {waterChanged.insert(y*w+x)}
                if !inWater {outsideChanges += 1}
            }
            if x>=x0,x<=x1,y>=y0,y<=y1 {
                for c in 0..<3{delta += abs(Double(pixels[i+c])-Double(previous[i+c]))}
            }
        }}
        maxDelta=max(maxDelta,delta/Double((x1-x0+1)*(y1-y0+1)*3))
    }
    previous=pixels;last=pixels
    let left=index==0 ? 0:x0,top=index==0 ? 0:y0
    let width=index==0 ? w:x1-x0+1,height=index==0 ? h:y1-y0+1
    var indices=[UInt8]();indices.reserveCapacity(width*height)
    for y in top..<(top+height){for x in left..<(left+width){
        let p=y*w+x,i=p*4
        let value=paletteIndex(pixels[i],pixels[i+1],pixels[i+2])
        indices.append(index>0 && previousIndices[p]==value ? 0:value)
        previousIndices[p]=value
    }}
    gif.append(contentsOf:[0x21,0xF9,4,UInt8(index==0 ? 4:5),4,0,0,0,0x2C])
    word(left);word(top);word(width);word(height);byte(0);byte(8)
    let data=lzw(indices)
    for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])}
    byte(0)
    if index%50==0{print("Rendered \(index)/\(frameCount)")}
}
byte(0x3B);try gif.write(to:output)
var seam=0.0
for y in y0...y1{for x in x0...x1{for c in 0..<3{
    let i=(y*w+x)*4+c;seam += abs(Double(first[i])-Double(last[i]))
}}}
seam /= Double((x1-x0+1)*(y1-y0+1)*3)
precondition(outsideChanges==0,"Motion leaked onto platform or background")
precondition(waterChanged.count>200,"Water should animate")
precondition(seam<=maxDelta*1.4,"Loop seam is too abrupt")
guard let check=CGImageSourceCreateWithURL(output as CFURL,nil),CGImageSourceGetCount(check)==frameCount,
      CGImageSourceCreateImageAtIndex(check,frameCount-1,nil) != nil else{fatalError("Invalid GIF")}
let meta=CGImageSourceCopyProperties(check,nil)! as NSDictionary
precondition((meta[kCGImagePropertyGIFDictionary] as? NSDictionary)?[kCGImagePropertyGIFLoopCount] as? Int == 0)
var decodedDuration=0.0
for j in 0..<frameCount {
    let props=CGImageSourceCopyPropertiesAtIndex(check,j,nil)! as NSDictionary
    let values=props[kCGImagePropertyGIFDictionary] as! NSDictionary
    decodedDuration += (values[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (values[kCGImagePropertyGIFDelayTime] as! Double)
}
precondition(abs(decodedDuration-duration)<0.001)
func makeImage(_ pixels:[UInt8])->CGImage {
    CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,
            bitmapInfo:CGBitmapInfo(rawValue:bitmapInfo),provider:CGDataProvider(data:Data(pixels) as CFData)!,
            decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
let cropW=waterX1-waterX0+1,cropH=waterY1-waterY0+1,zoom=2
let sheetW=cropW*zoom*2,sheetH=cropH*zoom*3
let sheet=CGContext(data:nil,width:sheetW,height:sheetH,bitsPerComponent:8,bytesPerRow:sheetW*4,space:space,bitmapInfo:bitmapInfo)!
sheet.interpolationQuality = .none
for (j,pixels) in snapshots.enumerated(){
    let crop=makeImage(pixels).cropping(to:CGRect(x:waterX0,y:waterY0,width:cropW,height:cropH))!
    sheet.draw(crop,in:CGRect(x:(j%2)*cropW*zoom,y:(2-j/2)*cropH*zoom,width:cropW*zoom,height:cropH*zoom))
}
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-3-motion-check-v2-birds.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
let report="""
White platform rank \(rank): \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
Shell has become a terraced green hill. Four continuous cascades, water reflections/ripples, eight localized wind patches with independently phased trees and plants, three fish jumps at 3.5, 4.12 and 10.3 seconds with splashes. White disk, rock and background remain static.
Three small birds: two arrive, land on grassy terraces, peck and hop, then take off; one flies across above the island. Bird1 lands at 3.6s and leaves at 10.8s; bird2 lands at 5.5s and leaves at 12.4s. All enter and exit beyond the canvas.
Water patch bounds: \(waterX0),\(waterY0) to \(waterX1),\(waterY1). Outer pond shoreline remains fixed inside this rank's loop.
Changed pixels within authorized water/fish/wind/bird regions: \(waterChanged.count).
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette and transparent delta frames.
GIF has no audio. Shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-3-animation-report-v2-birds.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
