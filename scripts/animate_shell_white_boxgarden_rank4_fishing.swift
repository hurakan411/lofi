import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rank4: the first little harbor. Boat, awning, smoke, resident birds and fish.
// Coordinates are in the 1070x1470 approved plate, output at sixty percent.
let rank=4
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shell-harbor/white-boxgarden-v1")
let input=folder.appendingPathComponent("rank-\(rank).png")
let output=folder.appendingPathComponent("rank-4-animation-v2-fishing.gif")
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
// Image-generated cutout, cropped by its real alpha, kept separate from the
// plate so the fisher shares the boat transform without warping the scenery.
let fisherURL=folder.appendingPathComponent("rank-4-fisher-cutout.png")
let fisherSource=CGImageSourceCreateWithURL(fisherURL as CFURL,nil)!
let fisherImage=CGImageSourceCreateImageAtIndex(fisherSource,0,nil)!
let fw=fisherImage.width,fh=fisherImage.height
var fisherRaw=[UInt8](repeating:0,count:fw*fh*4)
fisherRaw.withUnsafeMutableBytes { bytes in
    let c=CGContext(data:bytes.baseAddress,width:fw,height:fh,bitsPerComponent:8,bytesPerRow:fw*4,space:space,bitmapInfo:bitmapInfo)!
    c.draw(fisherImage,in:CGRect(x:0,y:0,width:fw,height:fh))
}
var minFX=fw,minFY=fh,maxFX=0,maxFY=0,transparentCount=0
for y in 0..<fh {for x in 0..<fw {
    let alpha=fisherRaw[(y*fw+x)*4+3]
    if alpha>8 {minFX=min(minFX,x);maxFX=max(maxFX,x);minFY=min(minFY,y);maxFY=max(maxFY,y)}
    if alpha==0 {transparentCount += 1}
}}
precondition(maxFX>minFX && maxFY>minFY && transparentCount>fw*fh/3,"Fisher asset must have genuine transparency")
let fisherCrop=fisherImage.cropping(to:CGRect(x:minFX,y:minFY,width:maxFX-minFX+1,height:maxFY-minFY+1))!
let spriteW=64,spriteH=96
var fisher=[UInt8](repeating:0,count:spriteW*spriteH*4)
fisher.withUnsafeMutableBytes {bytes in
    let c=CGContext(data:bytes.baseAddress,width:spriteW,height:spriteH,bitsPerComponent:8,bytesPerRow:spriteW*4,space:space,bitmapInfo:bitmapInfo)!
    c.interpolationQuality = .high
    c.draw(fisherCrop,in:CGRect(x:0,y:0,width:spriteW,height:spriteH))
}
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
let basin:[Point] = [(575,806),(614,800),(653,802),(681,810),(702,820),
    (732,828),(763,839),(793,851),(822,863),(845,876),(841,891),
    (820,910),(794,933),(764,950),(744,970),(718,980),(695,985),
    (674,995),(634,1000),(592,1009),(546,1008),(500,1001),(457,993),
    (422,978),(403,958),(438,942),(484,926),(524,911),(553,903),
    (558,884),(549,869),(521,867),(503,846),(521,826),(548,816)]
let pond:[Point] = [(294,1025),(257,1037),(220,1052),(214,1070),(243,1086),
    (281,1104),(331,1124),(383,1144),(443,1158),(508,1167),(570,1172),
    (638,1165),(703,1154),(763,1138),(812,1120),(846,1100),(884,1089),
    (922,1072),(926,1054),(907,1037),(904,1012),(892,992),(870,977),
    (849,965),(828,974),(801,987),(777,1000),(760,1021),(768,1053),
    (747,1072),(711,1072),(690,1053),(657,1052),(617,1057),(578,1059),
    (531,1058),(482,1057),(436,1049),(391,1040),(354,1034),(319,1032)]
struct Flow{let start:Point;let end:Point;let width:Double;let bend:Double}
let flows:[Flow] = [Flow(start:(446,631),end:(455,657),width:10,bend:0.5),
    Flow(start:(484,681),end:(503,721),width:24,bend:1),
    Flow(start:(550,745),end:(580,804),width:35,bend:2),
    Flow(start:(700,988),end:(735,1060),width:34,bend:2)]
let waterX0=Int(196.0*scale),waterX1=Int(936.0*scale)
let waterY0=Int(420.0*scale),waterY1=Int(1190.0*scale)
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
    FishJump(start:3.5,from:(623,861),to:(680,880),height:46,length:22,color:[181,199,205]),
    FishJump(start:4.12,from:(739,903),to:(788,920),height:40,length:19,color:[206,174,159]),
    FishJump(start:7.2,from:(646,936),to:(718,958),height:65,length:38,color:[169,192,201]),
    FishJump(start:10.3,from:(457,1086),to:(521,1097),height:43,length:21,color:[174,194,204])]
struct Bird {
    let home:Point
    let water:Point
    let depart:Double
    let arrive:Double
    let leave:Double
    let back:Double
    let outward:[[Point]]
    let returning:[[Point]]
    let heading:Double
    let waterHeading:Double
    let phase:Double
    let color:[Double]
    let drinks:Bool
}
let birds:[Bird] = [
    Bird(home:(371,707),water:(548,886),depart:3.0,arrive:6.0,leave:9.0,back:12.2,
         outward:[[(371,707),(430,640),(160,685),(190,798)],[(190,798),(245,906),(515,934),(548,886)]],
         returning:[[(548,886),(635,940),(260,610),(371,707)]],
         heading:1,waterHeading:1,phase:0.4,color:[105,114,125],drinks:true),
    Bird(home:(656,696),water:(853,878),depart:5.0,arrive:8.2,leave:11.2,back:14.5,
         outward:[[(656,696),(590,580),(965,706),(930,830)],[(930,830),(915,866),(880,881),(853,878)]],
         returning:[[(853,878),(795,735),(741,570),(656,696)]],
         heading:-1,waterHeading:-1,phase:2.3,color:[133,119,107],drinks:true),
    Bird(home:(352,970),water:(352,970),depart:1.4,arrive:5.9,leave:5.9,back:5.9,
         outward:[[(352,970),(365,752),(195,381),(395,400)],
                  [(395,400),(563,388),(650,509),(636,595)],
                  [(636,595),(495,580),(290,830),(352,970)]],returning:[],
         heading:1,waterHeading:1,phase:4.6,color:[102,116,125],drinks:false)]
struct BirdPose {let center:Point;let heading:Double;let flying:Double;let peck:Double;let tilt:Double;let groundY:Double;let drinking:Bool}
func bezier(_ p:[Point],_ t:Double)->Point {
    let a=1-t
    return (a*a*a*p[0].0+3*a*a*t*p[1].0+3*a*t*t*p[2].0+t*t*t*p[3].0,
            a*a*a*p[0].1+3*a*a*t*p[1].1+3*a*t*t*p[2].1+t*t*t*p[3].1)
}
func birdPose(_ bird:Bird,_ time:Double)->BirdPose? {
    let out=time>=bird.depart && time<bird.arrive
    let returning=bird.drinks && time>=bird.leave && time<bird.back
    if out || returning {
        let start=out ? bird.depart:bird.leave,end=out ? bird.arrive:bird.back
        let route=out ? bird.outward:bird.returning
        let t=clamp((time-start)/(end-start)),s=t*Double(route.count)
        let segment=min(route.count-1,Int(s)),u=s-Double(segment),points=route[segment]
        let center=bezier(points,u),a=bezier(points,max(0,u-0.005)),b=bezier(points,min(1,u+0.005))
        let folded=min(smooth((time-start)/0.22),smooth((end-time)/0.30))
        let tilt=clamp(atan2(b.1-a.1,abs(b.0-a.0)),-0.35,0.35)
        return BirdPose(center:center,heading:b.0>=a.0 ? 1:-1,flying:folded,peck:0,tilt:tilt,groundY:center.1+9,drinking:false)
    }
    let drinking=bird.drinks && time>=bird.arrive && time<bird.leave
    let center=drinking ? bird.water:bird.home
    let age=drinking ? time-bird.arrive:time
    let peck=drinking ? pow(max(0,sin(age*tau)),4):0.5*pow(max(0,sin(time*tau/4+bird.phase)),12)
    return BirdPose(center:center,heading:drinking ? bird.waterHeading:bird.heading,flying:0,peck:peck,tilt:0,groundY:center.1+9,drinking:drinking)
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
    WindPatch(outline:[(269,930),(310,926),(338,946),(326,967),(283,959)],rootY:976,amplitude:2.6,frequency:3,phase:3.6),
    WindPatch(outline:[(356,983),(409,986),(435,1005),(414,1027),(365,1014)],rootY:1030,amplitude:2.3,frequency:4,phase:5.2),
    WindPatch(outline:[(695,747),(739,742),(760,768),(748,791),(708,785)],rootY:798,amplitude:2.5,frequency:3,phase:0.8),
    WindPatch(outline:[(791,811),(830,815),(840,839),(825,852),(796,842)],rootY:858,amplitude:2.1,frequency:4,phase:2.2)]
var windMasks=[[Double]]()
var boatMask=[Double](repeating:0,count:w*h),awningMask=boatMask
let boatOutline:[Point]=[(551,894),(647,897),(657,925),(642,947),(576,948),(550,927)]
let awningOutline:[Point]=[(397,835),(437,829),(457,850),(443,861),(411,858),(397,850)]
var leafCoverage=[Double](repeating:0,count:w*h)
for p in 0..<(w*h) {
    let r=Double(base[p*4]),g=Double(base[p*4+1]),b=Double(base[p*4+2])
    leafCoverage[p]=clamp((g-b-9)/15)*clamp((r-b-6)/12)*clamp((g-r+22)/18)
}
for (j,patch) in windPatches.enumerated() {
    var mask=[Double](repeating:0,count:w*h)
    for y in waterY0...waterY1 {for x in waterX0...waterX1 {
        let p=y*w+x
        var amount=polygonMask(Double(x)/scale,Double(y)/scale,patch.outline,feather:7)
        if j<3 && amount>0 {
            // Only leaf clusters may flutter. Brown branches, trunks and the
            // shell remain fixed instead of warping a whole canopy rectangle.
            let r=Double(base[p*4]),g=Double(base[p*4+1]),b=Double(base[p*4+2])
            if r>g+20 && r>b+10 {amount=0}
            else {
                var nearby=leafCoverage[p]
                for yy in max(0,y-1)...min(h-1,y+1) {for xx in max(0,x-1)...min(w-1,x+1) {
                    nearby=max(nearby,leafCoverage[yy*w+xx]*0.65)
                }}
                amount *= nearby
            }
        }
        mask[p]=amount
    }}
    windMasks.append(mask)
}
for y in waterY0...waterY1{for x in 0..<w{
    let px=Double(x)/scale,py=Double(y)/scale,p=y*w+x
    basinMask[p]=polygonMask(px,py,basin,feather:6)
    boatMask[p]=polygonMask(px,py,boatOutline,feather:7)
    awningMask[p]=polygonMask(px,py,awningOutline,feather:3)
    basinMask[p] *= 1-boatMask[p]
    for pool:[Point] in [
        [(445,652),(464,651),(482,664),(491,677),(479,681),(463,671)],
        [(493,720),(515,718),(541,733),(555,746),(538,750),(514,738),(494,732)]
    ] {basinMask[p]=max(basinMask[p],polygonMask(px,py,pool,feather:3))}
    pondMask[p]=polygonMask(px,py,pond,feather:7)
    permittedWater[p]=max(basinMask[p],pondMask[p])
    permittedWater[p]=max(permittedWater[p],max(boatMask[p],awningMask[p]))
    if px>=278 && px<=335 && py>=625 && py<=735 {permittedWater[p]=1}
    if px>=578 && px<=710 && py>=850 && py<=973 {permittedWater[p]=1}
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
for bird in birds {
    for t in [0.0,duration] {
        let pose=birdPose(bird,t)!
        precondition(hypot(pose.center.0-bird.home.0,pose.center.1-bird.home.1)<0.01 && pose.flying==0)
    }
    if bird.drinks {
        let x=Int((bird.water.0+13*bird.waterHeading)*scale),y=Int((bird.water.1+7.5)*scale)
        precondition(basinMask[y*w+x]>0.01,"Drinking beak must reach water")
    }
}
// All birds exist on the island at both loop endpoints. Only their local
// orbit/drinking silhouettes may change outside existing water/wind regions.
for index in 0..<frameCount {for bird in birds {
    guard let pose=birdPose(bird,Double(index)/Double(fps)) else{continue}
    precondition(pose.center.0>110 && pose.center.0<970 && pose.center.1>370 && pose.center.1<1030,"Bird must stay around the miniature island")
    let left=max(0,Int((pose.center.0-34)*scale)),right=min(w-1,Int((pose.center.0+34)*scale))
    let top=max(0,Int((pose.center.1-34)*scale)),bottom=min(h-1,Int((pose.center.1+34)*scale))
    if left<=right && top<=bottom {for y in top...bottom {for x in left...right {permittedWater[y*w+x]=1}}}
}}
func colorBlend(_ p:inout[UInt8],_ x:Int,_ y:Int,_ color:[Double],_ alpha:Double){
    guard x>=0,y>=0,x<w,y<h else{return}
    let i=(y*w+x)*4,a=clamp(alpha)
    for c in 0..<3{p[i+c]=UInt8(clamp(Double(p[i+c])*(1-a)+color[c]*a,0,255))}
}
func drawFisher(_ pixels:inout[UInt8],_ time:Double) {
    let phase=tau*time/duration
    let rise=1.65*sin(phase*4)+0.4*sin(phase*7),drift=0.6*sin(phase*2)
    let angle=0.009*sin(phase*3),ca=cos(angle),sa=sin(angle)
    func boatPoint(_ p:Point)->Point {
        let dx=p.0-601,dy=p.1-922
        return (601+dx*ca-dy*sa+drift,922+dx*sa+dy*ca+rise)
    }
    func stroke(_ a:Point,_ b:Point,_ color:[Double],_ width:Double,_ opacity:Double) {
        let aa=boatPoint(a),bb=boatPoint(b),dx=bb.0-aa.0,dy=bb.1-aa.1
        for y in Int((min(aa.1,bb.1)-2)*scale)...Int((max(aa.1,bb.1)+2)*scale) {
            for x in Int((min(aa.0,bb.0)-2)*scale)...Int((max(aa.0,bb.0)+2)*scale) {
                let px=Double(x)/scale,py=Double(y)/scale
                let t=clamp(((px-aa.0)*dx+(py-aa.1)*dy)/max(0.001,dx*dx+dy*dy))
                let d=hypot(px-aa.0-t*dx,py-aa.1-t*dy)
                colorBlend(&pixels,x,y,color,clamp((width*0.5+0.75-d)/0.9)*opacity)
            }
        }
    }
    let tip:Point=(672+1.4*sin(phase*2),865+2.2*sin(phase*2))
    let handle:Point=(613,904),bend:Point=(634,867+1.5*sin(phase*2))
    let float:Point=(687+1.3*sin(phase*3),952+0.8*sin(phase*5))
    func quad(_ a:Point,_ b:Point,_ c:Point,_ t:Double)->Point {
        let v=1-t;return (v*v*a.0+2*v*t*b.0+t*t*c.0,v*v*a.1+2*v*t*b.1+t*t*c.1)
    }
    for j in 0..<24 {
        let t=Double(j)/24,u=Double(j+1)/24
        stroke(quad(handle,bend,tip,t),quad(handle,bend,tip,u),[131,111,84],1.25,0.95)
        stroke(quad(tip,(683+sin(phase*2),909),float,t),quad(tip,(683+sin(phase*2),909),float,u),[184,199,207],0.65,0.72)
    }
    let f=boatPoint(float)
    for y in Int((f.1-6)*scale)...Int((f.1+6)*scale) {for x in Int((f.0-15)*scale)...Int((f.0+15)*scale) {
        let px=Double(x)/scale,py=Double(y)/scale
        let r=hypot(px-f.0,(py-f.1-2)/0.28)
        let water=basinMask[y*w+x]
        let radius=5+2*sin(phase*5)
        colorBlend(&pixels,x,y,[191,209,219],exp(-pow((r-radius)/1.1,2))*0.23*water)
        let body=clamp((1-pow((px-f.0)/1.8,2)-pow((py-f.1)/3,2))*2)
        colorBlend(&pixels,x,y,py<f.1 ? [192,131,98]:[218,210,181],body)
    }}
    func spriteSample(_ x:Double,_ y:Double,_ channel:Int)->Double {
        let xx=clamp(x,0,Double(spriteW-2)),yy=clamp(y,0,Double(spriteH-2))
        let ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*spriteW+ix)*4+channel
        return Double(fisher[i])*(1-fx)*(1-fy)+Double(fisher[i+4])*fx*(1-fy)+Double(fisher[i+spriteW*4])*(1-fx)*fy+Double(fisher[i+spriteW*4+4])*fx*fy
    }
    for y in Int(875*scale)...Int(929*scale) {for x in Int(580*scale)...Int(623*scale) {
        let dx=Double(x)/scale-601-drift,dy=Double(y)/scale-922-rise
        let sx=601+dx*ca+dy*sa,sy=922-dx*sa+dy*ca
        let u=(sx-587)/28,v=(sy-881)/42
        guard u>=0,u<1,v>=0,v<1 else{continue}
        let alpha=spriteSample(u*Double(spriteW-1),v*Double(spriteH-1),3)
        guard alpha>0 else{continue}
        let color=(0..<3).map{clamp(spriteSample(u*Double(spriteW-1),v*Double(spriteH-1),$0)*255/alpha,0,255)}
        colorBlend(&pixels,x,y,color,alpha/255)
    }}
}
func drawHarborDetails(_ pixels:inout[UInt8],_ time:Double) {
    let phase=tau*time/duration
    let rise=1.65*sin(phase*4)+0.4*sin(phase*7)
    let drift=0.6*sin(phase*2),angle=0.009*sin(phase*3)
    let ca=cos(angle),sa=sin(angle)
    for y in Int(822*scale)...Int(954*scale) {for x in Int(390*scale)...Int(662*scale) {
        let p=y*w+x,px=Double(x)/scale,py=Double(y)/scale
        var a=boatMask[p]
        if a>0 {
            let dx=px-601-drift,dy=py-922-rise
            let sx=(601+dx*ca+dy*sa)*scale,sy=(922-dx*sa+dy*ca)*scale
            for c in 0..<3 {
                pixels[p*4+c]=UInt8(clamp(Double(pixels[p*4+c])*(1-a)+sample(clean,sx,sy,c)*a,0,255))
            }
        }
        a=awningMask[p]
        if a>0 {
            let free=smooth((py-831)/29)
            let dy=free*(1.3*sin(phase*3+px*0.035)+0.35*sin(phase*7))
            for c in 0..<3 {
                pixels[p*4+c]=UInt8(clamp(Double(pixels[p*4+c])*(1-a)+sample(clean,Double(x),Double(y)-dy*scale,c)*a,0,255))
            }
        }
    }}
    // Connected smoke at the chimney mouth, then overlapping puffs that
    // clearly rise, drift and dissolve without a detached first cloud.
    for y in Int(647*scale)...Int(727*scale) {for x in Int(280*scale)...Int(334*scale) {
        let py=Double(y)/scale,px=Double(x)/scale,age=clamp((727-py)/80)
        let center=297+12*age+2.4*age*sin(phase*2-age*9)
        let width=2.0+6*age
        let core=exp(-pow((px-center)/width,2)*1.6)
        let travel=0.80+0.20*sin(phase*10+age*24)
        colorBlend(&pixels,x,y,[211,207,198],core*(1-age)*0.45*travel)
    }}
    for j in 0..<14 {
        let age=(time/3.2+Double(j)/14).truncatingRemainder(dividingBy:1)
        let cx=297+12*age+3*sin(age*8+phase*2+Double(j))*age
        let cy=727-age*80,radius=2.8+age*7
        let opacity=0.38*pow(sin(.pi*age),1.3)
        for y in Int((cy-radius-1)*scale)...Int((cy+radius+1)*scale) {
            for x in Int((cx-radius-1)*scale)...Int((cx+radius+1)*scale) {
                let r=hypot((Double(x)/scale-cx)/radius,(Double(y)/scale-cy)/(radius*0.85))
                colorBlend(&pixels,x,y,[211,207,198],smooth(1-r)*opacity)
            }
        }
    }
}
func drawBird(_ pixels:inout[UInt8],_ bird:Bird,_ time:Double) {
    guard let pose=birdPose(bird,time) else{return}
    let cx=pose.center.0,cy=pose.center.1
    let angle=pose.tilt*pose.heading,ca=cos(angle),sa=sin(angle)
    let flap=sin((time-bird.depart)*tau*5.7+bird.phase)
    let tip = -3.0-(4+12*flap)*pose.flying
    let wing:[Point]=[(3,-1),(-1,-4),(-5,tip),(-10,tip+2),(-5,1)]
    let farWing:[Point]=[(1,-2),(-2,-4),(-3,-3+(tip+2)*0.70),(-8,-2+(tip+2)*0.65),(-4,0)]
    let headX=5+pose.peck*2.2,headY = -4.5+pose.peck*8
    if pose.drinking {
        let age=(time-bird.arrive).truncatingRemainder(dividingBy:1)
        if age>0.18 && age<0.85 {
            let t=(age-0.18)/0.67,cx=pose.center.0+13*pose.heading,cy=pose.center.1+7.5
            let radius=2+8*t
            for y in Int((cy-4)*scale)...Int((cy+4)*scale) {for x in Int((cx-13)*scale)...Int((cx+13)*scale) {
                guard x>=0,y>=0,x<w,y<h else{continue}
                let water=max(basinMask[y*w+x],pondMask[y*w+x])
                let r=hypot(Double(x)/scale-cx,(Double(y)/scale-cy)/0.30)
                colorBlend(&pixels,x,y,[193,212,222],exp(-pow((r-radius)/1.2,2))*(1-t)*0.65*water)
            }}
        }
    }
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
            let dx:Double,dy:Double
            if j<3 {
                // Several small leaves flutter with different phases. No
                // common canopy translation and no vertical trunk stretching.
                dx=height*(1.65*sin(phase*3+px*0.047+patch.phase)+0.45*flutter)
                dy=height*0.45*sin(phase*5+px*0.075+py*0.04+patch.phase)
            } else {
                dx=patch.amplitude*height*(branch+0.20*flutter)
                dy=height*(0.55*sin(phase*(patch.frequency+1)+patch.phase)+0.20*flutter)
            }
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
    drawHarborDetails(&pixels,time)
    drawFisher(&pixels,time)
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
    let previewFrames=[0,70,181,194,236,325]
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
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-4-motion-check-v2-fishing.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
let report="""
White platform rank \(rank): \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
First little harbor: stone cottage terrace, short pier and one rowboat. Boat gently bobs/rocks, fabric awning stirs, subtle chimney smoke rises. Four cascades and water ripples; small fish and one larger 38px fish jump. Color-isolated leaves flutter with fixed trunks/branches, five grass/flower patches sway independently.
Small seated human fisher uses generated transparent cutout, shares boat bob/rotation, holds subtly moving rod/line with a float on the water. Chimney smoke has a continuous mouth-connected plume plus 14 rising/dissolving puffs for improved visibility. Cutout alpha verified.
All three birds start/finish on grass. Two fly around the island to water perches (pier edge/right shore), drink with tiny ripples, then fly home. Third circles the shell and returns to grass. No off-canvas entries/exits. Water-contact points and flight positions verified.
Water patch bounds: \(waterX0),\(waterY0) to \(waterX1),\(waterY1). Outer pond shoreline remains fixed inside this rank's loop.
Changed pixels within authorized water/fish/wind/bird regions: \(waterChanged.count).
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette and transparent delta frames.
GIF has no audio. Shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-4-animation-report-v2-fishing.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
