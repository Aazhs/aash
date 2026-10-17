# Patterns to copy

Each pattern here compiles in Swift 6 language mode against the macOS SDK on this Mac (checked
18 Oct 2026). Copy the one you need instead of inventing a variant. If a card needs something new,
the card shows it, and the reviewer adds it here afterwards.

## Logging

```swift
import os

private let log = Logger(subsystem: "me.aarshj.aash", category: "Status")

log.debug("walk area: \(range.lowerBound, privacy: .public)…\(range.upperBound, privacy: .public)")
log.error("Gemini returned HTTP \(status, privacy: .public)")
```

- One `private let log` per file, at the top. Categories are listed in `architecture.md#logging`.
- Mark numbers and enum values `privacy: .public`; leave text as it is (private). Never log keys
  or chat text.

## Observers

Notifications on the main actor: `queue: .main`, `[weak self]`, then `MainActor.assumeIsolated`.

```swift
@MainActor
final class SystemEvents {
    var onPausedChange: ((Bool) -> Void)?
    private var tokens: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        tokens.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onPausedChange?(true) }
        })
        // NSWorkspace notifications live on NSWorkspace.shared.notificationCenter,
        // everything else on NotificationCenter.default.
        tokens.append(NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.onPausedChange?(ProcessInfo.processInfo.isLowPowerModeEnabled) }
        })
    }

    func stop() {
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            NotificationCenter.default.removeObserver(token)
        }
        tokens.removeAll()
    }
}
```

## The clock

`AnimationClock` is the app's only repeating timer. It reschedules itself whenever the engine's
output asks for a different `ClockSchedule`.

```swift
import AppKit
import AashCore

@MainActor
final class AnimationClock {
    var onTick: (() -> Void)?
    private var timer: Timer?
    private(set) var schedule: ClockSchedule = .stopped

    func apply(_ newSchedule: ClockSchedule) {
        guard newSchedule != schedule else { return }
        schedule = newSchedule
        timer?.invalidate()
        timer = nil
        let made: Timer
        switch newSchedule {
        case .stopped:
            return
        case .every(let seconds):
            made = Timer(timeInterval: seconds, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.onTick?() }
            }
            made.tolerance = seconds * 0.2
        case .once(let date):
            made = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.schedule = .stopped
                    self?.onTick?()
                }
            }
            made.tolerance = 0.5
        }
        RunLoop.main.add(made, forMode: .common)   // .common: keeps firing while a menu is open
        timer = made
    }
}
```

- Tolerance lets macOS batch the wake-up with others: 20% for frame ticks, 0.5 s for one-off ticks.
- Never add a second `Timer`, a `DispatchSourceTimer` or an `asyncAfter` chain. Ask the engine for a
  schedule instead.

## Sprite layer

The sheet is one `CGImage`. A frame is shown by changing `contentsRect`, a GPU-only change with
nothing redrawn.

```swift
import AppKit
import QuartzCore

@MainActor
final class SpriteLayerView: NSView {
    private let spriteLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        spriteLayer.magnificationFilter = .nearest   // crisp pixels
        spriteLayer.contentsGravity = .resize
        layer?.addSublayer(spriteLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func show(sheet: CGImage, rect: CGRect, frame layerFrame: CGRect, facingLeft: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)        // no implicit 0.25 s animation
        if spriteLayer.contents == nil { spriteLayer.contents = sheet }
        spriteLayer.contentsRect = rect
        spriteLayer.frame = layerFrame
        spriteLayer.setAffineTransform(facingLeft ? CGAffineTransform(scaleX: -1, y: 1) : .identity)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Dark menu bar: rebuild the sheet with an outline (sprites.md#outline).
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }   // clicks go to the status button
}
```

- Every change to a layer goes inside `CATransaction` with actions disabled.
- Round layer positions to whole device pixels: `(x * scale).rounded() / scale`, where `scale` is
  `window?.backingScaleFactor ?? 2`.
- Never override `draw(_:)` for the sprite.

## Status item

```swift
@MainActor
final class StatusItemExample: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: 22)
    var onLeftClick: (() -> Void)?
    var menu: NSMenu?

    func install(view: NSView) {
        guard let button = item.button else { return }
        button.image = nil
        button.addSubview(view)
        button.target = self
        button.action = #selector(clicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp, let menu {
            item.menu = menu
            sender.performClick(nil)   // shows the menu
            item.menu = nil            // left clicks stay ours
        } else {
            onLeftClick?()
        }
    }
}
```

- `item.length` sets the width in points. On macOS 27 the item grows to the left and its right
  edge stays put (`menubar.md#what-macos-27-does`).
- The item's frame on screen is `item.button?.window?.frame`.

## Settings

```swift
@MainActor
final class AppSettings {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var walkingEnabled: Bool {
        get { defaults.object(forKey: "walkingEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "walkingEnabled") }
    }
}
```

Read with `object(forKey:) as? Bool ?? default` so an unset key gets the documented default.
List every key in `architecture.md#settings-keys`.

## AppKit layout

Build small windows and popovers from `NSStackView`, not hand-written constraints.

```swift
@MainActor
func makeRow(title: String, control: NSView) -> NSStackView {
    let label = NSTextField(labelWithString: title)
    label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    let row = NSStackView(views: [label, control])
    row.orientation = .horizontal
    row.spacing = 8
    row.alignment = .firstBaseline
    return row
}
```

Build views when they're first shown and release them when they close; don't keep a hidden
window or popover alive.

## Streaming

A provider is a `Sendable` struct. It returns an `AsyncThrowingStream`, and cancelling the
stream cancels the request.

```swift
public struct StreamingClient: Sendable {
    public enum ClientError: Error, Equatable { case http(Int), noResponse }
    let session: URLSession
    let endpoint: URL

    public func lines(body: Data) -> AsyncThrowingStream<String, Error> {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        request.timeoutInterval = 30
        let session = self.session
        let ready = request
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (bytes, response) = try await session.bytes(for: ready)
                    guard let http = response as? HTTPURLResponse else { throw ClientError.noResponse }
                    guard (200..<300).contains(http.statusCode) else { throw ClientError.http(http.statusCode) }
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

Consume it on the main actor:

```swift
let provider = self.provider
streamTask = Task { @MainActor [weak self] in
    do {
        for try await chunk in provider.stream(messages, system: prompt) { self?.append(chunk) }
    } catch {
        self?.show(error)
    }
}
```

Cancel `streamTask` when the popover closes.

## Keychain

```swift
import Security

public struct KeychainStore: Sendable {
    public enum Error: Swift.Error, Equatable { case unexpected(OSStatus) }
    let service: String

    public func read(_ account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw Error.unexpected(status) }
        return String(data: data, encoding: .utf8)
    }
}
```

Write is `SecItemUpdate`, falling back to `SecItemAdd` on `errSecItemNotFound`. Delete treats
`errSecItemNotFound` as success. T16 has the full code.

## Tests

```swift
import Foundation
import Testing
@testable import AashCore

@Suite struct BehaviourEngineTests {
    @Test func blinksAfterInterval() {
        // arrange, act, then:
        #expect(output.pose == .blink)
    }

    @Test(arguments: [(0, 0), (-3, -6), (21, 42)])
    func doubles(input: Int, expected: Int) {
        #expect(input * 2 == expected)
    }

    @Test func usesAFixedDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Asia/Kolkata"))
        let date = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 9)))
        #expect(calendar.component(.hour, from: date) == 9)
    }
}
```

- Never call `Date()` in a test: build dates from components with a fixed time zone.
- Never use real randomness: pass a seed (`SplitMix64`), or a config whose ranges have a single
  value, like `4...4`.
- One behaviour per `@Test`, and the name says what's expected.

## Fixtures

Recorded responses live in `Tests/Fixtures/`, outside every target, so SwiftPM doesn't need
resource declarations. Load them relative to the test file:

```swift
enum Fixture {
    static func url(_ name: String, file: StaticString = #filePath) -> URL {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // Tests/<Target>Tests
            .deletingLastPathComponent()   // Tests
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
    }
}

let text = try String(contentsOf: Fixture.url("gemini/stream-hello.txt"), encoding: .utf8)
```

## Random numbers

```swift
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

var rng = SplitMix64(seed: 42)
let wait = Double.random(in: 3...6, using: &rng)
```

## Gotchas

Curated by reviewers. Add one line when a card trips over something.

- Changing a layer property without `CATransaction.setDisableActions(true)` animates for 0.25 s,
  which costs CPU and blurs pixel art.
- A `Timer` added in `.default` mode stops while a menu is open; use `.common`.
- Notification and `Timer` closures are `@Sendable`. Reach main-actor state with
  `MainActor.assumeIsolated`, and only from closures that run on the main thread
  (`queue: .main`, `RunLoop.main`).
- `NSWorkspace` notifications are posted on `NSWorkspace.shared.notificationCenter`, not
  `NotificationCenter.default`.
- Growing a status item moves its left edge, not its right one.
- Test builds only work through the scripts (`./scripts/test.sh`). Plain `swift build` can break
  Swift Testing's macros with the Command Line Tools (`decisions.md`, 18 Oct).
