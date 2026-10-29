// Pictures for the installer disk image's items:
//   render_dmg_icons <file> <size>        the Privacy & Security shortcut's blue tile
//   render_dmg_icons <file> --from <icns>  an existing icon, e.g. the classic package box for the installer
//
// A Finder window can't hold a real button, only file icons, and Finder highlights an icon's whole square when it is
// clicked. So the button is a square blue tile filling its icon, the same size as the installer's icon: the highlight
// then hugs it like a pressed button.
import AppKit

let args = CommandLine.arguments
if args.count == 4, args[2] == "--from" {
    guard let icon = NSImage(contentsOfFile: args[3]), NSWorkspace.shared.setIcon(icon, forFile: args[1]) else {
        print("could not set the icon from \(args[3])")
        exit(1)
    }
    exit(0)
}
guard args.count == 3, let size = Double(args[2]) else {
    print("usage: render_dmg_icons <file> <size> | render_dmg_icons <file> --from <icns>")
    exit(1)
}
let S = CGFloat(size)

let tile = NSImage(size: NSSize(width: S, height: S), flipped: false) { _ in
    let r = NSRect(x: 0, y: 0, width: S, height: S).insetBy(dx: S * 0.04, dy: S * 0.04)
    NSColor(srgbRed: 0x2a / 255.0, green: 0x6d / 255.0, blue: 0xf4 / 255.0, alpha: 1).setFill()
    NSBezierPath(roundedRect: r, xRadius: S * 0.19, yRadius: S * 0.19).fill()

    let para = NSMutableParagraphStyle()
    para.alignment = .center
    para.lineSpacing = 1
    let title = NSAttributedString(string: "Open Privacy\n& Security", attributes: [
        .font: NSFont.systemFont(ofSize: S * 0.118, weight: .semibold), .foregroundColor: NSColor.white,
        .paragraphStyle: para])
    let th = title.boundingRect(with: NSSize(width: r.width, height: S), options: [.usesLineFragmentOrigin]).height

    // An open padlock above the words.
    let config = NSImage.SymbolConfiguration(pointSize: S * 0.2, weight: .semibold)
    let lock = NSImage(systemSymbolName: "lock.open.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
    let gap = S * 0.06
    let lockSize = lock?.size ?? .zero
    let total = lockSize.height + gap + th
    let top = r.midY + total / 2
    if let lock {
        let white = NSImage(size: lockSize, flipped: false) { rect in
            lock.draw(in: rect)
            NSColor.white.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        white.draw(in: NSRect(x: r.midX - lockSize.width / 2, y: top - lockSize.height, width: lockSize.width, height: lockSize.height))
    }
    title.draw(with: NSRect(x: r.minX, y: top - lockSize.height - gap - th, width: r.width, height: th), options: [.usesLineFragmentOrigin])
    return true
}

guard NSWorkspace.shared.setIcon(tile, forFile: args[1]) else {
    print("could not set the icon")
    exit(1)
}
