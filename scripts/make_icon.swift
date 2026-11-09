import AppKit

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
NSColor(red: 0.97, green: 0.955, blue: 0.925, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()
NSColor(red: 0.63, green: 0.19, blue: 0.14, alpha: 1).setFill()
for row in 0..<6 {
    let y = 255 + row * 90
    if row == 1 || row == 4 {
        NSRect(x: 262, y: y, width: 210, height: 38).fill()
        NSRect(x: 552, y: y, width: 210, height: 38).fill()
    } else {
        NSRect(x: 262, y: y, width: 500, height: 38).fill()
    }
}
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try data.write(to: output)
