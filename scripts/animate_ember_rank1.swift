import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let folder = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("output/concepts/ember-workshop/stages-v1")
let w=512,h=768,fps=25,n=250
let tau=Double.pi*2
let space=CGColorSpaceCreateDeviceRGB()
let info=CGImageAlphaInfo.premultipliedLast.rawValue
let src=CGImageSourceCreateWithURL(folder.appendingPathComponent("rank-1.png") as CFURL,nil)!
let original=CGImageSourceCreateImageAtIndex(src,0,nil)!
var base=[UInt8](repeating:0,count:w*h*4)
base.withUnsafeMutableBytes{b in
 let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:info)!
 c.interpolationQuality = .high
 c.draw(original,in:CGRect(x:0,y:0,width:w,height:h))
}
func clamp(_ x:Double)->Double { min(1,max(0,x)) }
func blend(_ p:inout [UInt8],_ x:Int,_ y:Int,_ color:[Double],_ a:Double){
 if x<0 || y<0 || x>=w || y>=h {return}
 let i=(y*w+x)*4,alpha=clamp(a)
 for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(p[i+c])*(1-alpha)+color[c]*alpha)))}
}
func image(_ p:[UInt8])->CGImage{
 CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:space,bitmapInfo:CGBitmapInfo(rawValue:info),provider:CGDataProvider(data:Data(p) as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
}
// Clear the painted smoke in the empty black space. In the platform area,
// replace the thin old plume from adjacent stone texture with a feathered mask.
var clean=base
for y in 235..<388 {for x in 246..<299{
 let height=Double(y)
 let center=270+10*sin((height-245)*0.045)
 let mask=clamp((15-abs(Double(x)-center))/7)
 if mask>0{
  let i=(y*w+x)*4
  for c in 0..<3{
   let replacement=y<309 ? 0.0 : Double(base[(y*w+x-25)*4+c])
   clean[i+c]=UInt8(Double(base[i+c])*(1-mask)+replacement*mask)
  }
 }
}}
// A small fixed palette eliminates frame-to-frame dithering on the stone.
struct ColorBin { let r:Int; let g:Int; let b:Int; let count:Int }
var histogram: [Int:Int] = [:]
for y in stride(from:0,to:h,by:2) { for x in stride(from:0,to:w,by:2) {
    let i=(y*w+x)*4
    let key=(Int(base[i])>>3)<<10 | (Int(base[i+1])>>3)<<5 | (Int(base[i+2])>>3)
    histogram[key,default:0] += 1
}}
var boxes=[histogram.map { key,count in ColorBin(r:((key>>10)&31)*8+4,g:((key>>5)&31)*8+4,b:(key&31)*8+4,count:count) }]
func spread(_ box:[ColorBin]) -> (Int,Int) {
    let ranges=[box.map(\.r).max()!-box.map(\.r).min()!,box.map(\.g).max()!-box.map(\.g).min()!,box.map(\.b).max()!-box.map(\.b).min()!]
    let axis=ranges.enumerated().max(by:{$0.element<$1.element})!.offset
    return (axis,ranges[axis])
}
while boxes.count<255 {
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
var palette:[[Int]]=[[0,0,0]]+boxes.map {box in
    let total=box.reduce(0){$0+$1.count}
    return [box.reduce(0){$0+$1.r*$1.count}/total,box.reduce(0){$0+$1.g*$1.count}/total,box.reduce(0){$0+$1.b*$1.count}/total]
}
while palette.count<256 {palette.append(palette.last!)}
var colorCache=[Int](repeating:-1,count:32768)
func idx(_ r:UInt8,_ g:UInt8,_ b:UInt8)->UInt8 {
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
func frame(_ f:Int)->[UInt8]{
 let t=Double(f)/Double(fps),phase=tau*t/10
 var p=clean
 let pulse=0.52+0.26*sin(phase*4)+0.14*sin(phase*9+1.1)+0.08*sin(phase*17+0.4)
 // Large ember brightness variation, plus reflected amber light across ash.
 for y in 367..<476 {for x in 174..<344{
  let i=(y*w+x)*4,r=Double(clean[i]),g=Double(clean[i+1]),b=Double(clean[i+2])
  let ground=exp(-pow((Double(x)-254)/57,2)-pow((Double(y)-433)/22,2))
  let hot=clamp((r-g*1.5-12)/65)*clamp((Double(y)-390)/15)*clamp((446-Double(y))/8)
  let local=0.85+0.15*sin(Double(x)*0.24+Double(y)*0.16+phase*13)
  let delta=(pulse-0.4)*local
  let added=[105.0,31.0,4.0]
  let light=[23.0,10.0,2.0]
  for c in 0..<3{p[i+c]=UInt8(min(255,max(0,Double(clean[i+c])+hot*delta*added[c]+ground*delta*light[c])))}
  _=b
 }}
 // Wispy continuous smoke: packets rise, broaden, sway and fade smoothly.
 for k in 0..<9{
  let u=(t/5.0+Double(k)/9).truncatingRemainder(dividingBy:1)
  let yy=391-u*153
  let xx=260+sin(u*9-phase*2+Double(k)*0.5)*(7+u*26)
  let rx=4+u*14,ry=8+u*17
  let a=pow(sin(Double.pi*u),1.5)*0.32
  for y in max(0,Int(yy-ry*2))...min(h-1,Int(yy+ry*2)){
   for x in max(0,Int(xx-rx*2))...min(w-1,Int(xx+rx*2)){
    let dx=(Double(x)-xx)/rx,dy=(Double(y)-yy)/ry
    let alpha=exp(-2*(dx*dx+dy*dy))*a
    blend(&p,x,y,[115,111,128],alpha)
   }
  }
 }
 // Clearly visible ember motes: periodic flights from the coal to a soft fade.
 for k in 0..<19 {
  let cycle=2.5
  let u=(t/cycle+Double(k)*0.61803398875).truncatingRemainder(dividingBy:1)
  let seed=Double(k)
  let x=254+sin(seed*7.3)*22+sin(seed*3.1+u*5)*(8+u*17)
  let y=418-u*(48+38*(0.5+0.5*sin(seed*5.1)))
  let a=pow(sin(Double.pi*u),0.6)*(0.7+0.3*sin(seed+u*20))
  let radius=k%4==0 ? 1.7:1.0
  for yy in Int(y-3)...Int(y+3){for xx in Int(x-3)...Int(x+3){
   let d=hypot(Double(xx)-x,(Double(yy)-y)*0.7)
   blend(&p,xx,yy,[255,116+45*u,31],a*clamp((radius+0.7-d)/1.0))
  }}
 }
 return p
}
func lzw(_ bytes:[UInt8])->[UInt8]{
 var out:[UInt8]=[],acc=0,bits=0
 func emit(_ c:Int){acc |= c<<bits;bits += 9;while bits>=8{out.append(UInt8(acc&255));acc >>= 8;bits -= 8}}
 var table:[Int:Int]=[:],next=258,prefix=Int(bytes[0]);emit(256)
 for v in bytes.dropFirst(){let b=Int(v),key=(prefix<<8)|b
  if let code=table[key]{prefix=code}else{emit(prefix);table[key]=next;next += 1;prefix=b;if next>=500{emit(256);table.removeAll(keepingCapacity:true);next=258}}
 }
 emit(prefix);emit(257);if bits>0{out.append(UInt8(acc&255))};return out
}
var gif=Data("GIF89a".utf8)
func byte(_ x:Int){gif.append(UInt8(x))}
func word(_ x:Int){byte(x&255);byte((x>>8)&255)}
word(w);word(h);byte(0xF7);byte(0);byte(0)
for color in palette {for c in color {byte(c)}}
gif.append(contentsOf:[0x21,0xFF,11]);gif.append(Data("NETSCAPE2.0".utf8));gif.append(contentsOf:[3,1,0,0,0])
var previous=[UInt8](repeating:0,count:w*h)
for f in 0..<n{
 let p=frame(f)
 let left=f==0 ? 0:170,top=f==0 ? 0:225,width=f==0 ? w:180,height=f==0 ? h:255
 var indices:[UInt8]=[]
 for y in top..<(top+height){for x in left..<(left+width){let k=y*w+x,i=k*4,v=idx(p[i],p[i+1],p[i+2]);indices.append(f>0 && previous[k]==v ? 0:v);previous[k]=v}}
 // Transparency uses index 0 only on delta frames; black is opaque on first.
 gif.append(contentsOf:[0x21,0xF9,4,UInt8(f==0 ? 4:5),4,0,0,0,0x2C]);word(left);word(top);word(width);word(height);byte(0);byte(8)
 let data=lzw(indices)
 for start in stride(from:0,to:data.count,by:255){let end=min(start+255,data.count);byte(end-start);gif.append(contentsOf:data[start..<end])};byte(0)
 if f%50==0{print("Rendered \(f)/\(n)")}
}
byte(0x3B)
let out=folder.appendingPathComponent("rank-1-animation-v1.gif")
try gif.write(to:out)
let check=CGImageSourceCreateWithURL(out as CFURL,nil)!
precondition(CGImageSourceGetCount(check)==n)
let preview=CGImageDestinationCreateWithURL(folder.appendingPathComponent("rank-1-animation-check.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(preview,image(frame(35)),nil);precondition(CGImageDestinationFinalize(preview))
print("Verified: \(w)x\(h), \(n) frames, 25fps, 10 seconds, infinite loop. \(gif.count) bytes")
print(out.path)
