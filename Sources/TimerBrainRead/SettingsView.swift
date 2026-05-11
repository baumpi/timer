import SwiftUI
import AppKit

/// Hosts the app's preferences. Opens via `Settings { … }` in the App scene
/// (⌘, hotkey on macOS), and from the gear buttons in the main top bar and
/// the menu bar popover footer.
struct SettingsView: View {
    var body: some View {
        TabView {
            SoundSettingsTab()
                .tabItem { Label("Sound", systemImage: "speaker.wave.2.fill") }
            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintpalette.fill") }
            BehaviorSettingsTab()
                .tabItem { Label("Behavior", systemImage: "slider.horizontal.3") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 420)
    }
}

// MARK: - Sound

private struct SoundSettingsTab: View {
    @AppStorage(Defaults.soundEnabled)    private var soundEnabled: Bool = true
    @AppStorage(Defaults.completionSound) private var rawSound: String = CompletionSound.default.rawValue
    @AppStorage(Defaults.completionVolume) private var volume: Double = 1.0

    @State private var customLabel: String = CustomSoundStore.currentDisplayName()

    private var current: CompletionSound {
        CompletionSound(rawValue: rawSound) ?? .default
    }

    var body: some View {
        Form {
            Toggle("Play a sound when the countdown reaches zero", isOn: $soundEnabled)

            Picker("Sound", selection: $rawSound) {
                ForEach(CompletionSound.allCases) { sound in
                    Text(sound.displayName).tag(sound.rawValue)
                }
            }
            .disabled(!soundEnabled)
            .onChange(of: rawSound) { _, _ in current.play() }

            HStack {
                Text("Volume")
                Slider(value: $volume, in: 0...1)
                Text("\(Int((volume * 100).rounded()))%")
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
            .disabled(!soundEnabled)

            Section("Custom sound") {
                HStack {
                    Text(customLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Choose…") {
                        CustomSoundStore.chooseFile { imported in
                            if imported {
                                customLabel = CustomSoundStore.currentDisplayName()
                                rawSound = CompletionSound.custom.rawValue
                                CompletionSound.custom.play()
                            }
                        }
                    }
                    Button("Clear") {
                        CustomSoundStore.clear()
                        customLabel = CustomSoundStore.currentDisplayName()
                        if rawSound == CompletionSound.custom.rawValue {
                            rawSound = CompletionSound.default.rawValue
                        }
                    }
                    .disabled(CustomSoundStore.currentFileURL() == nil)
                }
                Text("AIFF, WAV, MP3, M4A or CAF. The file is copied into the app's Application Support folder so it survives moves and restarts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Test") { current.play() }
                    .disabled(!soundEnabled)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Appearance

private struct AppearanceSettingsTab: View {
    @AppStorage(Defaults.themeMode)             private var theme: ThemeMode = .dark
    @AppStorage(Defaults.menuBarOverlayEnabled) private var menuBarOverlayEnabled: Bool = true
    @AppStorage(Defaults.menuBarTintOpacity)    private var tintOpacity: Double = 1.0
    @AppStorage(Defaults.disablePulse)          private var disablePulse: Bool = false
    @AppStorage(Defaults.menuBarLabelFormat)    private var labelFormat: String = MenuBarLabelFormat.mmss.rawValue
    @AppStorage(Defaults.fontFamily)            private var fontFamily: String = FontFamily.sans.rawValue
    @AppStorage(Defaults.accentHex)             private var accentHexInt: Int = 0
    @EnvironmentObject private var tintStore: TintStore

    private var accentBinding: Binding<Color> {
        Binding(
            get: {
                accentHexInt > 0 ? Color(hex: UInt32(accentHexInt)) : .brandAccent
            },
            set: { newColor in
                accentHexInt = Int(newColor.srgbHex)
            }
        )
    }

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Mode", selection: $theme) {
                    Text("Dark").tag(ThemeMode.dark)
                    Text("Light").tag(ThemeMode.light)
                }
                .pickerStyle(.segmented)

                Picker("Font", selection: $fontFamily) {
                    ForEach(FontFamily.allCases) { f in
                        Text(f.displayName).tag(f.rawValue)
                    }
                }

                HStack {
                    ColorPicker("Accent color", selection: accentBinding, supportsOpacity: false)
                    Button("Reset") { accentHexInt = 0 }
                }
            }

            Section("Menu bar") {
                Toggle("Color the macOS menu bar with the timer tint", isOn: $menuBarOverlayEnabled)

                HStack {
                    Text("Tint opacity")
                    Slider(value: $tintOpacity, in: 0.1...1)
                    Text("\(Int((tintOpacity * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 44, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
                .disabled(!menuBarOverlayEnabled)

                Picker("Menu bar timer label", selection: $labelFormat) {
                    ForEach(MenuBarLabelFormat.allCases) { f in
                        Text(f.displayName).tag(f.rawValue)
                    }
                }

                Toggle("Disable pulsing/flashing in the final seconds", isOn: $disablePulse)
            }

            Section("Menu bar tint palette") {
                HStack(spacing: 12) {
                    ForEach(0..<TintStore.slotCount, id: \.self) { slot in
                        TintSlotChip(slot: slot)
                    }
                    Spacer()
                    Button("Edit selected…") {
                        CustomColorPickerProxy.shared.present(slot: tintStore.activeSlot, store: tintStore)
                    }
                }
                .disabled(!menuBarOverlayEnabled)
                .opacity(menuBarOverlayEnabled ? 1 : 0.4)
            }
        }
        .formStyle(.grouped)
    }
}

private struct TintSlotChip: View {
    @EnvironmentObject private var tintStore: TintStore
    let slot: Int

    var body: some View {
        let selected = tintStore.activeSlot == slot
        Button {
            if selected {
                CustomColorPickerProxy.shared.present(slot: slot, store: tintStore)
            } else {
                tintStore.setActiveSlot(slot)
            }
        } label: {
            Circle()
                .fill(tintStore.color(for: slot))
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(
                        selected ? Color.primary : Color.secondary.opacity(0.35),
                        lineWidth: selected ? 2 : 1
                    )
                )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Edit color…") {
                CustomColorPickerProxy.shared.present(slot: slot, store: tintStore)
            }
        }
        .help(selected ? "Click to edit color" : "Click to use this color")
    }
}

// MARK: - Behavior

private struct BehaviorSettingsTab: View {
    @AppStorage(Defaults.defaultCountdownDuration) private var defaultDurationSeconds: Double = Countdown.defaultSeconds
    @AppStorage(Defaults.showShortcuts) private var showShortcuts: Bool = false
    @AppStorage(Defaults.alwaysOnTop)   private var alwaysOnTop: Bool = false

    @State private var presets: [Int] = Countdown.presetsMinutesDefault
    @State private var launchEnabled: Bool = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section("Countdown") {
                LabeledContent("Default duration") {
                    DurationField(seconds: $defaultDurationSeconds)
                }
                Text("Used when a new countdown starts or you reset. Currently running timers aren't affected.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Preset buttons") {
                    HStack(spacing: 6) {
                        ForEach(presets.indices, id: \.self) { i in
                            presetField($presets[i])
                        }
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: presets) { _, _ in savePresets() }
            }

            Section("Window") {
                Toggle("Show keyboard shortcut hints in the main window", isOn: $showShortcuts)
                Toggle("Always on top", isOn: $alwaysOnTop)
            }

            Section("Login") {
                Toggle("Launch Wura Timer at login", isOn: $launchEnabled)
                    .onChange(of: launchEnabled) { _, newValue in
                        if !LaunchAtLogin.set(newValue) {
                            // System refused (e.g. user blocked in Settings).
                            // Roll the UI back to the real state.
                            launchEnabled = LaunchAtLogin.isEnabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            presets = Countdown.currentPresetMinutes()
            launchEnabled = LaunchAtLogin.isEnabled
        }
    }

    private func presetField(_ binding: Binding<Int>) -> some View {
        TextField("", value: binding, format: .number)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(width: 44)
            .fixedSize()
    }

    private func savePresets() {
        // `currentPresetMinutes()` re-clamps on read, so we can persist as-is.
        UserDefaults.standard.set(presets, forKey: Defaults.customPresetMinutes)
    }
}

/// Edits a duration as mm:ss while persisting it as seconds.
private struct DurationField: View {
    @Binding var seconds: Double
    @State private var text: String = ""

    var body: some View {
        TextField("MM:SS", text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(width: 90)
            .onAppear { text = TimerEngine.format(seconds) }
            .onSubmit { commit() }
            .onChange(of: seconds) { _, newValue in
                let formatted = TimerEngine.format(newValue)
                if formatted != text { text = formatted }
            }
    }

    private func commit() {
        if let s = TimerEngine.parseTime(text) {
            let clamped = max(Countdown.minSeconds, min(Countdown.maxSeconds, s))
            seconds = clamped
            text = TimerEngine.format(clamped)
        } else {
            text = TimerEngine.format(seconds)
        }
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    var body: some View {
        Form {
            Section("Wura Timer") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppInfo.version)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Link("Open source on GitHub", destination: AppInfo.githubURL)
                Link("Report a bug or request a feature", destination: AppInfo.bugReportURL)
            }

            Section("Settings") {
                HStack {
                    Button("Export settings…")  { SettingsBackup.exportToFile() }
                    Button("Import settings…")  { SettingsBackup.importFromFile() }
                    Spacer()
                    Button("Reset all…", role: .destructive) { SettingsBackup.resetAll() }
                }
                Text("Export saves your preferences as a JSON file. Custom sound files aren't included — re-import the sound on the new machine.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
