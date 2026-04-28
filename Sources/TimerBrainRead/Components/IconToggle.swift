import SwiftUI

/// Unified icon button used for all top-bar toggles (pin, mini, theme, loop, help).
///
/// - Pass just `symbol` for a square icon-only toggle (30×30).
/// - Pass `symbol` + `label` for a pill with icon and uppercase label.
/// - Pass `activeSymbol` if the icon should change when `isOn`.
/// - `accentWhenOn = true` colors the toggle in brand-red when active.
struct IconToggle: View {
    @Binding var isOn: Bool
    let symbol: String
    var activeSymbol: String? = nil
    var label: String? = nil
    var accentWhenOn: Bool = true
    var help: String = ""

    @Environment(\.palette) private var palette
    @State private var isHovering = false

    var body: some View {
        Button { isOn.toggle() } label: {
            content
                .background(background)
                .foregroundStyle(foreground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(palette.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .animation(.easeOut(duration: Layout.hoverAnimDuration), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(help)
    }

    @ViewBuilder
    private var content: some View {
        if let label {
            HStack(spacing: 8) {
                icon
                Text(label)
                    .font(KIFont.tech(11, weight: .bold))
                    .tracking(2.0)
            }
            .padding(.horizontal, Layout.toggleLabelPaddingX)
            .padding(.vertical, Layout.toggleLabelPaddingY)
        } else {
            icon.frame(width: Layout.toggleIconSize, height: Layout.toggleIconSize)
        }
    }

    private var icon: some View {
        Image(systemName: (isOn ? activeSymbol : nil) ?? symbol)
            .font(.system(size: Layout.iconFontSize, weight: .semibold))
    }

    private var cornerRadius: CGFloat {
        label == nil ? Layout.cornerRadiusSm : Layout.cornerRadiusMd
    }

    private var background: Color {
        if isOn && accentWhenOn { return palette.toggleActiveBG }
        return isHovering ? palette.bgCard : palette.bgSurface
    }

    private var foreground: Color {
        if isOn && accentWhenOn { return palette.accentText }
        // Labeled pills look nicer with a slightly muted text; icon-only with secondary.
        return label == nil ? palette.textSecondary : palette.textMuted
    }
}
