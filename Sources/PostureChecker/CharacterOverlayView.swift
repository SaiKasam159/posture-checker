import SwiftUI

/// Placeholder character. Swap the shape/art once design is settled —
/// the walk-on/walk-off/yell state machine below is what matters for now.
struct CharacterOverlayView: View {
    let state: PostureState

    @State private var xOffset: CGFloat = 300
    @State private var flashRed = false

    var body: some View {
        ZStack {
            if flashRed {
                Color.red.opacity(0.25)
                    .ignoresSafeArea()
            }

            VStack(spacing: 6) {
                if case .alert = state {
                    Text("sit up!")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.black.opacity(0.75), in: Capsule())
                        .foregroundStyle(.white)
                }
                Text("🙂")
                    .font(.system(size: 64))
                    .scaleEffect(isAlert ? 1.15 : 1.0)
            }
            .offset(x: xOffset)
        }
        .onChange(of: state) { newState in
            update(for: newState)
        }
        .onAppear {
            update(for: state)
        }
    }

    private var isAlert: Bool {
        if case .alert = state { return true }
        return false
    }

    private func update(for state: PostureState) {
        switch state {
        case .good:
            withAnimation(.easeInOut(duration: 0.6)) {
                xOffset = 300 // walks off-screen
            }
            flashRed = false
        case .slouching:
            withAnimation(.easeOut(duration: 0.6)) {
                xOffset = 0 // walks on-screen
            }
            flashRed = false
        case .alert:
            withAnimation(.easeOut(duration: 0.3)) {
                xOffset = 0
            }
            flashRed = true
        }
    }
}

#Preview {
    CharacterOverlayView(state: .slouching(seconds: 4))
        .frame(width: 400, height: 200)
        .background(.gray.opacity(0.2))
}
