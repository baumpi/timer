import SwiftUI

/// Two-segment selector for stopwatch ↔ countdown.
struct ModeToggle: View {
    @Binding var mode: TimerMode
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TimerMode.allCases) { m in
                Button {
                    if mode != m { mode = m }
                } label: {
                    Text(m.label)
                        .font(KIFont.tech(11, weight: .bold))
                        .tracking(2.0)
                        .padding(.horizontal, 18)
                        .padding(.vertical, Layout.toggleLabelPaddingY)
                        .frame(minWidth: 130)
                        .background(mode == m ? palette.toggleActiveBG : Color.clear)
                        .foregroundStyle(mode == m ? palette.accentText : palette.textMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(palette.bgSurface)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.cornerRadiusMd)
                .stroke(palette.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadiusMd))
    }
}
