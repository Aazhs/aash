import AppKit
import ApplicationServices

// 1) Our own status item: can we read its on-screen frame?
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let item = NSStatusBar.system.statusItem(withLength: 22)
item.button?.title = "◦"
RunLoop.main.run(until: Date().addingTimeInterval(1.0))
if let w = item.button?.window {
    print("own status item window frame:", w.frame, "· number:", w.windowNumber, "· level:", w.level.rawValue)
} else {
    print("own status item: no window")
}

// 2) Accessibility: trusted? If so, read the frontmost app's menus and every app's status items.
let trusted = AXIsProcessTrusted()
print("AXIsProcessTrusted:", trusted)
func frame(_ el: AXUIElement) -> CGRect? {
    var p: CFTypeRef?, s: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success,
          AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success else { return nil }
    var pt = CGPoint.zero, sz = CGSize.zero
    AXValueGetValue(p as! AXValue, .cgPoint, &pt); AXValueGetValue(s as! AXValue, .cgSize, &sz)
    return CGRect(origin: pt, size: sz)
}
func children(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
    var v: CFTypeRef?
    guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success else { return [] }
    if let bar = v, CFGetTypeID(bar) == AXUIElementGetTypeID() {
        var kids: CFTypeRef?
        guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &kids) == .success else { return [] }
        return kids as? [AXUIElement] ?? []
    }
    return []
}
if trusted {
    if let front = NSWorkspace.shared.frontmostApplication {
        let menus = children(AXUIElementCreateApplication(front.processIdentifier), kAXMenuBarAttribute as String)
        let frames = menus.compactMap(frame)
        print("frontmost \(front.localizedName ?? "?"): \(frames.count) menus, rightmost maxX =", frames.map(\.maxX).max() ?? -1)
    }
    var extras: [(String, CGRect)] = []
    for running in NSWorkspace.shared.runningApplications {
        for el in children(AXUIElementCreateApplication(running.processIdentifier), "AXExtrasMenuBar") {
            if let f = frame(el) { extras.append((running.localizedName ?? "?", f)) }
        }
    }
    print("status items via AXExtrasMenuBar: \(extras.count)")
    for (name, f) in extras.sorted(by: { $0.1.minX < $1.1.minX }).prefix(25) { print("  \(name): x=\(f.minX) w=\(f.width) y=\(f.minY) h=\(f.height)") }
}
