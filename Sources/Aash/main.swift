import AppKit

// No storyboard and no Dock icon: Info.plist sets LSUIElement, and .accessory keeps it that way.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
