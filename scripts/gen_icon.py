import os
import subprocess
import tempfile

sizes = [16, 32, 64, 128, 256, 512, 1024]
out_dir = "/Users/huhyoujung/dev/leavenow/macos/Runner/Assets.xcassets/AppIcon.appiconset"

def make_icon(size):
    script = f"""
import AppKit
import CoreGraphics

let size = {size}
let outPath = "{out_dir}/app_icon_{size}.png"

// CGBitmapContext로 직접 렌더링
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(
    data: nil,
    width: size, height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
NSGraphicsContext.current = nsCtx

// 배경 (연한 파랑 rounded rect)
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let radius = CGFloat(size) * 0.22
NSColor(red: 0.91, green: 0.957, blue: 0.992, alpha: 1.0).setFill()
NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

// 이모지
let fontSize = CGFloat(size) * 0.62
let font = NSFont.systemFont(ofSize: fontSize)
let str = NSAttributedString(string: "🚌", attributes: [.font: font])
let strSize = str.size()
let x = (CGFloat(size) - strSize.width) / 2
let y = (CGFloat(size) - strSize.height) / 2
str.draw(at: NSPoint(x: x, y: y))

// PNG 저장
let cgImage = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: cgImage)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: outPath))
print("saved {size}")
"""
    with tempfile.NamedTemporaryFile(suffix=".swift", mode="w", delete=False) as f:
        f.write(script)
        fname = f.name
    result = subprocess.run(["swift", fname], capture_output=True, text=True)
    os.unlink(fname)
    if result.returncode != 0:
        print(f"ERROR {size}: {result.stderr.splitlines()[0]}")
    else:
        print(result.stdout.strip())

for size in sizes:
    make_icon(size)

print("done")
