import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let s=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-5-redrawn-v16.png") as CFURL,nil)!
let image=CGImageSourceCreateImageAtIndex(s,0,nil)!
let cs=CGColorSpaceCreateDeviceRGB(),bi=CGImageAlphaInfo.premultipliedLast.rawValue
let c=CGContext(data:nil,width:600,height:1300,bitsPerComponent:8,bytesPerRow:2400,space:cs,bitmapInfo:bi)!
c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:600,height:1300))
let scaled=c.makeImage()!
let atlas=CGContext(data:nil,width:1280,height:1280,bitsPerComponent:8,bytesPerRow:5120,space:cs,bitmapInfo:bi)!
atlas.interpolationQuality = .none
let crops=[CGRect(x:0,y:242,width:160,height:160),CGRect(x:440,y:335,width:160,height:160),CGRect(x:385,y:480,width:160,height:160),CGRect(x:45,y:95,width:160,height:160)]
for (j,r) in crops.enumerated(){atlas.draw(scaled.cropping(to:r)!,in:CGRect(x:j%2*640,y:(1-j/2)*640,width:640,height:640))}
let d=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank5-v1/upper-original-atlas.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(d,atlas.makeImage()!,nil);precondition(CGImageDestinationFinalize(d))
