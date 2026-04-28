# Wura Timer

Bühnen-Timer im KI-Austria-Look. Native macOS-App (Apple Silicon), riesige Ziffern, drei klare Buttons.

## Installieren

1. `build/Wura Timer.dmg` doppelklicken.
2. Im Fenster die App auf **Applications** ziehen.
3. DMG auswerfen.
4. **Erster Start (Gatekeeper-Hinweis):** Da die App ad-hoc signiert ist (kein Apple-Developer-Zertifikat), kommt beim ersten Öffnen "Wura Timer konnte nicht geprüft werden". → **Rechtsklick** auf die App → **Öffnen** → **Öffnen** bestätigen. Danach läuft sie immer normal.

> Falls du die alte "Timer BrainRead.app" noch im Applications-Ordner hast: einfach in den Papierkorb. Die neue App hat einen anderen Bundle Identifier (`at.wura.timer`), läuft also unabhängig daneben.

## Features

- **Stopwatch** und **Countdown** umschaltbar (oben links).
- **Light/Dark-Toggle** oben rechts (☀ LIGHT / ☾ DARK), Einstellung wird gemerkt.
- Riesige MM:SS-Ziffern in JetBrains Mono — skaliert mit Fenster, projector-ready.
- Countdown wird in der letzten Minute rot. Bei 00:00 pulsiert der Rahmen + System-Sound.
- Alle Farben/Fonts aus dem KI-Austria-Design-Kit v3.

## Tastatur

| Taste     | Aktion             |
|-----------|--------------------|
| `Space`   | Start / Stop       |
| `R`       | Reset              |
| `F`       | Vollbild           |
| `L`       | Light/Dark wechseln|
| `+` / `-` | Countdown ±1 min   |

`⌃⌘F` (Standard-Vollbild via Ampel-Button) geht ebenfalls.

## Aus dem Source neu bauen

Voraussetzung: macOS Command Line Tools (`xcode-select --install`). Kein Xcode nötig.

```bash
./scripts/build.sh        # → build/Wura Timer.app
./scripts/make-dmg.sh     # → build/Wura Timer.dmg
```

App-Icon neu rendern:

```bash
mkdir -p build/AppIcon.iconset
swift scripts/make-icon.swift build/AppIcon.iconset Resources/fonts/JetBrainsMono-Bold.ttf
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
./scripts/build.sh
```

## Projektstruktur

```
Sources/TimerBrainRead/
├── TimerBrainReadApp.swift   @main entry
├── ContentView.swift         Layout + Tastatur (.onKeyPress) + Window-Styling
├── TimerEngine.swift         Stopwatch- + Countdown-Logik
├── DesignSystem.swift        KI-Austria Palette (dark + light), Fonts
└── Components/
    ├── BigClockView.swift    Auto-skalierende MM:SS-Anzeige
    ├── ControlButton.swift   Primary/Secondary Button (ButtonStyle)
    └── ModeToggle.swift      Stopwatch↔Countdown + Theme-Toggle
Resources/
├── Info.plist
├── AppIcon.icns
└── fonts/                    Inter + JetBrains Mono (im App-Bundle)
scripts/
├── build.sh
├── make-dmg.sh
└── make-icon.swift
```

> Hinweis: Der interne Swift-Target-Name bleibt `TimerBrainRead` (Verzeichnis & Executable). Nur die Bundle-Daten (`CFBundleName`, Display, DMG, Window-Titel) sind "Wura Timer".
