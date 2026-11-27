import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let cs=CGColorSpaceCreateDeviceRGB()
let source=CGImageSourceCreateWithURL(root.appendingPathComponent("rank-5-redrawn-v16.png") as CFURL,nil)!
let im=CGImageSourceCreateImageAtIndex(source,0,nil)!
let ctx=CGContext(data:nil,width:600,height:1300,bitsPerComponent:8,bytesPerRow:2400,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.interpolationQuality = .high;ctx.draw(im,in:CGRect(x:0,y:0,width:600,height:1300))
let scaled=ctx.makeImage()!
func save(_ image:CGImage,_ name:String){let d=CGImageDestinationCreateWithURL(root.appendingPathComponent("rank4-v5/"+name) as CFURL,UTType.png.identifier as CFString,1,nil)!;CGImageDestinationAddImage(d,image,nil);precondition(CGImageDestinationFinalize(d))}
// Identical square cells preserve each close-up's scale and registration.
let regions=[CGRect(x:122,y:510,width:160,height:160),CGRect(x:140,y:765,width:160,height:160)]
let atlas=CGContext(data:nil,width:1280,height:640,bitsPerComponent:8,bytesPerRow:5120,space:cs,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
atlas.interpolationQuality = .none
for (j,r) in regions.enumerated(){let c=scaled.cropping(to:r)!;save(c,j==0 ? "hall-original.png":"torii-original.png");atlas.draw(c,in:CGRect(x:j*640,y:0,width:640,height:640))}
save(atlas.makeImage()!,"entrances-original-atlas.png")
print("Entrance atlas prepared")
