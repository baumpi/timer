import SwiftUI

enum MenuBarLabelFormat: String, CaseIterable, Identifiable {
    case mmss     = "mmss"      // 04:32
    case seconds  = "seconds"   // 272s
    case percent  = "percent"   // 64%
    case hidden   = "hidden"    // no digits, just the indicator
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mmss:    return "MM:SS"
        case .seconds: return "Seconds"
        case .percent: return "Percent remaining"
        case .hidden:  return "Hide digits"
        }
    }
}

struct MenuBarTimerLabel: View {
    // ObservedObject (not EnvironmentObject) because MenuBarExtra's `label:`
    // closure renders outside any `.environmentObject(...)` propagation.
    @ObservedObject var engine: TimerEngine

    @AppStorage(Defaults.menuBarLabelFormat) private var rawFormat: String = MenuBarLabelFormat.mmss.rawValue
    @AppStorage(Defaults.disablePulse)       private var disablePulse: Bool = false
    @AppStorage(Defaults.accentHex)          private var accentHexInt: Int = 0

    private static let barWidth: CGFloat = 42
    private static let barHeight: CGFloat = 6
    private static let digitsSize: CGFloat = 14

    @State private var pulsePhase: Double = 0

    private var format: MenuBarLabelFormat {
        MenuBarLabelFormat(rawValue: rawFormat) ?? .mmss
    }

    private var accent: Color {
        // Reads `accentHexInt` (not `Color.currentAccent`) so SwiftUI knows
        // to re-render this view when the user changes the accent in
        // Settings — the @AppStorage binding is the observability hook.
        accentHexInt > 0 ? Color(hex: UInt32(accentHexInt)) : .brandAccent
    }

    private var shouldFlash: Bool {
        !disablePulse
            && engine.mode == .countdown
            && engine.isRunning
            && engine.displaySeconds > 0
            && engine.displaySeconds <= Countdown.flashWindowSeconds
    }

    var body: some View {
        HStack(spacing: 7) {
            leadingIndicator
            if format != .hidden {
                digits
            }
        }
        .padding(.horizontal, 3)
        .onChange(of: shouldFlash) { _, on in updatePulse(on) }
        .onAppear { updatePulse(shouldFlash) }
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

    @ViewBuilder
    private var leadingIndicator: some View {
        switch engine.mode {
        case .countdown:
            drainCapsule
        case .stopwatch:
            stopwatchDot
        }
    }

    private var drainCapsule: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Self.barHeight / 2)
                .fill(Color.primary.opacity(0.18))
                .frame(width: Self.barWidth, height: Self.barHeight)
            RoundedRectangle(cornerRadius: Self.barHeight / 2)
                .fill(accent.opacity(min(1.0, capsuleOpacity + pulsePhase * 0.35)))
                .frame(
                    width: max(2, Self.barWidth * engine.countdownRemainingRatio),
                    height: Self.barHeight
                )
                .animation(.linear(duration: 1.0), value: engine.displaySeconds)
        }
        .frame(width: Self.barWidth, height: Self.barHeight)
        .scaleEffect(1.0 + pulsePhase * 0.12)
    }

    private var stopwatchDot: some View {
        Circle()
            .fill(engine.isRunning ? accent : Color.secondary.opacity(0.6))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
    }

    private var digits: some View {
        Text(formattedDigits)
            .font(.system(size: Self.digitsSize, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
    }

    private var formattedDigits: String {
        switch format {
        case .mmss:
            return TimerEngine.format(engine.displaySeconds)
        case .seconds:
            return "\(Int(engine.displaySeconds))s"
        case .percent:
            guard engine.mode == .countdown else {
                return TimerEngine.format(engine.displaySeconds)
            }
            let pct = Int((engine.countdownRemainingRatio * 100).rounded())
            return "\(pct)%"
        case .hidden:
            return ""
        }
    }

    private var capsuleOpacity: Double {
        guard engine.mode == .countdown else { return 1 }
        if engine.isFinished { return 1.0 }
        if engine.displaySeconds <= Countdown.warningSeconds { return 1.0 }
        if engine.displaySeconds <= Countdown.cautionSeconds { return 0.95 }
        return 0.85
    }
}
