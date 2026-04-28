import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var engine = TimerEngine()
    @AppStorage("themeMode")        private var theme: ThemeMode = .dark
    @AppStorage("showShortcuts")    private var showShortcuts: Bool = false
    @AppStorage("countdownRepeats") private var repeats: Bool = false
    @AppStorage("timerMode")        private var savedMode: String = TimerMode.stopwatch.rawValue
    @AppStorage("alwaysOnTop")      private var alwaysOnTop: Bool = false
    @AppStorage("miniMode")         private var miniMode: Bool = false
    @FocusState private var keyFocus: Bool

    private var palette: Palette { Palette.from(theme) }
    private var clockEditable: Bool { engine.mode == .countdown && !engine.isRunning }

    private var themeIsDark: Binding<Bool> {
        Binding(
            get: { theme == .dark },
            set: { theme = $0 ? .dark : .light }
        )
    }

    var body: some View {
        ZStack {
            palette.bgApp.ignoresSafeArea()
            if miniMode { miniLayout } else { normalLayout }
        }
        .frame(
            minWidth:  miniMode ? Layout.miniMinSize.width  : Layout.normalMinSize.width,
            minHeight: miniMode ? Layout.miniMinSize.height : Layout.normalMinSize.height
        )
        .environment(\.palette, palette)
        .background(WindowAccessor(palette: palette, theme: theme,
                                   alwaysOnTop: alwaysOnTop, miniMode: miniMode))
        .onAppear {
            BundledFonts.register()
            engine.repeats = repeats
            if let m = TimerMode(rawValue: savedMode), m != engine.mode {
                engine.mode = m
            }
            keyFocus = true
        }
        .onChange(of: repeats)     { _, newValue in engine.repeats = newValue }
        .onChange(of: engine.mode) { _, newMode  in savedMode = newMode.rawValue }
        .focusable()
        .focusEffectDisabled()
        .focused($keyFocus)
        .onKeyPress(phases: .down, action: handleKey)
        .preferredColorScheme(theme == .dark ? .dark : .light)
        .animation(.easeInOut(duration: Layout.themeAnimDuration), value: theme)
        .animation(.easeInOut(duration: Layout.themeAnimDuration), value: miniMode)
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.characters.lowercased() {
        case " ":       engine.toggle();              return .handled
        case "r":       engine.reset();               return .handled
        case "m":       engine.mode = (engine.mode == .stopwatch) ? .countdown : .stopwatch
                                                      ; return .handled
        case "f":       NSApp.keyWindow?.toggleFullScreen(nil); return .handled
        case "l":       theme = (theme == .dark) ? .light : .dark; return .handled
        case "t":       alwaysOnTop.toggle();         return .handled
        case "i":       miniMode.toggle();            return .handled
        case "?":       showShortcuts.toggle();       return .handled
        case "+", "=":  engine.adjustCountdown(by:  Countdown.stepSeconds); return .handled
        case "-", "_":  engine.adjustCountdown(by: -Countdown.stepSeconds); return .handled
        default:        return .ignored
        }
    }

    // MARK: - Layouts

    private var normalLayout: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 18)
                .padding(.horizontal, 28)

            Spacer(minLength: 12)

            BigClockView(
                text: TimerEngine.format(engine.displaySeconds),
                editable: clockEditable,
                onCommit: { secs in engine.setCountdown(seconds: secs) },
                onEditingFinished: { keyFocus = true }
            )
            .padding(.horizontal, 32)

            Spacer(minLength: 12)

            controlBar
                .padding(.bottom, 32)
                .padding(.horizontal, 28)
        }
    }

    private var miniLayout: some View {
        ZStack(alignment: .topTrailing) {
            BigClockView(
                text: TimerEngine.format(engine.displaySeconds),
                editable: clockEditable,
                onCommit: { secs in engine.setCountdown(seconds: secs) },
                onEditingFinished: { keyFocus = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            HStack(spacing: 6) { pinToggle; miniToggle }
                .padding(.top, 8)
                .padding(.trailing, 8)
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            ModeToggle(mode: $engine.mode)
            if engine.mode == .countdown {
                loopToggle.transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Spacer()
            if showShortcuts {
                shortcutHints
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            helpToggle
            pinToggle
            miniToggle
            themeToggle
        }
        .animation(.easeInOut(duration: 0.2), value: showShortcuts)
        .animation(.easeInOut(duration: 0.2), value: engine.mode)
    }

    // MARK: - Toggle factories (each is one IconToggle)

    private var helpToggle: some View {
        IconToggle(
            isOn: $showShortcuts,
            symbol: "questionmark",
            help: showShortcuts ? "Hide shortcuts (?)" : "Show shortcuts (?)"
        )
    }

    private var pinToggle: some View {
        IconToggle(
            isOn: $alwaysOnTop,
            symbol: "pin",
            activeSymbol: "pin.fill",
            help: alwaysOnTop ? "Always on top — click to release"
                              : "Keep window above other apps (T)"
        )
    }

    private var miniToggle: some View {
        IconToggle(
            isOn: $miniMode,
            symbol: "arrow.down.right.and.arrow.up.left",
            activeSymbol: "arrow.up.left.and.arrow.down.right",
            accentWhenOn: false,
            help: miniMode ? "Exit mini mode (I)" : "Mini mode — only digits (I)"
        )
    }

    private var themeToggle: some View {
        IconToggle(
            isOn: themeIsDark,
            symbol: "sun.max.fill",
            activeSymbol: "moon.fill",
            label: theme == .dark ? "DARK" : "LIGHT",
            accentWhenOn: false,
            help: "Toggle light / dark mode (L)"
        )
    }

    private var loopToggle: some View {
        IconToggle(
            isOn: $repeats,
            symbol: "arrow.triangle.2.circlepath",
            label: "LOOP",
            help: repeats ? "Loop on — countdown restarts at zero"
                          : "Loop off — countdown stops at zero"
        )
    }

    // MARK: - Shortcut hints row (visible only when ? is on)

    private var shortcutHints: some View {
        HStack(spacing: 18) {
            hint("SPACE", "start/stop")
            hint("R",     "reset")
            hint("M",     "mode")
            hint("F",     "fullscreen")
            hint("T",     "always on top")
            hint("I",     "mini mode")
            hint("L",     "theme")
        }
        .opacity(0.85)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(KIFont.tech(10, weight: .bold))
                .tracking(1.5)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(palette.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 1))
                .foregroundStyle(palette.textSecondary)
            Text(label)
                .font(KIFont.human(11, weight: .regular))
                .foregroundStyle(palette.textMuted)
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: 14) {
            if engine.mode == .countdown {
                ControlButton(title: "−1 MIN", variant: .secondary, minWidth: 110) {
                    engine.adjustCountdown(by: -Countdown.stepSeconds)
                }
                .disabled(engine.countdownDuration <= Countdown.stepSeconds)
                .opacity(engine.countdownDuration <= Countdown.stepSeconds ? 0.4 : 1)
            }

            Spacer(minLength: 0)

            ControlButton(
                title: engine.isRunning ? "STOP" : "START",
                variant: .primary,
                minWidth: 200
            ) { engine.toggle() }

            ControlButton(title: "RESET", variant: .secondary, minWidth: 160) {
                engine.reset()
            }

            Spacer(minLength: 0)

            if engine.mode == .countdown {
                ControlButton(title: "+1 MIN", variant: .secondary, minWidth: 110) {
                    engine.adjustCountdown(by: Countdown.stepSeconds)
                }
            }
        }
    }
}

// MARK: - Window styling

struct WindowAccessor: NSViewRepresentable {
    let palette: Palette
    let theme: ThemeMode
    let alwaysOnTop: Bool
    let miniMode: Bool

    final class Coordinator {
        var didSetupOnce = false
        var lastTheme: ThemeMode?
        var lastOnTop: Bool?
        var lastMini: Bool?
        var savedNormalSize: NSSize?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coord = context.coordinator
        DispatchQueue.main.async {
            guard let win = nsView.window else { return }

            if !coord.didSetupOnce {
                win.titleVisibility = .hidden
                win.titlebarAppearsTransparent = true
                win.isMovableByWindowBackground = true
                win.styleMask.insert(.fullSizeContentView)
                win.minSize = NSSize(width: Layout.normalMinSize.width,
                                     height: Layout.normalMinSize.height)
                if win.frame.size.width < 1100 {
                    win.setContentSize(NSSize(width: Layout.normalDefaultSize.width,
                                              height: Layout.normalDefaultSize.height))
                    win.center()
                }
                coord.didSetupOnce = true
            }

            if coord.lastTheme != theme {
                win.appearance = theme.nsAppearance
                win.backgroundColor = palette.nsBackground
                coord.lastTheme = theme
            }

            if coord.lastOnTop != alwaysOnTop {
                if alwaysOnTop {
                    win.level = .floating
                    win.collectionBehavior.insert(.canJoinAllSpaces)
                    win.collectionBehavior.insert(.fullScreenAuxiliary)
                } else {
                    win.level = .normal
                    win.collectionBehavior.remove(.canJoinAllSpaces)
                    win.collectionBehavior.remove(.fullScreenAuxiliary)
                }
                coord.lastOnTop = alwaysOnTop
            }

            if coord.lastMini != miniMode {
                if miniMode {
                    coord.savedNormalSize = win.frame.size
                    win.minSize = NSSize(width: Layout.miniMinSize.width,
                                         height: Layout.miniMinSize.height)
                    win.setContentSize(NSSize(width: Layout.miniDefaultSize.width,
                                              height: Layout.miniDefaultSize.height))
                } else {
                    win.minSize = NSSize(width: Layout.normalMinSize.width,
                                         height: Layout.normalMinSize.height)
                    if let s = coord.savedNormalSize,
                       s.width  >= Layout.normalMinSize.width,
                       s.height >= Layout.normalMinSize.height {
                        win.setContentSize(s)
                    } else {
                        win.setContentSize(NSSize(width: Layout.normalDefaultSize.width,
                                                  height: Layout.normalDefaultSize.height))
                    }
                }
                coord.lastMini = miniMode
            }
        }
    }
}
