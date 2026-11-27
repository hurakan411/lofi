import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let source=CGImageSourceCreateWithURL(root.appendingPathComponent("rank-5-first-frame-v1.png") as CFURL,nil)!
let image=CGImageSourceCreateImageAtIndex(source,0,nil)!
let crops:[(String,CGRect)]=[("upper",CGRect(x:180,y:90,width:355,height:230)),("middle",CGRect(x:190,y:240,width:335,height:270))]
for (name,rect) in crops {
 let crop=image.cropping(to:rect)!
 let c=CGContext(data:nil,width:crop.width*3,height:crop.height*3,bitsPerComponent:8,bytesPerRow:crop.width*12,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
 c.interpolationQuality = .none;c.draw(crop,in:CGRect(x:0,y:0,width:crop.width*3,height:crop.height*3))
 let dest=CGImageDestinationCreateWithURL(root.appendingPathComponent("rank5-v2/\(name)-walkway-inspection.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(dest,c.makeImage()!,nil);precondition(CGImageDestinationFinalize(dest))
}
