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
    @AppStorage("soundEnabled")     private var soundEnabled: Bool = true
    @State private var isFullscreen: Bool = false
    @State private var fullscreenRequestID: Int = 0
    @FocusState private var keyFocus: Bool

    private var palette: Palette { Palette.from(theme) }
    private var clockEditable: Bool { engine.mode == .countdown && !engine.isRunning }
    private var clockStatus: ClockStatus {
        guard engine.mode == .countdown else { return .normal }
        if engine.isFinished { return .finished }
        if engine.displaySeconds <= Countdown.warningSeconds { return .warning }
        return .normal
    }

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
                                   alwaysOnTop: alwaysOnTop, miniMode: miniMode,
                                   fullscreenRequestID: fullscreenRequestID,
                                   onFullscreenChange: handleFullscreenChange))
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
        .onChange(of: engine.completionCount) { _, newValue in
            guard newValue > 0, soundEnabled else { return }
            NSSound.beep()
        }
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
        case "f":       toggleFullscreen();           return .handled
        case "l":       theme = (theme == .dark) ? .light : .dark; return .handled
        case "t":       alwaysOnTop.toggle();         return .handled
        case "i":       toggleMiniMode();             return .handled
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
                status: clockStatus,
                editable: clockEditable,
                onCommit: { secs in engine.setCountdown(seconds: secs) },
                onEditingFinished: { keyFocus = true }
            )
            .padding(.horizontal, 32)

            secondaryStrip
                .padding(.top, 10)
                .padding(.horizontal, 32)

            Spacer(minLength: 10)

            controlBar
                .padding(.bottom, 32)
                .padding(.horizontal, 28)
        }
    }

    private var miniLayout: some View {
        ZStack(alignment: .topTrailing) {
            BigClockView(
                text: TimerEngine.format(engine.displaySeconds),
                status: clockStatus,
                editable: clockEditable,
                onCommit: { secs in engine.setCountdown(seconds: secs) },
                onEditingFinished: { keyFocus = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            HStack(spacing: 6) {
                pinToggle
                miniPlayToggle
                miniToggle
            }
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
                soundToggle.transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            Spacer()
            if showShortcuts {
                shortcutHints
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
            helpToggle
            pinToggle
            fullscreenToggle
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
            isOn: miniModeBinding,
            symbol: "minus",
            activeSymbol: "plus",
            accentWhenOn: false,
            help: miniMode ? "Exit mini mode (I)" : "Mini mode — only digits (I)"
        )
    }

    private var miniPlayToggle: some View {
        iconButton(
            symbol: engine.isRunning ? "pause.fill" : "play.fill",
            isActive: engine.isRunning,
            help: engine.isRunning ? "Pause timer (Space)" : "Start timer (Space)"
        ) {
            engine.toggle()
        }
    }

    private var fullscreenToggle: some View {
        IconToggle(
            isOn: fullscreenBinding,
            symbol: "arrow.up.left.and.arrow.down.right",
            activeSymbol: "arrow.down.right.and.arrow.up.left",
            accentWhenOn: false,
            help: isFullscreen ? "Exit full screen (F)" : "Enter full screen (F)"
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

    private var soundToggle: some View {
        IconToggle(
            isOn: $soundEnabled,
            symbol: "speaker.slash.fill",
            activeSymbol: "speaker.wave.2.fill",
            accentWhenOn: false,
            help: soundEnabled ? "Sound on at zero" : "Sound off at zero"
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
            hint("+/−",   "timer")
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
                .disabled(engine.isRunning || engine.countdownDuration <= Countdown.stepSeconds)
                .opacity((engine.isRunning || engine.countdownDuration <= Countdown.stepSeconds) ? 0.4 : 1)
            } else {
                ControlButton(title: "LAP", variant: .secondary, minWidth: 110) {
                    engine.recordLap()
                }
                .disabled(engine.displaySeconds <= 0)
                .opacity(engine.displaySeconds <= 0 ? 0.4 : 1)
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
                .disabled(engine.isRunning || engine.countdownDuration >= Countdown.maxSeconds)
                .opacity((engine.isRunning || engine.countdownDuration >= Countdown.maxSeconds) ? 0.4 : 1)
            } else {
                Color.clear
                    .frame(width: 110, height: Layout.buttonHeight)
            }
        }
    }

    // MARK: - Secondary strip

    @ViewBuilder
    private var secondaryStrip: some View {
        if engine.mode == .countdown {
            presetStrip
        } else if !engine.laps.isEmpty {
            lapStrip
        }
    }

    private var presetStrip: some View {
        HStack(spacing: 8) {
            ForEach(Countdown.presetsMinutes, id: \.self) { minutes in
                compactButton(
                    title: "\(minutes) MIN",
                    isSelected: Int(engine.countdownDuration / 60) == minutes && engine.countdownDuration.truncatingRemainder(dividingBy: 60) == 0,
                    isDisabled: engine.isRunning
                ) {
                    engine.applyPreset(minutes: minutes)
                }
            }
        }
        .frame(height: 30)
    }

    private var lapStrip: some View {
        HStack(spacing: 12) {
            ForEach(engine.laps.prefix(3)) { lap in
                Text("L\(lap.index) \(TimerEngine.format(lap.split))")
                    .font(KIFont.tech(11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(palette.textMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(palette.bgSurface)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
                    .help("Total \(TimerEngine.format(lap.total))")
            }
        }
        .frame(height: 30)
    }

    private func compactButton(
        title: String,
        isSelected: Bool,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(KIFont.tech(11, weight: .bold))
                .tracking(1.5)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? palette.accentText : palette.textMuted)
                .background(isSelected ? palette.toggleActiveBG : palette.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1)
    }

    private var fullscreenBinding: Binding<Bool> {
        Binding(
            get: { isFullscreen },
            set: { target in
                guard target != isFullscreen else { return }
                toggleFullscreen()
            }
        )
    }

    private var miniModeBinding: Binding<Bool> {
        Binding(
            get: { miniMode },
            set: { target in
                guard target != miniMode else { return }
                toggleMiniMode()
            }
        )
    }

    private func iconButton(
        symbol: String,
        isActive: Bool = false,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: Layout.iconFontSize, weight: .semibold))
                .frame(width: Layout.toggleIconSize, height: Layout.toggleIconSize)
                .background(isActive ? palette.toggleActiveBG : palette.bgSurface)
                .foregroundStyle(isActive ? palette.accentText : palette.textSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                        .stroke(palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toggleMiniMode() {
        if isFullscreen {
            toggleFullscreen()
            return
        }
        miniMode.toggle()
    }

    private func toggleFullscreen() {
        if miniMode {
            miniMode = false
        }
        fullscreenRequestID += 1
    }

    private func handleFullscreenChange(_ fullscreen: Bool) {
        isFullscreen = fullscreen
        if fullscreen && miniMode {
            miniMode = false
        }
    }
}

// MARK: - Window styling

struct WindowAccessor: NSViewRepresentable {
    let palette: Palette
    let theme: ThemeMode
    let alwaysOnTop: Bool
    let miniMode: Bool
    let fullscreenRequestID: Int
    let onFullscreenChange: (Bool) -> Void

    final class Coordinator {
        var didSetupOnce = false
        var lastTheme: ThemeMode?
        var lastOnTop: Bool?
        var lastMini: Bool?
        var lastAppliedFullscreen: Bool?
        var lastFullscreenRequestID: Int = 0
        var savedNormalSize: NSSize?
        weak var window: NSWindow?
        var observers: [NSObjectProtocol] = []
        var onFullscreenChange: ((Bool) -> Void)?
        var isFullscreen: Bool = false

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(to window: NSWindow) {
            guard self.window !== window else { return }
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
            self.window = window

            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSWindow.didEnterFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.setFullscreen(true)
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSWindow.didExitFullScreenNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.setFullscreen(false)
                }
            )
        }

        func setFullscreen(_ fullscreen: Bool) {
            guard fullscreen != isFullscreen else { return }
            isFullscreen = fullscreen
            onFullscreenChange?(fullscreen)
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coord = context.coordinator
        DispatchQueue.main.async {
            guard let win = nsView.window else { return }
            coord.attach(to: win)
            coord.onFullscreenChange = onFullscreenChange

            if !coord.didSetupOnce {
                win.titleVisibility = .hidden
                win.titlebarAppearsTransparent = true
                win.isMovableByWindowBackground = true
                win.styleMask.insert(.titled)
                win.styleMask.insert(.closable)
                win.styleMask.insert(.miniaturizable)
                win.styleMask.insert(.resizable)
                win.styleMask.insert(.fullSizeContentView)
                win.collectionBehavior.insert(.fullScreenPrimary)
                win.collectionBehavior.remove(.fullScreenAuxiliary)
                win.minSize = NSSize(width: Layout.normalMinSize.width,
                                     height: Layout.normalMinSize.height)
                if win.frame.size.width < 1100 {
                    win.setContentSize(NSSize(width: Layout.normalDefaultSize.width,
                                              height: Layout.normalDefaultSize.height))
                    win.center()
                }
                coord.didSetupOnce = true
            }

            coord.setFullscreen(win.styleMask.contains(.fullScreen))

            if coord.lastTheme != theme {
                win.appearance = theme.nsAppearance
                win.backgroundColor = palette.nsBackground
                coord.lastTheme = theme
            }

            if coord.lastOnTop != alwaysOnTop || coord.lastAppliedFullscreen != coord.isFullscreen {
                if alwaysOnTop && !coord.isFullscreen {
                    win.level = .floating
                    win.collectionBehavior.insert(.canJoinAllSpaces)
                } else {
                    win.level = .normal
                    win.collectionBehavior.remove(.canJoinAllSpaces)
                }
                win.collectionBehavior.insert(.fullScreenPrimary)
                win.collectionBehavior.remove(.fullScreenAuxiliary)
                coord.lastOnTop = alwaysOnTop
                coord.lastAppliedFullscreen = coord.isFullscreen
            }

            if coord.lastMini != miniMode && !coord.isFullscreen {
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

            if coord.lastFullscreenRequestID != fullscreenRequestID {
                coord.lastFullscreenRequestID = fullscreenRequestID
                win.collectionBehavior.insert(.fullScreenPrimary)
                win.collectionBehavior.remove(.fullScreenAuxiliary)
                win.toggleFullScreen(nil)
            }
        }
    }
}
