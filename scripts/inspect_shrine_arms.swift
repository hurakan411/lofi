import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let v3=CommandLine.arguments.contains("--v3")
let w=600,h=1300,side=8,crop=CGRect(x:480,y:975,width:80,height:60)
let colorSpace=CGColorSpaceCreateDeviceRGB(),info=CGImageAlphaInfo.premultipliedLast.rawValue
let sheet=CGContext(data:nil,width:1280,height:960,bitsPerComponent:8,bytesPerRow:1280*4,space:colorSpace,bitmapInfo:info)!
sheet.interpolationQuality = .none
let names=v3 ? ["rank-2-base.png","rank-2-put-brush-compact-v3.png","rank-2-take-stamp-compact-v3.png","rank-2-stamp-raised.png"] : ["rank-2-base.png","rank-2-clean-plate-v2.png","rank-2-stamp-raised.png","rank-2-stamp-pressed.png"]
for (j,name) in names.enumerated() {
 let s=CGImageSourceCreateWithURL(folder.appendingPathComponent(name) as CFURL,nil)!,im=CGImageSourceCreateImageAtIndex(s,0,nil)!
 let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:colorSpace,bitmapInfo:info)!
 c.interpolationQuality = .high;c.draw(im,in:CGRect(x:0,y:0,width:w,height:h))
 let piece=c.makeImage()!.cropping(to:crop)!
 sheet.draw(piece,in:CGRect(x:(j%2)*640,y:(1-j/2)*480,width:640,height:480))
}
let output=folder.appendingPathComponent(v3 ? "rank-2-arm-sequence-check-v3.png":"rank-2-arm-reference-check.png")
let d=CGImageDestinationCreateWithURL(output as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(d,sheet.makeImage()!,nil);precondition(CGImageDestinationFinalize(d))
