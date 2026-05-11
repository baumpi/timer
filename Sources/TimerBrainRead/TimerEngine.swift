import SwiftUI
import AppKit
import Combine

enum TimerMode: String, CaseIterable, Identifiable {
    case stopwatch
    case countdown
    var id: String { rawValue }
    var label: String {
        switch self {
        case .stopwatch: return "STOPWATCH"
        case .countdown: return "COUNTDOWN"
        }
    }
}

struct StopwatchLap: Identifiable, Equatable {
    let id = UUID()
    let index: Int
    let total: TimeInterval
    let split: TimeInterval
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published var mode: TimerMode = .stopwatch {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: Defaults.timerMode)
            reset()
        }
    }
    @Published var repeats: Bool = false {
        didSet {
            UserDefaults.standard.set(repeats, forKey: Defaults.countdownRepeats)
        }
    }
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var displaySeconds: TimeInterval = 0
    @Published private(set) var laps: [StopwatchLap] = []
    @Published private(set) var completionCount: Int = 0
    @Published private(set) var isFinished: Bool = false

    @Published private var _countdownDuration: TimeInterval = Countdown.defaultSeconds
    var countdownDuration: TimeInterval {
        get { _countdownDuration }
        set {
            let clamped = max(Countdown.minSeconds, min(newValue, Countdown.maxSeconds))
            guard clamped != _countdownDuration else { return }
            _countdownDuration = clamped
            UserDefaults.standard.set(clamped, forKey: Defaults.countdownDuration)
            if !isRunning && mode == .countdown {
                isFinished = false
                displaySeconds = clamped
            }
        }
    }

    /// Fraction of countdown time remaining (1 = full, 0 = empty).
    /// Returns 1 when not in countdown mode or duration is invalid.
    var countdownRemainingRatio: Double {
        guard mode == .countdown, _countdownDuration > 0 else { return 1 }
        return max(0, min(1, displaySeconds / _countdownDuration))
    }

    init() {
        let defaults = UserDefaults.standard

        let savedDuration = defaults.double(forKey: Defaults.countdownDuration)
        if savedDuration >= Countdown.minSeconds && savedDuration <= Countdown.maxSeconds {
            self._countdownDuration = savedDuration
        } else {
            // Fall back to the user's configured default if no per-session
            // value has been persisted yet.
            let defaultDuration = defaults.double(forKey: Defaults.defaultCountdownDuration)
            if defaultDuration >= Countdown.minSeconds && defaultDuration <= Countdown.maxSeconds {
                self._countdownDuration = defaultDuration
            }
        }

        // Only assign when the persisted value differs from the property's
        // default — otherwise we'd trigger didSet (and a no-op UserDefaults
        // write-back + reset()) on every launch.
        if let raw = defaults.string(forKey: Defaults.timerMode),
           let saved = TimerMode(rawValue: raw),
           saved != mode {
            self.mode = saved   // didSet → reset() → seeds displaySeconds
        }
        if defaults.object(forKey: Defaults.countdownRepeats) != nil {
            let saved = defaults.bool(forKey: Defaults.countdownRepeats)
            if saved != repeats { self.repeats = saved }
        }
    }

    private var startedAt: Date?
    private var accumulated: TimeInterval = 0
    private var ticker: Timer?

    func toggle() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if mode == .countdown && displaySeconds <= 0 {
            displaySeconds = countdownDuration
            accumulated = 0
        }
        isFinished = false
        startedAt = Date()
        isRunning = true
        scheduleTicker()
    }

    func pause() {
        guard isRunning else { return }
        if let s = startedAt {
            accumulated += Date().timeIntervalSince(s)
        }
        startedAt = nil
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        recompute()
    }

    func reset() {
        ticker?.invalidate()
        ticker = nil
        startedAt = nil
        accumulated = 0
        isRunning = false
        isFinished = false
        laps.removeAll()
        switch mode {
        case .stopwatch: displaySeconds = 0
        case .countdown: displaySeconds = countdownDuration
        }
    }

    func adjustCountdown(by deltaSeconds: TimeInterval) {
        guard mode == .countdown, !isRunning else { return }
        countdownDuration += deltaSeconds
    }

    func recordLap() {
        guard mode == .stopwatch else { return }
        recompute()
        guard displaySeconds > 0 else { return }
        let previousTotal = laps.first?.total ?? 0
        guard displaySeconds > previousTotal else { return }
        let lap = StopwatchLap(
            index: laps.count + 1,
            total: displaySeconds,
            split: max(0, displaySeconds - previousTotal)
        )
        laps.insert(lap, at: 0)
    }

    func applyPreset(minutes: Int) {
        setCountdown(seconds: TimeInterval(minutes * 60))
    }

    private func scheduleTicker() {
        ticker?.invalidate()
        let t = Timer(timeInterval: Tick.interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.recompute() }
        }
        RunLoop.main.add(t, forMode: .common)
        ticker = t
    }

    private func recompute() {
        let liveDelta = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        let elapsed = accumulated + liveDelta
        switch mode {
        case .stopwatch:
            setDisplaySeconds(elapsed.rounded(.down))
        case .countdown:
            let remaining = countdownDuration - elapsed
            if remaining <= 0 {
                setDisplaySeconds(0)
                if isRunning { finishCountdown(elapsed: elapsed) }
            } else {
                setDisplaySeconds(remaining.rounded(.up))
            }
        }
    }

    private func finishCountdown(elapsed: TimeInterval) {
        completionCount += 1
        playCompletionSoundIfEnabled()
        if repeats {
            let duration = max(Countdown.minSeconds, countdownDuration)
            let remainder = elapsed.truncatingRemainder(dividingBy: duration)
            accumulated = remainder
            startedAt = Date()
            setDisplaySeconds((duration - remainder).rounded(.up))
        } else {
            ticker?.invalidate()
            ticker = nil
            startedAt = nil
            isRunning = false
            accumulated = 0
            isFinished = true
        }
    }

    private func playCompletionSoundIfEnabled() {
        // Live next to the timer rather than a SwiftUI .onChange observer
        // because the observer only fires while its host view is on screen.
        // Driving the timer from the menu bar with the main window closed
        // would otherwise produce no sound.
        let defaults = UserDefaults.standard
        let enabled = defaults.object(forKey: Defaults.soundEnabled) as? Bool ?? true
        guard enabled else { return }
        CompletionSound.current().play()
    }

    private func setDisplaySeconds(_ seconds: TimeInterval) {
        let value = max(0, seconds)
        guard value != displaySeconds else { return }
        displaySeconds = value
    }

    /// Set the countdown duration directly from a parsed time. Only effective when paused.
    func setCountdown(seconds: TimeInterval) {
        guard mode == .countdown, !isRunning else { return }
        countdownDuration = seconds
        accumulated = 0
        isFinished = false
        displaySeconds = countdownDuration
    }

    /// Parse a time string into seconds. Designed to be maximally permissive:
    ///   "5:30"   → 5 min 30 sec
    ///   "5:"     → 5 min
    ///   ":30"    → 30 sec
    ///   "0:90"   → 90 sec    (seconds can exceed 59; normalized via total)
    ///   "10"     → 10 sec    (1–2 digits = pure seconds, including 60–99)
    ///   "60"     → 60 sec
    ///   "100"    → 1 min     (3+ digits = MM:SS packed)
    ///   "1230"   → 12 min 30 sec
    ///   "00:10"  → 10 sec
    /// Returns nil only if the input is empty, non-numeric, or the resulting
    /// total falls outside `Countdown.minSeconds…Countdown.maxSeconds`.
    static func parseTime(_ s: String) -> TimeInterval? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let total: TimeInterval
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { return nil }
            let mmStr = parts[0].isEmpty ? "0" : parts[0]
            let ssStr = parts[1].isEmpty ? "0" : parts[1]
            guard let mm = Int(mmStr), let ss = Int(ssStr),
                  mm >= 0, ss >= 0 else { return nil }
            total = TimeInterval(mm * 60 + ss)
        } else {
            let digits = trimmed.filter(\.isNumber)
            guard digits.count == trimmed.count, !digits.isEmpty else { return nil }

            if digits.count <= 2 {
                // 1–2 digit input is always pure seconds. "60" → 60s, "99" → 99s.
                guard let secs = Int(digits) else { return nil }
                total = TimeInterval(secs)
            } else {
                // 3+ digits: last 4 digits packed as MMSS.
                let padded = digits.count >= 4 ? String(digits.suffix(4))
                                               : String(repeating: "0", count: 4 - digits.count) + digits
                guard let mm = Int(padded.prefix(2)),
                      let ss = Int(padded.suffix(2)) else { return nil }
                total = TimeInterval(mm * 60 + ss)
            }
        }

        guard total >= Countdown.minSeconds, total <= Countdown.maxSeconds else { return nil }
        return total
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.down)))
        if s >= 3600 {
            let h = s / 3600
            let m = (s % 3600) / 60
            let sec = s % 60
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        let m = s / 60
        let sec = s % 60
        return String(format: "%02d:%02d", m, sec)
    }
}
