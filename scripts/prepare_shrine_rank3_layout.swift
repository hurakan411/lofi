import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine/")
let src=CGImageSourceCreateWithURL(root.appendingPathComponent("rank3-v1/base-generated.png") as CFURL,nil)!
let im=CGImageSourceCreateImageAtIndex(src,0,nil)!
let c=CGContext(data:nil,width:600,height:1300,bitsPerComponent:8,bytesPerRow:2400,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
c.setFillColor(CGColor(red:0.025,green:0.031,blue:0.04,alpha:1));c.fill(CGRect(x:0,y:0,width:600,height:1300));c.interpolationQuality = .high
let scale=600.0/Double(im.width)
c.draw(im,in:CGRect(x:0,y:0,width:600,height:Double(im.height)*scale))
let final=c.makeImage()!
func save(_ im:CGImage,_ name:String){let d=CGImageDestinationCreateWithURL(root.appendingPathComponent(name) as CFURL,UTType.png.identifier as CFString,1,nil)!;CGImageDestinationAddImage(d,im,nil);precondition(CGImageDestinationFinalize(d))}
save(final,"rank3-v1/base-framed.png")
save(final.cropping(to:CGRect(x:0,y:970,width:600,height:330))!,"rank3-v1/foreground-reference.png")
