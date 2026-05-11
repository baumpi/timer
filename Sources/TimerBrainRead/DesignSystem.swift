import SwiftUI
import AppKit

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// Round-trip a Color through sRGB and pack into `0xRRGGBB`. Used to persist
    /// the user-picked menu bar tint in UserDefaults via @AppStorage<Int>.
    var srgbHex: UInt32 {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .gray
        let clamp: (CGFloat) -> UInt32 = { UInt32(max(0, min(255, Int($0 * 255)))) }
        return (clamp(ns.redComponent) << 16)
             | (clamp(ns.greenComponent) << 8)
             |  clamp(ns.blueComponent)
    }

    /// Brand accent. Theme-independent — used by menu bar surfaces that render
    /// outside the `\.palette` environment (status item label, accents).
    static let brandAccent = Color(hex: 0xC41E3A)

    /// The user-configured accent color, or the brand accent if unset. Used by
    /// surfaces outside the `\.palette` environment (menu bar label, status
    /// dot) so they share a single source of truth.
    static var currentAccent: Color {
        let raw = UserDefaults.standard.integer(forKey: Defaults.accentHex)
        return raw > 0 ? Color(hex: UInt32(raw)) : .brandAccent
    }
}

enum ThemeMode: String, CaseIterable {
    case dark, light
    var label: String { self == .dark ? "DARK" : "LIGHT" }
    var systemSymbol: String { self == .dark ? "moon.fill" : "sun.max.fill" }
    var nsAppearance: NSAppearance? {
        NSAppearance(named: self == .dark ? .darkAqua : .aqua)
    }
}

struct Palette {
    let bgApp: Color
    let bgSurface: Color
    let bgCard: Color

    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    let accent: Color
    let accentHover: Color
    let accentText: Color
    let accentSoft: Color

    let border: Color
    let toggleActiveBG: Color

    let nsBackground: NSColor

    static func from(_ mode: ThemeMode) -> Palette {
        let accentRaw = UserDefaults.standard.integer(forKey: Defaults.accentHex)
        let hex: UInt32 = accentRaw > 0 ? UInt32(accentRaw) : 0xC41E3A
        return mode == .light ? makeLight(accentHex: hex) : makeDark(accentHex: hex)
    }

    private static func makeDark(accentHex hex: UInt32) -> Palette {
        Palette(
            bgApp:          Color(hex: 0x1F1E1C),
            bgSurface:      Color(hex: 0x252321),
            bgCard:         Color(hex: 0x2A2826),
            textPrimary:    Color(hex: 0xFAFAF7),
            textSecondary:  Color(hex: 0x9B9B9B),
            textMuted:      Color(hex: 0x6B6B6B),
            accent:         Color(hex: hex),
            accentHover:    Color(hex: hex.scaled(0.82)),
            accentText:     Color(hex: hex.scaled(1.25)),
            accentSoft:     Color(hex: hex, opacity: 0.18),
            border:         Color.white.opacity(0.06),
            toggleActiveBG: Color(hex: hex, opacity: 0.18),
            nsBackground:   NSColor(red: 0x1F/255, green: 0x1E/255, blue: 0x1C/255, alpha: 1)
        )
    }

    private static func makeLight(accentHex hex: UInt32) -> Palette {
        Palette(
            bgApp:          Color(hex: 0xFAFAF7),
            bgSurface:      Color(hex: 0xF2F0EC),
            bgCard:         Color(hex: 0xFFFFFF),
            textPrimary:    Color(hex: 0x3D3D3D),
            textSecondary:  Color(hex: 0x6B6B6B),
            textMuted:      Color(hex: 0x9B9B9B),
            accent:         Color(hex: hex),
            accentHover:    Color(hex: hex.scaled(0.82)),
            accentText:     Color(hex: hex),
            accentSoft:     Color(hex: hex, opacity: 0.14),
            border:         Color(hex: 0xE8E5DF),
            toggleActiveBG: Color(hex: hex, opacity: 0.14),
            nsBackground:   NSColor(red: 0xFA/255, green: 0xFA/255, blue: 0xF7/255, alpha: 1)
        )
    }
}

private extension UInt32 {
    /// Multiply each 8-bit RGB component by `factor`, clamped to 0...255.
    /// Used to brighten / darken an accent color while keeping the same hue.
    func scaled(_ factor: Double) -> UInt32 {
        let clamp: (Double) -> UInt32 = { v in
            UInt32(Swift.max(0.0, Swift.min(255.0, v.rounded())))
        }
        let r = Double((self >> 16) & 0xFF) * factor
        let g = Double((self >> 8)  & 0xFF) * factor
        let b = Double( self        & 0xFF) * factor
        return (clamp(r) << 16) | (clamp(g) << 8) | clamp(b)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue: Palette = .from(.dark)
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

enum FontFamily: String, CaseIterable, Identifiable {
    case sans       // Inter (default)
    case mono       // JetBrains Mono
    case system     // SF / system

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sans:   return "Inter (sans)"
        case .mono:   return "JetBrains Mono"
        case .system: return "System"
        }
    }

    static var current: FontFamily {
        let raw = UserDefaults.standard.string(forKey: Defaults.fontFamily)
        return raw.flatMap(FontFamily.init(rawValue:)) ?? .sans
    }
}

enum KIFont {
    static func human(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch FontFamily.current {
        case .system:
            return .system(size: size, weight: weight)
        case .mono:
            return tech(size, weight: weight)
        case .sans:
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "Inter-Bold"
            case .semibold, .medium:    name = "Inter-SemiBold"
            default:                    name = "Inter-Regular"
            }
            return Font.custom(name, size: size)
        }
    }

    static func tech(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch FontFamily.current {
        case .system:
            return .system(size: size, weight: weight, design: .monospaced)
        case .sans, .mono:
            let name: String
            switch weight {
            case .bold, .heavy, .black: name = "JetBrainsMono-Bold"
            case .regular, .light:      name = "JetBrainsMono-Regular"
            default:                    name = "JetBrainsMono-Medium"
            }
            return Font.custom(name, size: size)
        }
    }
}

enum BundledFonts {
    static func register() {
        guard let resourceURL = Bundle.main.resourceURL else { return }
        let fontsDir = resourceURL.appendingPathComponent("fonts")
        let files = (try? FileManager.default.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil)) ?? []
        for url in files where ["otf", "ttf"].contains(url.pathExtension.lowercased()) {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
