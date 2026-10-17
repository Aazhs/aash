import AppKit
import AashSprites
import QuartzCore
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Status")

@MainActor
final class SpriteLayerView: NSView {
    private struct Shown: Equatable {
        var frame: SpriteFrame
        var facingLeft: Bool
        var x: CGFloat
    }

    private let spriteLayer = CALayer()
    private var sheets: [SpriteStyle: SpriteSheet] = [:]
    private var shownStyle: SpriteStyle?
    private var last: Shown?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        spriteLayer.magnificationFilter = .nearest   // crisp pixels
        spriteLayer.contentsGravity = .resize
        layer?.addSublayer(spriteLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    private var scale: CGFloat {
        window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private var isDark: Bool {
        effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    /// Width of the drawn sprite in points: 15 on Retina, 16 on a non-Retina screen.
    var spriteWidth: CGFloat { scale >= 2 ? 15 : 16 }

    /// Shows `frame` with its left edge `x` points from this view's left edge, centred vertically.
    func show(_ frame: SpriteFrame, facingLeft: Bool, x: CGFloat) {
        last = Shown(frame: frame, facingLeft: facingLeft, x: x)
        let scale = self.scale
        let style: SpriteStyle = scale >= 2 ? (isDark ? .dark : .light) : .lowResolution
        let sheet: SpriteSheet
        if let cached = sheets[style] {
            sheet = cached
        } else if let made = SpriteRenderer.makeSheet(style: style) {
            sheets[style] = made
            sheet = made
        } else {
            log.error("could not draw the sprite sheet")
            return
        }

        let size: CGSize = scale >= 2
            ? CGSize(width: CGFloat(sheet.cellPixelWidth) / scale, height: CGFloat(sheet.cellPixelHeight) / scale)
            : CGSize(width: 16, height: 22)
        let snappedX = (x * scale).rounded() / scale
        let snappedY = ((bounds.height - size.height) / 2 * scale).rounded() / scale

        CATransaction.begin()
        CATransaction.setDisableActions(true)        // no implicit 0.25 s animation
        if shownStyle != style {
            spriteLayer.contents = sheet.image
            shownStyle = style
        }
        spriteLayer.contentsRect = scale >= 2 ? sheet.contentsRect(for: frame)
                                              : sheet.contentsRectWithoutMargin(for: frame)
        // bounds + position, not frame: frame is undefined once a transform is set.
        spriteLayer.bounds = CGRect(origin: .zero, size: size)
        spriteLayer.position = CGPoint(x: snappedX + size.width / 2, y: snappedY + size.height / 2)
        spriteLayer.setAffineTransform(facingLeft ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
        CATransaction.commit()
    }

    private func reshow() {
        guard let last else { return }
        show(last.frame, facingLeft: last.facingLeft, x: last.x)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        reshow()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        reshow()
    }

    override func layout() {
        super.layout()
        reshow()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks go to the status button
}
