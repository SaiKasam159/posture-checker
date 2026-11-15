import SwiftUI

/// Lives in the full-screen click-through overlay window. Anchored to the
/// top-right corner — walks in from off the right edge, walks back out the
/// same way. Placeholder emoji character; swap for the real pixel-art sprite
/// once art is ready (see CharacterCatalog).
struct CharacterOverlayView: View {
    let state: PostureState

    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID
    @State private var xOffset: CGFloat = 160
    @State private var flashRed = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if flashRed {
                Color.red.opacity(0.25)
                    .ignoresSafeArea()
            }

            VStack(spacing: 6) {
                if case .alert = state {
                    Text("sit up!")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.75), in: Capsule())
                        .foregroundStyle(.white)
                }
                Text(CharacterCatalog.option(for: selectedCharacterID).preview)
                    .font(.system(size: 64))
                    .scaleEffect(isAlert ? 1.15 : 1.0)
            }
            .padding(.top, 36)
            .padding(.trailing, 36)
            .offset(x: xOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
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
                xOffset = 160 // walks off-screen, past the right edge
            }
            flashRed = false
        case .slouching:
            withAnimation(.easeOut(duration: 0.6)) {
                xOffset = 0 // walks on-screen, resting near the corner
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
