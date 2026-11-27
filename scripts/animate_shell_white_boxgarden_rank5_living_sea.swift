import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Rank5: completed miniature shell harbor, preserving corrected water flow.
// Coordinates are in the 1070x1470 approved plate, output at sixty percent.
let rank=5
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath)
let folder=root.appendingPathComponent("output/concepts/shell-harbor/white-boxgarden-v1")
let input=folder.appendingPathComponent("rank-5-sea-v2.png")
let output=folder.appendingPathComponent("rank-5-animation-v4-waves-wind.gif")
let harborYOffset=30.0
let chimneys:[(Point,Double)]=[((297,756),0),((294,650),2.0),((841,724),4.4)]
let w=642,h=882,fps=25,frameCount=600
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
struct RasterSprite {
    let width:Int
    let height:Int
    let aspect:Double
    let pixels:[UInt8]
}
func loadCutout(_ filename:String,_ column:Int?=nil)->RasterSprite {
    let src=CGImageSourceCreateWithURL(folder.appendingPathComponent(filename) as CFURL,nil)!
    var img=CGImageSourceCreateImageAtIndex(src,0,nil)!
    if let column {
        let width=img.width/3
        img=img.cropping(to:CGRect(x:column*width,y:0,width:width,height:img.height))!
    }
    let sw=img.width,sh=img.height
    var raw=[UInt8](repeating:0,count:sw*sh*4)
    raw.withUnsafeMutableBytes{ bytes in
        let c=CGContext(data:bytes.baseAddress,width:sw,height:sh,bitsPerComponent:8,bytesPerRow:sw*4,space:space,bitmapInfo:bitmapInfo)!
        c.draw(img,in:CGRect(x:0,y:0,width:sw,height:sh))
    }
    var x0=sw,y0=sh,x1=0,y1=0,clear=0
    for y in 0..<sh {for x in 0..<sw {
        let alpha=raw[(y*sw+x)*4+3]
        if alpha>8{x0=min(x0,x);x1=max(x1,x);y0=min(y0,y);y1=max(y1,y)}
        if alpha==0 {clear += 1}
    }}
    precondition(x1>x0 && y1>y0 && clear>sw*sh/3,"Cutout requires genuine alpha")
    let cropped=img.cropping(to:CGRect(x:x0,y:y0,width:x1-x0+1,height:y1-y0+1))!
    let aspect=Double(cropped.width)/Double(cropped.height)
    let height=128,width=max(16,Int(Double(height)*aspect))
    var pixels=[UInt8](repeating:0,count:width*height*4)
    pixels.withUnsafeMutableBytes{bytes in
        let c=CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:space,bitmapInfo:bitmapInfo)!
        c.interpolationQuality = .high;c.draw(cropped,in:CGRect(x:0,y:0,width:width,height:height))
    }
    return RasterSprite(width:width,height:height,aspect:aspect,pixels:pixels)
}
let residents=(0..<3).map{loadCutout("rank-5-residents-cutouts.png",$0)}
let coastalBoat=loadCutout("rank-5-coastal-boat-cutout-v2.png")
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
let basin:[Point] = [(575,836),(614,830),(638,822),(655,821),(668,831),
    (673,852),(685,866),(705,878),(737,892),(778,901),(814,903),
    (843,908),(849,923),(829,943),(800,962),(772,980),(746,1000),
    (720,1012),(695,1015),(674,1025),(634,1030),(592,1039),
    (546,1038),(500,1031),(457,1023),(422,1008),(403,988),
    (438,972),(484,956),(524,941),(553,933),(558,914),(549,899),
    (521,897),(503,876),(521,856),(548,846)]
let pond:[Point] = [(294,1055),(257,1067),(220,1082),(214,1100),(243,1116),
    (281,1134),(331,1154),(383,1174),(443,1188),(508,1197),(570,1202),
    (638,1195),(703,1184),(763,1168),(812,1150),(846,1130),(884,1119),
    (922,1102),(926,1084),(907,1067),(904,1042),(892,1022),(870,1007),
    (849,995),(828,1004),(801,1017),(777,1030),(760,1051),(768,1083),
    (747,1102),(711,1102),(690,1083),(657,1082),(617,1087),(578,1089),
    (531,1088),(482,1087),(436,1079),(391,1070),(354,1064),(319,1062)]
let islandFootprint:[Point]=[(150,780),(930,780),(925,940),(881,1012),
    (804,1060),(704,1091),(587,1102),(465,1094),(358,1084),(256,1049),
    (195,1004),(161,942)]
struct StreamSection {let y:Double;let left:Double;let right:Double}
struct Flow {
    let sections:[StreamSection]
    let cycles:Int
    var start:Point {(0.5*(sections[0].left+sections[0].right),sections[0].y)}
    var end:Point {let p=sections.last!;return (0.5*(p.left+p.right),p.y)}
    func at(_ y:Double)->(left:Double,right:Double,arc:Double)? {
        guard y>=sections[0].y && y<=sections.last!.y else{return nil}
        var arc=0.0
        for j in 0..<(sections.count-1) {
            let a=sections[j],b=sections[j+1]
            let length=hypot((b.left+b.right-a.left-a.right)*0.5,b.y-a.y)
            if y<=b.y {
                let t=(y-a.y)/(b.y-a.y)
                return (a.left+(b.left-a.left)*t,a.right+(b.right-a.right)*t,arc+length*t)
            }
            arc += length
        }
        return nil
    }
}
func sections(_ rows:[(Double,Double,Double)])->[StreamSection] {
    rows.map{StreamSection(y:$0.0,left:$0.1,right:$0.2)}
}
// Trace the actual water silhouette, including the shallow channels between
// falls. Old straight constant-width bands partly covered neighboring rock.
let flows:[Flow] = [
    Flow(sections:sections([(659,436,445),(666,439,450),(676,443,456),(684,446,460),(690,448,466)]),cycles:48),
    Flow(sections:sections([(690,448,466),(697,463,483),(705,476,497),(713,482,506),(726,489,514),(739,493,519),(752,496,527)]),cycles:48),
    Flow(sections:sections([(752,500,525),(759,513,549),(769,533,572),(779,548,588),(790,557,595),(805,563,600),(828,566,606),(835,565,609)]),cycles:48),
    Flow(sections:sections([(998,660,704),(1008,668,718),(1018,679,731),(1028,692,742),(1043,705,751),(1058,713,756),(1073,717,760),(1087,718,760)]),cycles:48),
    Flow(sections:sections([(752,648,658),(762,652,664),(775,658,671),(782,649,667),(792,644,662),(805,638,657),(817,635,654)]),cycles:36),
    Flow(sections:sections([(873,841,856),(880,830,846),(888,817,837),(899,810,829)]),cycles:36)
]
for f in flows {
    precondition(f.cycles>0)
    for j in 1..<f.sections.count {
        precondition(f.sections[j].y>f.sections[j-1].y && f.sections[j].right>f.sections[j].left)
        precondition(f.at(f.sections[j].y)!.arc>f.at(f.sections[j-1].y)!.arc)
    }
}
let flowOffsets=[0.0,flows[0].at(flows[0].end.1)!.arc,
    flows[0].at(flows[0].end.1)!.arc+flows[1].at(flows[1].end.1)!.arc,0.0,0.0,0.0]
// phase = 2π*arc/24 - 2π*time*cycles/duration. Its maxima therefore
// travel strictly downstream at 24*cycles/duration = 48 source pixels/sec.
let waterX0=Int(60.0*scale),waterX1=Int(1010.0*scale)
let waterY0=Int(420.0*scale),waterY1=Int(1230.0*scale)
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
    FishJump(start:3.5,from:(623,891),to:(680,910),height:46,length:22,color:[181,199,205]),
    FishJump(start:4.12,from:(739,933),to:(788,950),height:40,length:19,color:[206,174,159]),
    FishJump(start:7.2,from:(646,966),to:(718,988),height:65,length:38,color:[169,192,201]),
    FishJump(start:10.3,from:(457,1116),to:(521,1127),height:43,length:21,color:[174,194,204])]
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
    Bird(home:(371,707),water:(548,916),depart:3.0,arrive:6.0,leave:9.0,back:12.2,
         outward:[[(371,707),(430,640),(160,685),(190,798)],[(190,798),(245,906),(515,964),(548,916)]],
         returning:[[(548,916),(635,970),(260,610),(371,707)]],
         heading:1,waterHeading:1,phase:0.4,color:[105,114,125],drinks:true),
    Bird(home:(694,711),water:(827,941),depart:5.0,arrive:8.2,leave:11.2,back:14.5,
         outward:[[(694,711),(590,580),(965,706),(930,830)],[(930,830),(915,866),(854,944),(827,941)]],
         returning:[[(827,941),(795,735),(741,570),(694,711)]],
         heading:-1,waterHeading:-1,phase:2.3,color:[133,119,107],drinks:true),
    Bird(home:(352,1000),water:(352,1000),depart:1.4,arrive:5.9,leave:5.9,back:5.9,
         outward:[[(352,1000),(365,752),(195,381),(395,400)],
                  [(395,400),(563,388),(650,509),(636,595)],
                  [(636,595),(495,580),(290,860),(352,1000)]],returning:[],
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
let boatOutline:[Point]=[(551.0,894.0),(647,897),(657,925),(642,947),(576,948),(550,927)].map{($0.0,$0.1+harborYOffset)}
let awningOutline:[Point]=[(397.0,835.0),(437,829),(457,850),(443,861),(411,858),(397,850)].map{($0.0,$0.1+harborYOffset)}
var leafCoverage=[Double](repeating:0,count:w*h),branchCoverage=leafCoverage
for p in 0..<(w*h) {
    let r=Double(base[p*4]),g=Double(base[p*4+1]),b=Double(base[p*4+2])
    leafCoverage[p]=clamp((g-b-9)/15)*clamp((r-b-6)/12)*clamp((g-r+22)/18)
    if r<165 && g<150 && b<140 {branchCoverage[p]=clamp((r-g-7)/13)*clamp((g-b-3)/10)}
}
let trunkXs=[315.0,554.0,760.0]
for (j,patch) in windPatches.enumerated() {
    var mask=[Double](repeating:0,count:w*h)
    for y in waterY0...waterY1 {for x in waterX0...waterX1 {
        let p=y*w+x
        var amount=polygonMask(Double(x)/scale,Double(y)/scale,patch.outline,feather:7)
        if amount>0 {
            // Include fine twigs with their leaves; protect the thick trunk
            // and exclude the surrounding buildings and rock.
            let r=Double(base[p*4]),g=Double(base[p*4+1]),b=Double(base[p*4+2])
            if j>=3 && r>g+20 && r>b+10 {amount=0}
            else {
                var nearby=leafCoverage[p]
                let radius=j<3 ? 2:1
                for yy in max(0,y-radius)...min(h-1,y+radius) {for xx in max(0,x-radius)...min(w-1,x+radius) {
                    var candidate=leafCoverage[yy*w+xx]
                    if j<3 && Double(yy)/scale<patch.rootY-18 {candidate=max(candidate,branchCoverage[yy*w+xx])}
                    nearby=max(nearby,candidate*0.70)
                }}
                amount *= nearby
                if j<3 && abs(Double(x)/scale-trunkXs[j])<3.0 && Double(y)/scale>patch.rootY-65 {amount=0}
            }
        }
        mask[p]=amount
    }}
    windMasks.append(mask)
}
// Permit the displaced crown silhouette as well as its original footprint.
var windMotionCoverage=[Double](repeating:0,count:w*h)
var windEnvelopes=[[Double]]()
for (j,mask) in windMasks.enumerated() {
    var envelope=[Double](repeating:0,count:w*h)
    let padding=j<3 ? 8:3
    for p in 0..<(w*h) where mask[p]>0 {
        let x=p%w,y=p/w
        for yy in max(0,y-padding)...min(h-1,y+padding) {
            for xx in max(0,x-padding)...min(w-1,x+padding) {
                envelope[yy*w+xx]=1;windMotionCoverage[yy*w+xx]=1
            }
        }
    }
    windEnvelopes.append(envelope)
}
for y in waterY0...waterY1{for x in 0..<w{
    let px=Double(x)/scale,py=Double(y)/scale,p=y*w+x
    basinMask[p]=polygonMask(px,py,basin,feather:6)
    boatMask[p]=polygonMask(px,py,boatOutline,feather:7)
    awningMask[p]=polygonMask(px,py,awningOutline,feather:3)
    basinMask[p] *= 1-boatMask[p]
    let r=hypot((px-535)/472,(py-1027)/188)
    let sea=smooth((1-r)/0.025)*(1-polygonMask(px,py,islandFootprint,feather:6))
    let i=p*4,red=Double(clean[i]),green=Double(clean[i+1]),blue=Double(clean[i+2])
    let waterColor=clamp((blue-red+14)/26)*clamp((green-red+10)/20)*clamp((246-max(red,max(green,blue)))/28)
    pondMask[p]=sea*waterColor
    permittedWater[p]=max(basinMask[p],pondMask[p])
    permittedWater[p]=max(permittedWater[p],max(boatMask[p],awningMask[p]))
    for (mouth,_) in chimneys {
        if px>=mouth.0-19 && px<=mouth.0+38 && py>=mouth.1-102 && py<=mouth.1+8 {permittedWater[p]=1}
    }
    if px>=578 && px<=710 && py>=850+harborYOffset && py<=973+harborYOffset {permittedWater[p]=1}
    if px>=832 && px<=892 && py>=800 && py<=875 {permittedWater[p]=1}
    if hypot((px-392)/14,(py-454)/12)<1 {permittedWater[p]=1}
    if px>=635 && px<=695 && py>=690 && py<=750 {permittedWater[p]=1}
    if px>=395 && px<=485 && py>=895 && py<=958 {permittedWater[p]=1}
    if px>=165 && px<=905 && py>=1035 && py<=1210 {permittedWater[p]=1}
    permittedWater[p]=max(permittedWater[p],windMotionCoverage[p])
    for f in flows{
        if let section=f.at(py),px>=section.left,px<=section.right {
            permittedWater[p]=1
        }
    }
    for f in flows where abs(py-f.end.1)<9 && abs(px-f.end.0)<44{permittedWater[p]=1}
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
struct ShorePixel {let index:Int;let distance:Double;let arc:Double;let coverage:Double}
// Trace the outer waterline, keeping the waves off the inner harbor and disk.
let shore:[Point]=[(151,894),(161,942),(195,1004),(256,1049),(358,1084),
    (465,1094),(587,1102),(704,1091),(804,1060),(881,1012),(925,940),(923,900)]
var shorePixels=[ShorePixel]()
for y in waterY0...waterY1 {for x in 0..<w {
    let p=y*w+x
    guard pondMask[p]>0.02 else{continue}
    let px=Double(x)/scale,py=Double(y)/scale
    var closest=Double.greatestFiniteMagnitude,along=0.0,prefix=0.0
    for j in 0..<(shore.count-1) {
        let a=shore[j],b=shore[j+1],dx=b.0-a.0,dy=(b.1-a.1)/0.45
        let length=hypot(dx,dy)
        let t=clamp(((px-a.0)*dx+(py-a.1)/0.45*dy)/(length*length))
        let d=hypot(px-a.0-t*dx,(py-a.1)/0.45-t*dy)
        if d<closest {closest=d;along=prefix+t*length}
        prefix += length
    }
    if closest<48 {shorePixels.append(ShorePixel(index:p,distance:closest,arc:along,coverage:pondMask[p]))}
}}
precondition(shorePixels.count>500,"Shore wave field must reach the coastal water")
func colorBlend(_ p:inout[UInt8],_ x:Int,_ y:Int,_ color:[Double],_ alpha:Double){
    guard x>=0,y>=0,x<w,y<h else{return}
    let i=(y*w+x)*4,a=clamp(alpha)
    for c in 0..<3{p[i+c]=UInt8(clamp(Double(p[i+c])*(1-a)+color[c]*a,0,255))}
}
func drawShoreWaves(_ pixels:inout[UInt8],_ time:Double) {
    for s in shorePixels {
        // Four-second swash/backwash cycles, offset along the coast. The crest
        // travels to the rocks, spreads, and retreats rather than blinking.
        let q=(time/4+s.arc/1500).truncatingRemainder(dividingBy:1)
        let advance=q<0.58 ? 1-smooth(q/0.58):smooth((q-0.58)/0.42)
        let center=3+26*advance+2.2*sin(s.arc*0.038+tau*time/4),width=1.6+2.6*(1-advance)
        let crest=exp(-pow((s.distance-center)/width,2))
        let life=pow(max(0,sin(Double.pi*q)),0.65)
        let breakup=pow(max(0,sin(s.arc*0.11+0.6*sin(s.arc*0.035))),0.6)
        let foam=crest*life*breakup*0.74*s.coverage
        colorBlend(&pixels,s.index%w,s.index/w,[225,239,237],foam)
        let ripple=exp(-pow((s.distance-center-5)/2.8,2))*life*0.10*s.coverage
        colorBlend(&pixels,s.index%w,s.index/w,[69,137,156],ripple)
    }
}
func sampleCoverage(_ mask:[Double],_ x:Double,_ y:Double)->Double {
    let xx=clamp(x,0,Double(w-2)),yy=clamp(y,0,Double(h-2))
    let ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy)
    return (mask[iy*w+ix]*(1-fx)+mask[iy*w+ix+1]*fx)*(1-fy)
        + (mask[(iy+1)*w+ix]*(1-fx)+mask[(iy+1)*w+ix+1]*fx)*fy
}
func drawSprite(_ pixels:inout[UInt8],_ sprite:RasterSprite,foot:Point,height:Double,
                heading:Double=1,compression:Double=1,angle:Double=0,bridgeClip:Bool=false,sink:Double=0) {
    let width=height*sprite.aspect*compression,ca=cos(angle),sa=sin(angle)
    let pad=width*0.58+abs(height*sa)+3
    func read(_ x:Double,_ y:Double,_ channel:Int)->Double {
        let xx=clamp(x,0,Double(sprite.width-2)),yy=clamp(y,0,Double(sprite.height-2))
        let ix=Int(xx),iy=Int(yy),fx=xx-Double(ix),fy=yy-Double(iy),i=(iy*sprite.width+ix)*4+channel
        return Double(sprite.pixels[i])*(1-fx)*(1-fy)+Double(sprite.pixels[i+4])*fx*(1-fy)+Double(sprite.pixels[i+sprite.width*4])*(1-fx)*fy+Double(sprite.pixels[i+sprite.width*4+4])*fx*fy
    }
    for y in max(0,Int((foot.1-height-4)*scale))...min(h-1,Int((foot.1+4)*scale)) {
        for x in max(0,Int((foot.0-pad)*scale))...min(w-1,Int((foot.0+pad)*scale)) {
            let px=Double(x)/scale,py=Double(y)/scale
            if bridgeClip && py>736+0.006*pow(px-655,2) {continue}
            let dx=px-foot.0,dy=py-foot.1
            let u=(dx*ca+dy*sa)/width*heading+0.5,v=(-dx*sa+dy*ca)/height+1
            guard u>=0,u<1,v>=0,v<1 else{continue}
            let sx=u*Double(sprite.width-1),sy=v*Double(sprite.height-1),alpha=read(sx,sy,3)
            guard alpha>0 else{continue}
            let color=(0..<3).map{clamp(read(sx,sy,$0)*255/alpha,0,255)}
            let waterline=sink>0 ? smooth((foot.1-py)/sink):1
            colorBlend(&pixels,x,y,color,alpha/255*waterline)
        }
    }
}
func coastalPosition(_ time:Double)->Point {
    let a=tau*time/duration
    return (535+300*sin(a),1145+32*cos(a))
}
for index in 0..<frameCount {
    let p=coastalPosition(Double(index)/Double(fps))
    precondition(hypot((p.0-535)/472,(p.1-1027)/188)<0.95 && polygonMask(p.0,p.1,islandFootprint,feather:6)<0.01,"Coastal boat must remain in open outer sea")
}
func drawCoastalBoat(_ pixels:inout[UInt8],_ time:Double) {
    let phase=tau*time/duration,p=coastalPosition(time)
    // Wake follows the actual previous curved route, clipped to sea pixels.
    for j in stride(from:18,through:1,by:-1) {
        let age=Double(j)/18,trail=coastalPosition(time-age*0.85)
        let radius=4.2+age*6.8
        for y in Int((trail.1-radius*0.3)*scale)...Int((trail.1+radius*0.3)*scale) {
            for x in Int((trail.0-radius)*scale)...Int((trail.0+radius)*scale) {
                let r=hypot((Double(x)/scale-trail.0)/radius,(Double(y)/scale-trail.1)/(radius*0.30))
                colorBlend(&pixels,x,y,[194,217,224],clamp(1-r)*(1-age)*0.13*pondMask[y*w+x])
            }
        }
    }
    // Compress naturally while turning, then mirror only near bow-on view.
    let compression=0.30+0.70*abs(cos(phase))
    let boatWidth=110.0,boatHeight=boatWidth/coastalBoat.aspect
    drawSprite(&pixels,coastalBoat,foot:(p.0,p.1+5+0.8*sin(phase*6)),height:boatHeight,
               heading:cos(phase)>=0 ? 1:-1,compression:compression,angle:0.018*sin(phase*5),sink:3)
}
func drawResidents(_ pixels:inout[UInt8],_ time:Double) {
    let phase=tau*time/duration,q=(time/4).truncatingRemainder(dividingBy:1)
    func hop(_ at:Double)->Double {
        var d=abs(q-at);d=min(d,1-d)
        return d<0.09 ? 3*pow(cos(d/0.09 * .pi/2),2):0
    }
    let hopA=hop(0.96),hopB=hop(0.46)
    let feet:[Point]=[(420,945),(465,934)]
    for foot in feet {
        for y in Int((foot.1-2)*scale)...Int((foot.1+3)*scale) {for x in Int((foot.0-7)*scale)...Int((foot.0+7)*scale) {
            let r=hypot((Double(x)/scale-foot.0)/7,(Double(y)/scale-foot.1)/2)
            colorBlend(&pixels,x,y,[78,75,77],clamp(1-r)*0.17)
        }}
    }
    drawSprite(&pixels,residents[0],foot:(667,748),height:39,angle:0.009*sin(phase*2),bridgeClip:true)
    drawSprite(&pixels,residents[1],foot:(420,945-hopA),height:24,angle:0.025*sin(q*tau))
    drawSprite(&pixels,residents[2],foot:(465,934-hopB),height:23,angle:-0.025*sin(q*tau))
    let a:Point=(427,930-hopA),b:Point=(459,919-hopB)
    let from:Point,to:Point,t:Double
    if q<0.45 {from=a;to=b;t=q/0.45}
    else if q<0.50 {from=b;to=b;t=0}
    else if q<0.95 {from=b;to=a;t=(q-0.50)/0.45}
    else {from=a;to=a;t=0}
    let ball:Point=(from.0+(to.0-from.0)*t,from.1+(to.1-from.1)*t-18*sin(.pi*t))
    for y in Int((ball.1-2.6)*scale)...Int((ball.1+2.6)*scale) {for x in Int((ball.0-2.6)*scale)...Int((ball.0+2.6)*scale) {
        let r=hypot(Double(x)/scale-ball.0,Double(y)/scale-ball.1)
        colorBlend(&pixels,x,y,[121,168,178],clamp(2.4-r))
    }}
}
func lighthouseLevel(_ time:Double)->Double {
    var level=0.68+0.04*sin(tau*time/duration*2)
    let keys:[Point]=[(0,0.68),(0.25,0.18),(0.5,0.18),(0.7,1.35),(0.85,1.35),
                      (1.02,0.22),(1.15,0.22),(1.35,1.35),(1.48,1.35),(1.9,0.68)]
    for start in [6.0,17.0] {
        let t=time-start
        if t>=0 && t<=1.9 {
            for j in 0..<(keys.count-1) where t>=keys[j].0 && t<=keys[j+1].0 {
                let a=keys[j],b=keys[j+1],u=smooth((t-a.0)/(b.0-a.0))
                level=a.1+(b.1-a.1)*u
            }
        }
    }
    return level
}
func drawFisher(_ pixels:inout[UInt8],_ time:Double) {
    let phase=tau*time/duration
    let rise=1.65*sin(phase*4)+0.4*sin(phase*7),drift=0.6*sin(phase*2)
    let angle=0.009*sin(phase*3),ca=cos(angle),sa=sin(angle)
    func boatPoint(_ p:Point)->Point {
        let dx=p.0-601,dy=p.1-922
        return (601+dx*ca-dy*sa+drift,922+dx*sa+dy*ca+rise+harborYOffset)
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
    for y in Int((875+harborYOffset)*scale)...Int((929+harborYOffset)*scale) {for x in Int(580*scale)...Int(623*scale) {
        let dx=Double(x)/scale-601-drift,dy=Double(y)/scale-922-rise-harborYOffset
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
    for y in Int((822+harborYOffset)*scale)...Int((954+harborYOffset)*scale) {for x in Int(390*scale)...Int(662*scale) {
        let p=y*w+x,px=Double(x)/scale,py=Double(y)/scale-harborYOffset
        var a=boatMask[p]
        if a>0 {
            let dx=px-601-drift,dy=py-922-rise
            let sx=(601+dx*ca+dy*sa)*scale,sy=(922-dx*sa+dy*ca+harborYOffset)*scale
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
    for (mouth,offset) in chimneys {
        // Independent smoke phase, with continuous connection to each mouth.
        for y in Int((mouth.1-80)*scale)...Int(mouth.1*scale) {for x in Int((mouth.0-17)*scale)...Int((mouth.0+37)*scale) {
            let py=Double(y)/scale,px=Double(x)/scale,age=clamp((mouth.1-py)/80)
            let center=mouth.0+12*age+2.4*age*sin(phase*2-age*9+offset)
            let width=2.0+6*age,core=exp(-pow((px-center)/width,2)*1.6)
            let travel=0.80+0.20*sin(phase*10+age*24+offset)
            colorBlend(&pixels,x,y,[211,207,198],core*(1-age)*0.45*travel)
        }}
        for j in 0..<14 {
            let age=(time/3.2+Double(j)/14+offset/10).truncatingRemainder(dividingBy:1)
            let cx=mouth.0+12*age+3*sin(age*8+phase*2+Double(j)+offset)*age
            let cy=mouth.1-age*80,radius=2.8+age*7
            let opacity=0.38*pow(sin(.pi*age),1.3)
            for y in Int((cy-radius-1)*scale)...Int((cy+radius+1)*scale) {
                for x in Int((cx-radius-1)*scale)...Int((cx+radius+1)*scale) {
                    let r=hypot((Double(x)/scale-cx)/radius,(Double(y)/scale-cy)/(radius*0.85))
                    colorBlend(&pixels,x,y,[211,207,198],smooth(1-r)*opacity)
                }
            }
        }
    }
    // Rotate the wooden wheel in its own oblique plane, with fixed wall,
    // outer supporting frame and axle. Two full turns per seamless loop.
    let wheelAngle=phase*2,cosine=cos(wheelAngle),sine=sin(wheelAngle)
    for y in Int(800*scale)...Int(875*scale) {for x in Int(832*scale)...Int(892*scale) {
        let px=Double(x)/scale,py=Double(y)/scale
        let v=(py-838)/29,u=(px-864+0.15*(py-838))/19.5
        let r=hypot(u,v)
        let mask=smooth((0.94-r)/0.09)*smooth((r-0.10)/0.10)
        guard mask>0 else{continue}
        let a=u*cosine+v*sine,b=v*cosine-u*sine
        let sx=(864+19.5*a-0.15*29*b)*scale,sy=(838+29*b)*scale,p=(y*w+x)*4
        for c in 0..<3 {pixels[p+c]=UInt8(clamp(Double(pixels[p+c])*(1-mask)+sample(clean,sx,sy,c)*mask,0,255))}
    }}
    // Occasional soft double flashes affect the lamp glass, not the tower.
    let lampLevel=lighthouseLevel(time)
    for y in Int(442*scale)...Int(466*scale) {for x in Int(378*scale)...Int(406*scale) {
        let px=Double(x)/scale,py=Double(y)/scale,p=(y*w+x)*4
        let r=hypot((px-392)/14,(py-454)/12),a=smooth((1-r)/0.15)
        let warm=clamp((Double(clean[p])-Double(clean[p+2])-15)/50)
        let mask=a*warm
        for c in 0..<3 {
            let original=Double(clean[p+c])
            let lit=original*(0.65+lampLevel*0.5)+max(0,lampLevel-0.7)*[20.0,12,2][c]
            pixels[p+c]=UInt8(clamp(Double(pixels[p+c])*(1-mask)+lit*mask,0,255))
        }
    }}
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
            let p=y*w+x
            guard windEnvelopes[j][p]>0 else{continue}
            let py=Double(y)/scale,px=Double(x)/scale
            let height=smooth((patch.rootY-py)/55)
            let branch=sin(phase*patch.frequency+patch.phase)
            let flutter=sin(phase*7+px*0.095+py*0.06+patch.phase)
            let dx:Double,dy:Double
            if j<3 {
                // Branch tips bend farther than their anchored junctions;
                // matching twigs/leaves move together, thick trunk stays put.
                let reach=smooth(abs(px-trunkXs[j])/40)
                dx=height*(9.5*reach*sin(phase*2+patch.phase)+1.2*flutter)
                dy=height*(1.6*reach*sin(phase*3+patch.phase)+0.5*flutter)
            } else {
                dx=patch.amplitude*height*(branch+0.20*flutter)
                dy=height*(0.55*sin(phase*(patch.frequency+1)+patch.phase)+0.20*flutter)
            }
            let a=max(mask[p],sampleCoverage(mask,Double(x)-dx*scale,Double(y)-dy*scale))
            guard a>0 else{continue}
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
        let startY=Int(ceil(f.start.1*scale)),endY=Int(f.end.1*scale)
        for y in startY...endY{
            let py=Double(y)/scale
            guard let row=f.at(py) else{continue}
            let arc=row.arc+flowOffsets[j]
            for x in Int(ceil(row.left*scale))...Int(row.right*scale){
                let px=Double(x)/scale,u=(px-row.left)/(row.right-row.left),p=y*w+x,i=p*4
                let boundary=smooth((px-row.left)/1.8)*smooth((row.right-px)/1.8)
                let r=Double(clean[i]),g=Double(clean[i+1]),b=Double(clean[i+2])
                let waterColor=clamp((b-r+10)/18)*clamp((b-g+8)/14)
                let mask=boundary*waterColor
                guard mask>0 else{continue}
                // Downstream-moving narrow filaments instead of a whole blue
                // band blinking. Keep the source image's real water texture.
                let travel=arc*tau/24-phase*Double(f.cycles)
                let filament=0.25+0.75*pow(max(0,cos(u*tau*4+Double(j)*0.3)),6)
                let crest=pow(max(0,cos(travel+u*17)),8)
                let secondary=pow(max(0,cos(arc*tau/37-phase*24+u*23)),10)
                let light=filament*(crest*31+secondary*14)-1.8
                let offset=0.55*sin(travel+u*12)
                let sampleX=clamp(px+offset,row.left+0.4,row.right-0.4)*scale
                for c in 0..<3 {
                    let value=sample(clean,sampleX,Double(y),c)+light*[0.78,0.91,1.0][c]
                    pixels[i+c]=UInt8(clamp(Double(pixels[i+c])*(1-mask)+value*mask,0,255))
                }
            }
        }
        let rx=j<2 ? 19.0:32.0,ry=j<2 ? 3.8:5.5
        for y in Int((f.end.1-ry)*scale)...Int((f.end.1+ry)*scale){
            for x in Int((f.end.0-rx)*scale)...Int((f.end.0+rx)*scale){
                let p=y*w+x,i=p*4
                let dx=(Double(x)/scale-f.end.0)/rx,dy=(Double(y)/scale-f.end.1)/ry
                let waterColor=clamp((Double(clean[i+2])-Double(clean[i])+10)/18)*clamp((Double(clean[i+2])-Double(clean[i+1])+8)/14)
                let foam=pow(max(0,cos(phase*32+dx*8+Double(j))),2)
                let alpha=clamp(1-dx*dx-dy*dy)*(0.08+0.16*foam)*waterColor
                colorBlend(&pixels,x,y,[216,226,235],alpha)
            }
        }
    }
    drawShoreWaves(&pixels,time)
    drawHarborDetails(&pixels,time)
    drawFisher(&pixels,time)
    drawResidents(&pixels,time)
    drawCoastalBoat(&pixels,time)
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
    let previewFrames=[0,150,175,230,400,520]
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
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-5-motion-check-v4-waves-wind.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(preview))
// Inspect several wheel angles next to the static workshop wall and channel.
let wheelSheet=CGContext(data:nil,width:324*2,height:270*3,bitsPerComponent:8,bytesPerRow:324*2*4,space:space,bitmapInfo:bitmapInfo)!
wheelSheet.interpolationQuality = .none
for (j,pixels) in snapshots.enumerated() {
    let crop=makeImage(pixels).cropping(to:CGRect(x:492,y:474,width:54,height:45))!
    wheelSheet.draw(crop,in:CGRect(x:(j%2)*324,y:(2-j/2)*270,width:324,height:270))
}
let wheelPreview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-5-wheel-check-v4-waves-wind.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(wheelPreview,wheelSheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(wheelPreview))
let report="""
White platform rank \(rank): \(w)x\(h), \(frameCount) frames, \(fps)fps, \(duration)s infinite loop.
Output: \(output.lastPathComponent); \(gif.count) bytes.
Source: \(input.lastPathComponent).
Completed miniature shell harbor: spiral village, stone footbridge, lighthouse and waterfront workshop. Workshop wheel turns twice per loop in its own oblique plane; wall/frame/axle fixed. Lighthouse lantern gently changes brightness inside its glass only.
Expanded surrounding sea within the white disk, with a coastal boat moving continuously around a closed foreground route, natural turn compression and a curved wake. Coastal vessel width increased from 65 to 110 source pixels (1.69x), with a proportionately wider wake. Path verified to remain on open water; no vessel disappearance at loop boundaries.
One adult leans on the bridge behind the foreground parapet; two small children hop and toss a ball on the cottage terrace. Isolated image-generated alpha assets, intact body poses, shared transforms and fixed ground shadows. Lamp double-flash bursts at 6s and 17s. Tree tips and dark twigs bend with leaf clusters while protected trunk pixels stay fixed.
Boat, fisher, rod, line and float share boat motion at their new position. Three chimneys emit connected, independently phased rising smoke. Tree-tip horizontal sway increased from 3.8 to 9.5 source pixels, with the inverse-warp coverage following displaced twigs/leaves; thick trunk roots, roofs and walls stay fixed. Four fish jumps include one larger 38px fish.
Coastal whitewater advances to the outer stone shore and retreats in four-second cycles, offset along the waterline. Foam breaks into small irregular segments and is clipped to sea pixels, leaving rocks, harbor and white platform unchanged.
Six traced flow ribbons cover the original upper cascade chain/outlet and the new bridge tributary/wheel outlet. Source water texture retained; filaments move downstream with integer loop frequencies, and source rock colors are rejected. Water/pier/fish positions adapted to new shore.
Three birds start/finish on grass; two fly local routes to drink and return, one circles the shell. No off-canvas entry/exit. Drinking contacts, finite flight positions, real cutout alpha and monotonic downstream flow geometry verified.
Water patch bounds: \(waterX0),\(waterY0) to \(waterX1),\(waterY1). Outer pond shoreline remains fixed inside this rank's loop.
Changed pixels within authorized water/fish/wind/bird regions: \(waterChanged.count).
Changed pixels over loop: \(changingPixels.count); outside-motion changes: \(outsideChanges).
Loop-seam mean difference: \(seam); largest adjacent-frame mean difference: \(maxDelta).
Decoded frame count and duration verified; fixed shared palette and transparent delta frames.
GIF has no audio. Shell, land and camera remain fixed.
"""
try report.write(to:folder.appendingPathComponent("rank-5-animation-report-v4-waves-wind.txt"),atomically:true,encoding:.utf8)
print(report)
print(output.path)
