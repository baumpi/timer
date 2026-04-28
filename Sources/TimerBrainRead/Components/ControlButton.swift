import SwiftUI

enum ControlVariant {
    case primary
    case secondary
}

struct ControlButton: View {
    let title: String
    var variant: ControlVariant = .secondary
    var minWidth: CGFloat = 160
    let action: () -> Void

    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KIFont.human(20, weight: .semibold))
                .tracking(0.5)
                .frame(minWidth: minWidth, minHeight: 64)
                .padding(.horizontal, 28)
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(KIButtonStyle(variant: variant, palette: palette))
    }
}

private struct KIButtonStyle: ButtonStyle {
    let variant: ControlVariant
    let palette: Palette

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(variant: variant, palette: palette, configuration: configuration)
    }

    private struct StyledLabel: View {
        let variant: ControlVariant
        let palette: Palette
        let configuration: Configuration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .background(background)
                .foregroundStyle(foreground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: isHovering)
                .onHover { isHovering = $0 }
        }

        private var background: Color {
            switch variant {
            case .primary:
                return isHovering ? palette.accentHover : palette.accent
            case .secondary:
                return isHovering ? palette.bgCard : palette.bgSurface
            }
        }
        private var foreground: Color {
            variant == .primary ? .white : palette.textPrimary
        }
        private var borderColor: Color {
            variant == .primary ? .clear : palette.border
        }
    }
}
