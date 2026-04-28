import SwiftUI
import AppKit

struct BigClockView: View {
    let text: String
    var editable: Bool = false
    var onCommit: ((TimeInterval) -> Void)? = nil
    var onEditingFinished: (() -> Void)? = nil

    @Environment(\.palette) private var palette
    @State private var editing: Bool = false
    @State private var draft: String = ""
    @FocusState private var fieldFocus: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let glyphCount = CGFloat(max(text.count, 5))
            let byWidth  = (w * 0.92) / (glyphCount * 0.62)
            let byHeight = h * 0.95
            let size = min(byWidth, byHeight)

            ZStack {
                if editing {
                    TextField("MM:SS", text: $draft)
                        .textFieldStyle(.plain)
                        .font(KIFont.tech(size, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(palette.textPrimary)
                        .focused($fieldFocus)
                        .onSubmit { commit() }
                        .onExitCommand { cancel() }
                        .onChange(of: fieldFocus) { _, focused in
                            if !focused && editing { commit() }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text(text)
                        .font(KIFont.tech(size, weight: .bold))
                        .monospacedDigit()
                        .kerning(-size * 0.02)
                        .foregroundStyle(palette.textPrimary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.15), value: text)
                        .onHover { hovering in
                            if editable { hovering ? NSCursor.iBeam.push() : NSCursor.pop() }
                        }
                        .onTapGesture {
                            guard editable else { return }
                            beginEdit()
                        }
                }
            }
            .frame(width: w, height: h)
            .onChange(of: editable) { _, newValue in
                if !newValue && editing { cancel() }
            }
        }
    }

    private func beginEdit() {
        draft = ""
        editing = true
        DispatchQueue.main.async { fieldFocus = true }
    }

    private func commit() {
        if !draft.isEmpty, let secs = TimerEngine.parseTime(draft) {
            onCommit?(secs)
        }
        finishEditing()
    }

    private func cancel() {
        finishEditing()
    }

    private func finishEditing() {
        editing = false
        fieldFocus = false
        if editable { NSCursor.pop() }
        onEditingFinished?()
    }
}
