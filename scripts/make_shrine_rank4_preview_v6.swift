import Foundation
import CoreGraphics
import ImageIO
let root=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/shrine")
let input=root.appendingPathComponent("rank-4-shrine-v6.gif")
let output=root.appendingPathComponent("rank-4-preview-small-v6.gif")
let source=CGImageSourceCreateWithURL(input as CFURL,nil)!
let original=[UInt8](try Data(contentsOf:input))
precondition(original[10]&0x80 != 0)
let table=Array(original[13..<781])
var palette=[[Int]](),exact=[Int:UInt8]()
for j in 0..<255 {
 let r=Int(table[j*3]),g=Int(table[j*3+1]),b=Int(table[j*3+2])
 palette.append([r,g,b]);exact[(r<<16)|(g<<8)|b]=UInt8(j)
}
var cache=[Int:UInt8]()
func paletteIndex(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
 let key=(Int(r)<<16)|(Int(g)<<8)|Int(b)
 if let n=exact[key] {return n}
 if let n=cache[key] {return n}
 var best=0,distance=Int.max
 for j in 0..<255 {
  let dr=palette[j][0]-Int(r),dg=palette[j][1]-Int(g),db=palette[j][2]-Int(b)
  let d=dr*dr*2+dg*dg*3+db*db*2
  if d<distance {distance=d;best=j}
 }
 cache[key]=UInt8(best);return UInt8(best)
}
func lzw(_ bytes:[UInt8])->[UInt8] {
 var encoded=[UInt8](),accumulator=0,bitCount=0
 func emit(_ code:Int){accumulator |= code<<bitCount;bitCount+=9;while bitCount>=8 {encoded.append(UInt8(accumulator&255));accumulator >>= 8;bitCount-=8}}
 var table=[Int:Int](),next=258,prefix=Int(bytes[0]);emit(256)
 for value in bytes.dropFirst() {
  let b=Int(value),key=(prefix<<8)|b
  if let code=table[key] {prefix=code}
  else {emit(prefix);table[key]=next;next+=1;prefix=b;if next>=500 {emit(256);table.removeAll(keepingCapacity:true);next=258}}
 }
 emit(prefix);emit(257);if bitCount>0 {encoded.append(UInt8(accumulator&255))};return encoded
}
let w=360,h=780,frames=120
var gif=Data("GIF89a".utf8)
func byte(_ n:Int){gif.append(UInt8(n))}
func word(_ n:Int){byte(n&255);byte((n>>8)&255)}
word(w);word(h);byte(0xF7);byte(0);byte(0);gif.append(contentsOf:table)
gif.append(contentsOf:[0x21,0xFF,0x0B]);gif.append(Data("NETSCAPE2.0".utf8));gif.append(contentsOf:[3,1,0,0,0])
var previous=[UInt8](repeating:255,count:w*h)
for frame in 0..<frames {
 autoreleasepool {
  let image=CGImageSourceCreateImageAtIndex(source,frame*2,nil)!
  var pixels=[UInt8](repeating:0,count:w*h*4)
  pixels.withUnsafeMutableBytes {buffer in
   let c=CGContext(data:buffer.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
   c.interpolationQuality = .none;c.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
  }
  let top=frame==0 ? 0:180,height=h-top
  var indices=[UInt8]();indices.reserveCapacity(w*height)
  for y in top..<h {for x in 0..<w {
   let p=y*w+x,i=p*4,color=paletteIndex(pixels[i],pixels[i+1],pixels[i+2])
   indices.append(frame>0 && color==previous[p] ? 255:color);previous[p]=color
  }}
  gif.append(contentsOf:[0x21,0xF9,4,frame==0 ? 4:5,10,0,255,0,0x2C]);word(0);word(top);word(w);word(height);byte(0);byte(8)
  let data=lzw(indices)
  for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 }
}
byte(0x3B);try gif.write(to:output)
print("Saved \(output.path): \(gif.count)bytes, \(w)x\(h),12seconds,10fps")
