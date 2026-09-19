// make-icon.swift <out.png> [hex color]  —  用法：swift scripts/hex/make-icon.swift resources/hex/icon-1024.png
// Craft 风格底板（白→浅灰渐变圆角方块 + 软阴影）+ 像素网格 "HEX" 字样，对应 Craft 的几何 "C"。
import AppKit
let args = CommandLine.arguments
let out = args[1]
let hex = args.count > 2 ? args[2] : "6B87A6"   // 雨果灰蓝
func color(_ h: String) -> NSColor {
  var v: UInt64 = 0; Scanner(string: h).scanHexInt64(&v)
  return NSColor(srgbRed: CGFloat((v >> 16) & 0xff)/255, green: CGFloat((v >> 8) & 0xff)/255, blue: CGFloat(v & 0xff)/255, alpha: 1)
}
let size = 1024.0, inner = 832.0, radius = inner * 0.2237
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
ctx.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
let tile = NSRect(x: (size - inner)/2, y: (size - inner)/2, width: inner, height: inner)
let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
// shadow + tile gradient (Craft: white top → #ECECEE bottom)
ctx.cgContext.saveGState()
ctx.cgContext.setShadow(offset: CGSize(width: 0, height: -10), blur: 36, color: NSColor.black.withAlphaComponent(0.25).cgColor)
NSColor.white.setFill(); path.fill()
ctx.cgContext.restoreGState()
NSGradient(starting: NSColor.white, ending: color("EBEBED"))!.draw(in: path, angle: -90)
// subtle 1px inner edge like Craft
NSColor.black.withAlphaComponent(0.06).setStroke(); path.lineWidth = 2; path.stroke()
// pixel-grid wordmark: 5 rows, letters 3 cols, 1 col gap
let glyphs: [[String]] = [
  ["11011","11011","11011","11111","11011","11011","11011"],   // H
  ["11111","11000","11000","11110","11000","11000","11111"],   // E
  ["11011","11011","01110","00100","01110","11011","11011"],   // X
]
let cols = 3*5 + 2, rows = 7
let cell = floor(inner * 0.78 / Double(cols))          // ≈ 38
let gridW = cell * Double(cols), gridH = cell * Double(rows)
let ox = tile.midX - gridW/2, oy = tile.midY - gridH/2
color(hex).setFill()
var x0 = ox
for g in glyphs {
  for (r, row) in g.enumerated() {
    for (c, ch) in row.enumerated() where ch == "1" {
      let y = oy + Double(rows - 1 - r) * cell
      // +0.5 overlap hides antialias seams between adjacent cells
      NSRect(x: x0 + Double(c)*cell - 0.5, y: y - 0.5, width: cell + 1, height: cell + 1).fill()
    }
  }
  x0 += 6 * cell
}
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
