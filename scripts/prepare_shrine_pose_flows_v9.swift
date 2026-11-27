import Foundation
import Vision
import CoreGraphics
import ImageIO
import CoreVideo
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine/v9")
let pairs=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("flow-pairs.json"))) as! [String]
let dest=root.appendingPathComponent("flows-v2")
try FileManager.default.createDirectory(at:dest,withIntermediateDirectories:true)
func image(_ id:String)->CGImage {
 let source=CGImageSourceCreateWithURL(root.appendingPathComponent("cels/\(id).png") as CFURL,nil)!
 return CGImageSourceCreateImageAtIndex(source,0,nil)!
}
for (i,pair) in pairs.enumerated() {
 let target=dest.appendingPathComponent(pair+".bin")
 if FileManager.default.fileExists(atPath:target.path) {continue}
 try autoreleasepool {
  let parts=pair.split(separator:"-").map(String.init)
  let request=VNGenerateOpticalFlowRequest(targetedCGImage:image(parts[1]))
  request.revision=VNGenerateOpticalFlowRequestRevision1
  request.computationAccuracy = .high
  request.outputPixelFormat=kCVPixelFormatType_TwoComponent32Float
  try VNImageRequestHandler(cgImage:image(parts[0])).perform([request])
  let b=request.results!.first!.pixelBuffer
  CVPixelBufferLockBaseAddress(b,.readOnly)
  defer {CVPixelBufferUnlockBaseAddress(b,.readOnly)}
  let w=CVPixelBufferGetWidth(b),h=CVPixelBufferGetHeight(b),stride=CVPixelBufferGetBytesPerRow(b)/4
  precondition(w==256 && h==320)
  let source=CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to:Float.self)
  var p=[Float](repeating:0,count:w*h*2)
  for y in 0..<h {for x in 0..<w*2 {p[y*w*2+x]=source[y*stride+x]}}
  try p.withUnsafeBytes{Data($0)}.write(to:target)
 }
 print("flow \(i+1)/\(pairs.count) \(pair)")
}
