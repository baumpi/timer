import SwiftUI
import AppKit

/// Full-feature popover for the menu bar item — full control parity with the
/// main window so the user never has to leave the menu bar to drive the timer.
struct MenuBarTimerPopover: View {
    @EnvironmentObject private var engine: TimerEngine
    @Environment(\.palette) private var palette
    @Environment(\.openSettings) private var openSettings

    private var clockStatus: ClockStatus {
        guard engine.mode == .countdown else { return .normal }
        if engine.isFinished { return .finished }
        if engine.displaySeconds <= Countdown.warningSeconds { return .warning }
        return .normal
    }

    private var clockEditable: Bool {
        engine.mode == .countdown && !engine.isRunning
    }

    private var canAdjustCountdown: Bool {
        engine.mode == .countdown && !engine.isRunning
    }

    var body: some View {
        VStack(spacing: 14) {
            ModeToggle(mode: $engine.mode)

            BigClockView(
                text: TimerEngine.format(engine.displaySeconds),
                status: clockStatus,
                editable: clockEditable,
                onCommit: { engine.setCountdown(seconds: $0) }
            )
            .frame(height: 44)

            if engine.mode == .countdown {
                loopToggle
                presetRow
            }

            controlRow

            if engine.mode == .stopwatch && !engine.laps.isEmpty {
                lapList
            }

            Divider().background(palette.border)

            footer
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 300)
        .background(palette.bgApp)
    }

    private var loopToggle: some View {
        IconToggle(
            isOn: $engine.repeats,
            symbol: "arrow.triangle.2.circlepath",
            label: "LOOP",
            help: engine.repeats ? "Loop on — countdown restarts at zero"
                                 : "Loop off — countdown stops at zero"
        )
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(Countdown.currentPresetMinutes(), id: \.self) { minutes in
                let selected = Int(engine.countdownDuration / 60) == minutes
                    && engine.countdownDuration.truncatingRemainder(dividingBy: 60) == 0
                Button {
                    engine.applyPreset(minutes: minutes)
                } label: {
                    Text("\(minutes) MIN")
                        .font(KIFont.tech(10, weight: .bold))
                        .tracking(1.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(selected ? palette.accentText : palette.textMuted)
                        .background(selected ? palette.toggleActiveBG : palette.bgSurface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(palette.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .disabled(engine.isRunning)
                .opacity(engine.isRunning ? 0.4 : 1)
            }
        }
    }

    private var controlRow: some View {
        HStack(spacing: 8) {
            if engine.mode == .countdown {
                iconButton(symbol: "minus",
                           help: "−1 minute",
                           enabled: canAdjustCountdown && engine.countdownDuration > Countdown.stepSeconds) {
                    engine.adjustCountdown(by: -Countdown.stepSeconds)
                }
            } else {
                iconButton(symbol: "flag.fill",
                           help: "Record lap",
                           enabled: engine.displaySeconds > 0) {
                    engine.recordLap()
                }
            }

            iconButton(symbol: engine.isRunning ? "pause.fill" : "play.fill",
                       help: engine.isRunning ? "Pause" : "Start",
                       prominent: true) {
                engine.toggle()
            }

            iconButton(symbol: "arrow.counterclockwise",
                       help: "Reset") {
                engine.reset()
            }

            if engine.mode == .countdown {
                iconButton(symbol: "plus",
                           help: "+1 minute",
                           enabled: canAdjustCountdown && engine.countdownDuration < Countdown.maxSeconds) {
                    engine.adjustCountdown(by: Countdown.stepSeconds)
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }

    @ViewBuilder
    private func iconButton(
        symbol: String,
        help: String,
        enabled: Bool = true,
        prominent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 14 : 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: prominent ? 36 : 32)
                .background(prominent ? palette.toggleActiveBG : palette.bgSurface)
                .foregroundStyle(prominent ? palette.accentText : palette.textSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.cornerRadiusSm)
                        .stroke(palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusSm))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .help(help)
    }

    private var lapList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(engine.laps.prefix(3)) { lap in
                HStack {
                    Text("L\(lap.index)")
                        .font(KIFont.tech(10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(palette.textMuted)
                    Spacer()
                    Text(TimerEngine.format(lap.split))
                        .font(KIFont.tech(11, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(palette.textSecondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(palette.bgSurface)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(palette.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openSettingsFromPopover()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("SETTINGS")
                        .font(KIFont.tech(10, weight: .bold))
                        .tracking(1.5)
                }
                .foregroundStyle(palette.textMuted)
            }
            .buttonStyle(.plain)
            .help("Open Settings (⌘,)")

            Spacer()

            Button {
                showMainWindow()
            } label: {
                Text("Show window")
                    .font(KIFont.human(11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func openSettingsFromPopover() {
        // Bring the app forward first — the menu bar popover is a
        // nonactivating panel, so without this the Settings window opens
        // behind whatever app was previously active.
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        let main = NSApp.windows.first(where: { $0.canBecomeMain && $0.title == AppInfo.mainWindowTitle })
            ?? NSApp.windows.first(where: { $0.canBecomeMain })
        main?.makeKeyAndOrderFront(nil)
    }
}
