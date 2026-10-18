import AppKit
import ApplicationServices

/// One thing found on the menu bar, in AppKit screen coordinates (origin bottom-left).
struct MenuBarElement: Equatable {
    let owner: String
    let frame: CGRect
}

/// What an Accessibility scan of the menu bar found.
struct MenuBarScan: Equatable {
    var trusted: Bool
    /// The frontmost app's top-level menus, left to right.
    var appMenus: [MenuBarElement]
    /// Status items from each running app's "AXExtrasMenuBar" attribute.
    var extras: [MenuBarElement]
    /// Children of the MenuBarAgent process's elements, if it exposes any.
    var agentItems: [MenuBarElement]
}

/// Reads the menu bar through the Accessibility API. Needs the user's permission.
@MainActor
enum MenuBarScanner {
    /// Whether Aash has Accessibility permission.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that sends the user to System Settings to allow Aash.
    static func requestTrust() {
        let key = "AXTrustedCheckOptionPrompt"   // the SDK constant is a mutable global, which Swift 6 rejects
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Scans now. Returns an empty scan with `trusted == false` without permission.
    static func scan() -> MenuBarScan {
        guard isTrusted else {
            return MenuBarScan(trusted: false, appMenus: [], extras: [], agentItems: [])
        }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        var appMenus: [MenuBarElement] = []
        if let front = NSWorkspace.shared.frontmostApplication {
            let owner = front.localizedName ?? "?"
            let root = appElement(front.processIdentifier)
            for el in barChildren(root, kAXMenuBarAttribute as String) {
                if let f = frame(el, primaryHeight) { appMenus.append(MenuBarElement(owner: owner, frame: f)) }
            }
        }
        var extras: [MenuBarElement] = []
        var agentItems: [MenuBarElement] = []
        for running in NSWorkspace.shared.runningApplications {
            let owner = running.localizedName ?? running.bundleIdentifier ?? "?"
            let root = appElement(running.processIdentifier)
            for el in barChildren(root, "AXExtrasMenuBar") {
                if let f = frame(el, primaryHeight) { extras.append(MenuBarElement(owner: owner, frame: f)) }
            }
            let ident = (running.bundleIdentifier ?? "") + " " + (running.localizedName ?? "")
            if ident.contains("MenuBarAgent") {
                let top = children(root)
                for el in top + top.flatMap(children) {
                    guard let f = frame(el, primaryHeight), f.maxY > primaryHeight - 40 else { continue }
                    agentItems.append(MenuBarElement(owner: owner, frame: f))
                }
            }
        }
        return MenuBarScan(trusted: true, appMenus: appMenus, extras: extras, agentItems: agentItems)
    }

    /// A plain-text report of a scan plus screen and status item geometry.
    static func report(_ scan: MenuBarScan, ownItem: CGRect?) -> String {
        var lines = [
            "date: \(Date().formatted(.iso8601))",
            "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)",
            "trusted: \(scan.trusted)",
        ]
        for (i, screen) in NSScreen.screens.enumerated() {
            lines.append("screen \(i): frame \(screen.frame) visibleFrame \(screen.visibleFrame)")
        }
        lines.append("own item: \(ownItem.map { "\($0)" } ?? "none")")
        for (title, list) in [("appMenus", scan.appMenus), ("extras", scan.extras), ("agentItems", scan.agentItems)] {
            lines.append("\(title):")
            for e in list.sorted(by: { $0.frame.minX < $1.frame.minX }) {
                lines.append("  \(e.owner) · \(Int(e.frame.minX)) … \(Int(e.frame.maxX))")
            }
        }
        lines.append("counts: appMenus \(scan.appMenus.count), extras \(scan.extras.count), agentItems \(scan.agentItems.count)")
        return lines.joined(separator: "\n")
    }

    private static func appElement(_ pid: pid_t) -> AXUIElement {
        let el = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(el, 0.25)   // a hung app must not freeze the scan
        return el
    }

    /// Frame converted from Accessibility's top-left origin to AppKit's bottom-left.
    private static func frame(_ el: AXUIElement, _ primaryHeight: CGFloat) -> CGRect? {
        var p: CFTypeRef?, s: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &s) == .success,
              let p, let s, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID()
        else { return nil }
        var pt = CGPoint.zero, sz = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &pt),
              AXValueGetValue(s as! AXValue, .cgSize, &sz) else { return nil }
        return CGRect(x: pt.x, y: primaryHeight - pt.y - sz.height, width: sz.width, height: sz.height)
    }

    private static func children(_ el: AXUIElement) -> [AXUIElement] {
        var kids: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, kAXChildrenAttribute as CFString, &kids) == .success else { return [] }
        return kids as? [AXUIElement] ?? []
    }

    /// Children of the element that an attribute (such as the menu bar) points to.
    private static func barChildren(_ el: AXUIElement, _ attr: String) -> [AXUIElement] {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &v) == .success,
              let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return [] }
        return children(v as! AXUIElement)
    }
}
