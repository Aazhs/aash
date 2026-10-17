import Testing
@testable import AashSprites

@Suite struct SpriteArtTests {
    @Test func everyFrameIs8By11() {
        for frame in SpriteFrame.allCases {
            let rows = SpriteArt.rows(for: frame)
            #expect(rows.count == 11, "\(frame)")
            for row in rows {
                #expect(row.count == 8, "\(frame): \(row)")
            }
        }
    }

    @Test func gridsUseOnlyPaletteCharacters() {
        for frame in SpriteFrame.allCases {
            for row in SpriteArt.rows(for: frame) {
                for character in row {
                    #expect(character == "." || SpriteArt.palette[character] != nil, "\(frame): \(character)")
                }
            }
        }
    }

    @Test func paletteMatchesDocs() {
        #expect(SpriteArt.palette["1"] == RGBA(hex: "#2a1b2e"))
        #expect(SpriteArt.palette["2"] == RGBA(hex: "#f2c9a8"))
        #expect(SpriteArt.palette["3"] == RGBA(hex: "#8fd3c9"))
        #expect(SpriteArt.palette["4"] == RGBA(hex: "#3f2740"))
        #expect(SpriteArt.palette["5"] == RGBA(hex: "#1b1120"))
        #expect(SpriteArt.palette["6"] == RGBA(hex: "#2a1b2e"))
        #expect(SpriteArt.palette["7"] == RGBA(hex: "#c08f74"))
    }

    @Test func websiteFramesAreExact() {
        #expect(SpriteArt.rows(for: .idle) == [
            "..1111..", ".111111.", ".122221.", ".126262.", "..2222..", ".333333.",
            "33333333", "2.3333.2", "..4444..", "..4..4..", "..5..5..",
        ])
        #expect(SpriteArt.rows(for: .walk) == [
            "..1111..", ".111111.", ".122221.", ".126262.", "..2222..", ".333333.",
            "33333333", "2.3333.2", "..4444..", ".4....4.", ".5....5.",
        ])
        #expect(SpriteArt.rows(for: .armsUp) == [
            "2.1111.2", "21111112", "31222213", "3126262.", ".32222..", ".333333.",
            "..3333..", "..3333..", "..4444..", "..4..4..", "..5..5..",
        ])
    }

    @Test func frameOrderIsFixed() {
        #expect(SpriteFrame.allCases.map(\.rawValue) == ["idle", "blink", "walk", "armsUp", "wave", "waveHigh", "sleep"])
    }

    @Test func hexParsing() {
        #expect(RGBA(hex: "#ff0080") == RGBA(r: 255, g: 0, b: 128))
        #expect(RGBA(hex: "00FF00") == RGBA(r: 0, g: 255, b: 0))
        #expect(RGBA(hex: "#fff") == nil)
        #expect(RGBA(hex: "zzzzzz") == nil)
        #expect(RGBA(hex: "") == nil)
    }

    @Test func colorLookup() {
        #expect(SpriteArt.color(of: .idle, x: 2, y: 0) == SpriteArt.palette["1"])
        #expect(SpriteArt.color(of: .idle, x: 0, y: 0) == nil)
        #expect(SpriteArt.color(of: .idle, x: 8, y: 0) == nil)
        #expect(SpriteArt.color(of: .idle, x: 0, y: -1) == nil)
        #expect(SpriteArt.color(of: .blink, x: 3, y: 3) == SpriteArt.palette["7"])
    }

    @Test func blinkOnlyClosesTheEyes() {
        var differences: [(Int, Int)] = []
        for y in 0..<SpriteArt.height {
            for x in 0..<SpriteArt.width where SpriteArt.color(of: .idle, x: x, y: y) != SpriteArt.color(of: .blink, x: x, y: y) {
                differences.append((x, y))
            }
        }
        #expect(differences.count == 2)
        #expect(differences.contains { $0 == (3, 3) })
        #expect(differences.contains { $0 == (5, 3) })
    }
}
