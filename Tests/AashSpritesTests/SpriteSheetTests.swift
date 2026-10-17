import CoreGraphics
import Testing
@testable import AashSprites

@Suite struct SpriteSheetTests {
    private func reader(_ style: SpriteStyle) throws -> PixelReader {
        let sheet = try #require(SpriteRenderer.makeSheet(style: style))
        return try #require(PixelReader(sheet.image))
    }

    private func matches(_ p: (r: UInt8, g: UInt8, b: UInt8, a: UInt8), _ hex: String) -> Bool {
        guard let c = RGBA(hex: hex) else { return false }
        return p.r == c.r && p.g == c.g && p.b == c.b && p.a == 255
    }

    @Test func lightSheetSize() throws {
        let sheet = try #require(SpriteRenderer.makeSheet(style: .light))
        #expect(sheet.image.width == 210)
        #expect(sheet.image.height == 39)
    }

    @Test func onePixelSheetSize() throws {
        let sheet = try #require(SpriteRenderer.makeSheet(style: SpriteStyle(pixelSize: 1)))
        #expect(sheet.image.width == 70)
        #expect(sheet.image.height == 13)
    }

    @Test func idleHairPixel() throws {
        let p = try reader(.light).pixel(x: 9, y: 3)
        #expect(matches(p, "#2a1b2e"), "\(p)")
    }

    @Test func cornerIsTransparent() throws {
        #expect(try reader(.light).pixel(x: 0, y: 0).a == 0)
    }

    @Test func lightMarginIsTransparent() throws {
        let r = try reader(.light)
        for x in 0..<r.width {
            #expect(r.pixel(x: x, y: 0).a == 0, "row 0 x \(x)")
            #expect(r.pixel(x: x, y: 38).a == 0, "row 38 x \(x)")
        }
    }

    @Test func darkOutlineAboveHair() throws {
        let p = try reader(.dark).pixel(x: 9, y: 0)
        #expect(p.a == 140, "\(p)")
        #expect(abs(Int(p.r) - 130) <= 2 && abs(Int(p.g) - 126) <= 2 && abs(Int(p.b) - 133) <= 2, "\(p)")
    }

    @Test func outlineDoesNotCoverArt() throws {
        let p = try reader(.dark).pixel(x: 9, y: 3)
        #expect(matches(p, "#2a1b2e"), "\(p)")
    }

    @Test func secondFrameIsBlink() throws {
        let p = try reader(.light).pixel(x: 42, y: 12)
        #expect(matches(p, "#c08f74"), "\(p)")
    }

    @Test func contentsRects() throws {
        let sheet = try #require(SpriteRenderer.makeSheet(style: .light))
        func close(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minX - b.minX) < 0.0001 && abs(a.minY - b.minY) < 0.0001
                && abs(a.width - b.width) < 0.0001 && abs(a.height - b.height) < 0.0001
        }
        #expect(close(sheet.contentsRect(for: .walk), CGRect(x: 2.0 / 7, y: 0, width: 1.0 / 7, height: 1)))
        #expect(close(sheet.contentsRectWithoutMargin(for: .idle),
                      CGRect(x: 1.0 / 70, y: 1.0 / 13, width: 8.0 / 70, height: 11.0 / 13)))
    }

    @Test func pixelSizeClamped() {
        #expect(SpriteStyle(pixelSize: 0).pixelSize == 1)
    }
}
