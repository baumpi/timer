import SwiftUI

struct MenuBarTimerLabel: View {
    // ObservedObject (not EnvironmentObject) because MenuBarExtra's `label:`
    // closure renders outside any `.environmentObject(...)` propagation.
    @ObservedObject var engine: TimerEngine

    private static let barWidth: CGFloat = 42
    private static let barHeight: CGFloat = 6
    private static let digitsSize: CGFloat = 14
    private static let flashWindowSeconds: TimeInterval = 3

    @State private var pulsePhase: Double = 0

    private var shouldFlash: Bool {
        engine.mode == .countdown
            && engine.isRunning
            && engine.displaySeconds > 0
            && engine.displaySeconds <= Self.flashWindowSeconds
    }

    var body: some View {
        HStack(spacing: 7) {
            leadingIndicator
            digits
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
                .fill(Color.brandAccent.opacity(min(1.0, capsuleOpacity + pulsePhase * 0.35)))
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
            .fill(engine.isRunning ? Color.brandAccent : Color.secondary.opacity(0.6))
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.primary.opacity(0.25), lineWidth: 0.5))
    }

    private var digits: some View {
        Text(TimerEngine.format(engine.displaySeconds))
            .font(.system(size: Self.digitsSize, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
    }

    private var capsuleOpacity: Double {
        guard engine.mode == .countdown else { return 1 }
        if engine.isFinished { return 1.0 }
        if engine.displaySeconds <= Countdown.warningSeconds { return 1.0 }
        if engine.displaySeconds <= Countdown.cautionSeconds { return 0.95 }
        return 0.85
    }
}
