import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import CoreText
let folder=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let names=["rank-1-water-mist-v2.gif","rank-2-office-mist-v11.gif","rank-3-foreground-mist-v5.gif","rank-4-shrine-v6.gif"]
let w=600,h=1300,space=CGColorSpaceCreateDeviceRGB()
func raster(_ im:CGImage)->[UInt8] {
 var p=[UInt8](repeating:0,count:w*h*4)
 p.withUnsafeMutableBytes { b in
  let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.draw(im,in:CGRect(x:0,y:0,width:w,height:h))
 };return p
}
func save(_ im:CGImage,_ name:String) {
 let d=CGImageDestinationCreateWithURL(folder.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))
}
var firstImages=[CGImage](),backgrounds=[[UInt8]]()
for rank in 1...4 {
 let src=CGImageSourceCreateWithURL(folder.appendingPathComponent(names[rank-1]) as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary)!
 let count=CGImageSourceGetCount(src);precondition(count == (rank == 1 ? 240:2400))
 var duration=0.0
 for i in 0..<count {
  let props=CGImageSourceCopyPropertiesAtIndex(src,i,nil) as! [CFString:Any]
  let gp=props[kCGImagePropertyGIFDictionary] as! [CFString:Any]
  duration += gp[kCGImagePropertyGIFUnclampedDelayTime] as? Double ?? gp[kCGImagePropertyGIFDelayTime] as? Double ?? 0
 }
 precondition(abs(duration-(rank == 1 ? 12:120))<0.01)
 let first=CGImageSourceCreateImageAtIndex(src,0,nil)!;precondition(first.width==w && first.height==h)
 firstImages.append(first)
 let p=raster(first);backgrounds.append(Array(p[0..<3]))
 var motion=Set<Data>()
 let selected=rank == 1 ? [0,40,80,120,160,200,239]:[0,40,80,160,240,540,680,740,1340,2140,2399]
 for index in selected {
  autoreleasepool {
   let frame=CGImageSourceCreateImageAtIndex(src,index,nil)!,pixels=raster(frame)
   for y in stride(from:0,to:rank == 4 ? 250:750,by:40) {for x in stride(from:0,to:w,by:40) {
    let i=(y*w+x)*4
    precondition(pixels[i]==p[i] && pixels[i+1]==p[i+1] && pixels[i+2]==p[i+2],"Hidden backdrop must stay static")
    precondition(pixels[i]>215 && pixels[i+1]>215 && pixels[i+2]>215,"Unrevealed regions must be pale")
   }}
   let crop=frame.cropping(to:CGRect(x:rank==1 ? 60:465,y:rank==1 ? 1145:940,width:rank==1 ? 130:120,height:rank==1 ? 50:155))!
   motion.insert(crop.dataProvider!.data! as Data)
  }
 }
 precondition(motion.count>3,"Animation lost motion")
 if rank <= 3 {save(first,"rank-\(rank)-first-frame-mist.png")}
 print("PASS rank \(rank): \(count) frames, \(duration)s, \(motion.count) distinct motion samples; hidden field \(Array(p[0..<3]))")
}
for bg in backgrounds.prefix(3) {for c in 0..<3 {precondition(abs(Int(bg[c])-Int(backgrounds[3][c]))<=6)}}
let sw=1240,sh=690
let strip=CGContext(data:nil,width:sw,height:sh,bitsPerComponent:8,bytesPerRow:sw*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
strip.setFillColor(CGColor(red:0.96,green:0.97,blue:0.96,alpha:1));strip.fill(CGRect(x:0,y:0,width:sw,height:sh))
strip.interpolationQuality = .none
for i in 0..<4 {
 strip.draw(firstImages[i],in:CGRect(x:10+i*310,y:0,width:300,height:650))
 let text=NSAttributedString(string:"RANK \(i+1)",attributes:[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("HelveticaNeue-Medium" as CFString,15,nil),NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:0.2,alpha:1)])
 strip.textPosition=CGPoint(x:20+i*310,y:665);CTLineDraw(CTLineCreateWithAttributedString(text),strip)
}
save(strip.makeImage()!,"ranks-1-4-mist-comparison.png")
