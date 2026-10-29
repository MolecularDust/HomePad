// Draws the installer disk image's window background: the steps to get past the "can't be opened" block.
// render_dmg_background <out.png> <scale>   (scale 1 or 2; 660 × 720 points. The bottom 70 stay empty: a Finder with its tab bar and status bar showing has 52 less room)
// Finder draws two items on top, which make_installer_dmg.sh places (pictures: render_dmg_icons.swift): the installer
// under step 1, and the blue Open Privacy & Security tile under step 3 (both 112 points, named under them).
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let scale = Int(args[2]) else {
    print("usage: render_dmg_background <out.png> <scale>")
    exit(1)
}
let W: CGFloat = 660, H: CGFloat = 720
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W) * scale, pixelsHigh: Int(H) * scale,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)   // so the 2x image carries 144 dpi and Finder draws it at point size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
// Draw in top-left coordinates, like Finder's icon positions.
let flip = NSAffineTransform()
flip.translateX(by: 0, yBy: H)
flip.scaleX(by: 1, yBy: -1)
flip.concat()

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
}
let ink = rgb(0x1d1d1f), soft = rgb(0x5f6368), accent = rgb(0x2a6df4)

/// Text with **bold** parts, drawn in a box (flipped, so it reads the right way up).
@discardableResult
func text(_ s: String, at p: CGPoint, width: CGFloat, size: CGFloat, color: NSColor = ink,
          weight: NSFont.Weight = .regular, align: NSTextAlignment = .left) -> CGFloat {
    let para = NSMutableParagraphStyle()
    para.alignment = align
    para.lineSpacing = 2
    let out = NSMutableAttributedString()
    for (i, part) in s.components(separatedBy: "**").enumerated() {
        out.append(NSAttributedString(string: part, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: i % 2 == 1 ? .semibold : weight),
            .foregroundColor: color, .paragraphStyle: para]))
    }
    let box = out.boundingRect(with: NSSize(width: width, height: 400), options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.saveGraphicsState()
    let t = NSAffineTransform()
    t.translateX(by: p.x, yBy: p.y + ceil(box.height))
    t.scaleX(by: 1, yBy: -1)
    t.concat()
    out.draw(with: NSRect(x: 0, y: 0, width: width, height: ceil(box.height)), options: [.usesLineFragmentOrigin, .usesFontLeading])
    NSGraphicsContext.restoreGraphicsState()
    return ceil(box.height)
}

func badge(_ n: Int, at c: CGPoint) {
    accent.setFill()
    NSBezierPath(ovalIn: NSRect(x: c.x - 13, y: c.y - 13, width: 26, height: 26)).fill()
    text("\(n)", at: CGPoint(x: c.x - 13, y: c.y - 9), width: 26, size: 14, color: .white, weight: .bold, align: .center)
}

func card(_ r: NSRect) {
    let path = NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = rgb(0x000000, 0.10)
    shadow.shadowBlurRadius = 8
    shadow.shadowOffset = NSSize(width: 0, height: -2)
    shadow.set()
    NSColor.white.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    rgb(0x000000, 0.08).setStroke()
    path.lineWidth = 1
    path.stroke()
}

// Background.
NSGradient(starting: rgb(0xf7f8fb), ending: rgb(0xe8ecf3))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 90)

// Heading.
text("Install HomePad", at: CGPoint(x: 30, y: 22), width: 600, size: 24, weight: .bold)
text("HomePad isn't from the App Store, so your Mac stops the installer once. To let it through:",
     at: CGPoint(x: 30, y: 56), width: 600, size: 13, color: soft)

// One card with the steps from top to bottom. Finder draws the installer under step 1 and the blue tile under step 3
// (make_installer_dmg.sh places them at x 140, lined up with the text), each with its name under it. Finder draws an
// icon's picture 16 points below the position it is given.
card(NSRect(x: 30, y: 98, width: 600, height: 516))
func step(_ n: Int, _ s: String, y: CGFloat) {
    badge(n, at: CGPoint(x: 56, y: y + 8))
    text(s, at: CGPoint(x: 78, y: y), width: 530, size: 13)
}
step(1, "**Double-click** the installer below.", y: 116)
step(2, "A message says it can't be opened. Click **Done** (not Move to Trash).", y: 304)
step(3, "Double-click the blue button below. In the page that opens, scroll to the bottom and click **Open Anyway**.", y: 344)
step(4, "Confirm with **Open Anyway** and your password. The installer opens: click **Continue**, then **Install**.", y: 558)

// Footnote.
text("On macOS 13 or 14 it's quicker: right-click the installer, choose **Open**, then **Open** again.",
     at: CGPoint(x: 30, y: 632), width: 600, size: 12, color: soft, align: .center)

NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[1]))
