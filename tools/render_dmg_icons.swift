// Gives the installer disk image's two items their pictures: render_dmg_icons <button file> <installer file> <size>
//
// A Finder window can't hold a real button, only file icons, and every icon in it is drawn at one size. So the
// Privacy & Security shortcut gets a picture of a blue button (as wide as that size), and the installer gets its usual
// icon drawn smaller at the bottom of the same square, so it keeps its size and its name stays right under it.
import AppKit

let args = CommandLine.arguments
guard args.count == 4, let size = Double(args[3]) else {
    print("usage: render_dmg_icons <button file> <installer file> <size>")
    exit(1)
}
let S = CGFloat(size)

let button = NSImage(size: NSSize(width: S, height: S), flipped: false) { _ in
    let h: CGFloat = 40
    let r = NSRect(x: 1, y: (S - h) / 2, width: S - 2, height: h)
    NSColor(srgbRed: 0x2a / 255.0, green: 0x6d / 255.0, blue: 0xf4 / 255.0, alpha: 1).setFill()
    NSBezierPath(roundedRect: r, xRadius: 10, yRadius: 10).fill()
    let para = NSMutableParagraphStyle()
    para.alignment = .center
    let title = NSAttributedString(string: "Open Privacy & Security", attributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: para])
    let th = title.size().height
    title.draw(in: NSRect(x: r.minX, y: r.midY - th / 2, width: r.width, height: th))
    return true
}

// The installer's own icon (before any custom one), 112 points, at the bottom centre of the square.
let pkgIcon = NSWorkspace.shared.icon(forFile: args[2])
let art: CGFloat = 112
let installer = NSImage(size: NSSize(width: S, height: S), flipped: false) { _ in
    pkgIcon.draw(in: NSRect(x: (S - art) / 2, y: 0, width: art, height: art))
    return true
}

guard NSWorkspace.shared.setIcon(button, forFile: args[1]),
      NSWorkspace.shared.setIcon(installer, forFile: args[2]) else {
    print("could not set the icons")
    exit(1)
}
