import AppKit
import SwiftUI
import Combine

/// Tints the entire macOS menu bar with an hourglass-style drain bar.
///
/// macOS does not let apps paint inside the real menu bar, so per screen we
/// place a borderless click-through NSWindow at `.mainMenu + 1`, sized to cover
/// the menu bar area. Low alpha keeps the existing menu bar text readable.
///
/// Why these specific NSWindow flags:
/// - `level = .mainMenu + 1` — paints on top of menu bar items.
/// - `ignoresMouseEvents = true` — clicks fall through to menu items.
/// - `.fullScreenAuxiliary` — overlay hides with the bar when the user
///    fullscreens another app.
///
/// Notch handling: one full-width window per screen. Inside the SwiftUI view,
/// the fill is split into a left and right segment that drain *as if they were
/// one continuous bar*, skipping the notch entirely so no fill is wasted
/// behind the hardware cutout. On non-notch displays only the left segment is
/// used and the bar reads as one rectangle.
@MainActor
final class MenuBarOverlayController {
    private let engine: TimerEngine
    private let tintStore: TintStore
    private var windows: [NSWindow] = []
    private var cancellables: Set<AnyCancellable> = []

    init(engine: TimerEngine, tintStore: TintStore) {
        self.engine = engine
        self.tintStore = tintStore
        NotificationCenter.default
            .publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
        rebuild()
    }

    private func rebuild() {
        for win in windows { win.orderOut(nil) }
        windows.removeAll()
        for screen in NSScreen.screens {
            for frame in barSegments(for: screen) {
                if let win = makeWindow(frame: frame, screen: screen) {
                    windows.append(win)
                }
            }
        }
    }

    private func barSegments(for screen: NSScreen) -> [NSRect] {
        // One window spanning the full screen width. On notched MacBooks the
        // notch cutout simply masks the middle of the window; we don't have to
        // split it manually. The result is a single continuous fill instead of
        // two independent ones meeting at the notch.
        let inset = max(screen.safeAreaInsets.top, 24)
        return [NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - inset,
            width: screen.frame.width,
            height: inset
        )]
    }

    private func makeWindow(frame: NSRect, screen: NSScreen) -> NSWindow? {
        guard frame.width > 1, frame.height > 1 else { return nil }
        let win = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 1)
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = false
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        win.isReleasedWhenClosed = false
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true

        // Capture notch geometry at window-creation time. The controller
        // rebuilds on screen changes, so these widths stay accurate.
        let leftAuxWidth = screen.auxiliaryTopLeftArea?.width ?? 0
        let rightAuxWidth = screen.auxiliaryTopRightArea?.width ?? 0
        let hasNotch = screen.safeAreaInsets.top > 0
            && screen.auxiliaryTopLeftArea != nil
            && screen.auxiliaryTopRightArea != nil

        let host = NSHostingView(rootView: MenuBarOverlayView(
            engine: engine,
            tintStore: tintStore,
            leftAuxWidth: leftAuxWidth,
            rightAuxWidth: rightAuxWidth,
            hasNotch: hasNotch
        ))
        host.frame = NSRect(origin: .zero, size: frame.size)
        host.autoresizingMask = [.width, .height]
        win.contentView = host
        win.orderFrontRegardless()
        return win
    }
}

private struct MenuBarOverlayView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var tintStore: TintStore
    let leftAuxWidth: CGFloat
    let rightAuxWidth: CGFloat
    let hasNotch: Bool

    @State private var pulsePhase: Double = 0
    private static let flashWindowSeconds: TimeInterval = 3

    private var tintColor: Color { tintStore.activeColor }

    private var shouldFlash: Bool {
        engine.mode == .countdown
            && engine.isRunning
            && engine.displaySeconds > 0
            && engine.displaySeconds <= Self.flashWindowSeconds
    }

    private func updatePulse(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: 0.32).repeatForever(autoreverses: true)) {
                pulsePhase = 1.0
            }
        } else {
            withAnimation(.linear(duration: 0.15)) {
                pulsePhase = 0
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            // On non-notched displays we treat the whole bar as the "left"
            // segment; the right segment is zero-width and never renders.
            let leftWidth  = hasNotch ? leftAuxWidth  : totalWidth
            let rightWidth = hasNotch ? rightAuxWidth : 0
            let notchEndX  = totalWidth - rightWidth
            let visibleWidth = leftWidth + rightWidth

            let ratio = engine.mode == .countdown ? engine.countdownRemainingRatio : 0
            let fillTotal = visibleWidth * ratio

            // Drain right-to-left: as time runs down, the right segment empties
            // first (toward the notch), then the left segment empties (from its
            // notch-side edge inward). The notch is simply skipped.
            let leftFill  = min(fillTotal, leftWidth)
            let rightFill = max(0, fillTotal - leftWidth)

            let activeOpacity = min(1.0, fillOpacity + pulsePhase * 0.35)

            ZStack(alignment: .topLeading) {
                // Baseline tints on visible segments only
                Rectangle()
                    .fill(tintColor.opacity(baselineOpacity))
                    .frame(width: leftWidth)
                if rightWidth > 0 {
                    Rectangle()
                        .fill(tintColor.opacity(baselineOpacity))
                        .frame(width: rightWidth)
                        .offset(x: notchEndX)
                }

                // Fill
                Rectangle()
                    .fill(tintColor.opacity(activeOpacity))
                    .frame(width: leftFill)
                    .animation(.linear(duration: 1.0), value: engine.displaySeconds)

                if rightWidth > 0 {
                    Rectangle()
                        .fill(tintColor.opacity(activeOpacity))
                        .frame(width: rightFill)
                        .offset(x: notchEndX)
                        .animation(.linear(duration: 1.0), value: engine.displaySeconds)
                }
            }
        }
        .ignoresSafeArea()
        .onChange(of: shouldFlash) { _, on in updatePulse(on) }
        .onAppear { updatePulse(shouldFlash) }
    }

    private var baselineOpacity: Double {
        engine.mode == .countdown ? 0.04 : 0
    }

    private var fillOpacity: Double {
        guard engine.mode == .countdown else { return 0 }
        if engine.isFinished { return 0.40 }
        if engine.displaySeconds <= Countdown.warningSeconds { return 0.32 }
        if engine.displaySeconds <= Countdown.cautionSeconds { return 0.26 }
        return 0.20
    }
}
