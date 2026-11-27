import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine/rank4-v6")
func read(_ name:String)->CGImage {let s=CGImageSourceCreateWithURL(root.appendingPathComponent(name) as CFURL,nil)!;return CGImageSourceCreateImageAtIndex(s,0,nil)!}
let c=CGContext(data:nil,width:900,height:300,bitsPerComponent:8,bytesPerRow:3600,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
c.interpolationQuality = .none
let base=read("frame-without-falling-leaves.png")
let crops=[CGRect(x:316,y:791,width:100,height:100),CGRect(x:178,y:963,width:100,height:100),CGRect(x:462,y:1200,width:100,height:100)]
for (j,rect) in crops.enumerated(){let target=CGRect(x:j*300,y:0,width:300,height:300);c.draw(base.cropping(to:rect)!,in:target);c.draw(read("leaf-\(j)-landing-2.png").cropping(to:rect)!,in:target)}
let d=CGImageDestinationCreateWithURL(root.appendingPathComponent("landing-contact-check.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(d,c.makeImage()!,nil);precondition(CGImageDestinationFinalize(d))
