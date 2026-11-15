import SwiftUI

/// Apollo's palette: black, grey, white only — no system blue accent anywhere.
/// Visual language is deliberately pixelated/retro to match the character
/// art style: monospaced type, hard square corners, no blur or gradients,
/// stepped double borders instead of soft shadows.
enum Theme {
    static let background = Color.black
    static let surface = Color(white: 0.13)
    static let surfaceSelected = Color(white: 0.22)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.65)
    static let divider = Color(white: 0.28)
    static let accent = Color.white

    /// A true 8-bit "Press Start 2P"-style font isn't bundled (no font file
    /// in the project yet — drop one into Resources and swap this to
    /// `.custom(name, size: size)` once it exists). Until then, the system
    /// monospaced design gets us most of the way: fixed-width, blocky,
    /// reads as "retro" rather than "default app font."
    static func pixelFont(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// Square-cornered, double-outlined panel. Stands in for rounded
/// cards/capsules elsewhere in SwiftUI — pixel art doesn't do soft corners.
struct PixelPanel: ViewModifier {
    var fill: Color = Theme.surface
    var borderColor: Color = Theme.textPrimary

    func body(content: Content) -> some View {
        content
            .background(fill)
            .overlay(
                Rectangle()
                    .strokeBorder(borderColor, lineWidth: 2)
            )
            .overlay(
                Rectangle()
                    .strokeBorder(borderColor.opacity(0.35), lineWidth: 1)
                    .padding(3)
            )
    }
}

extension View {
    func pixelPanel(fill: Color = Theme.surface, border: Color = Theme.textPrimary) -> some View {
        modifier(PixelPanel(fill: fill, borderColor: border))
    }
}

/// Blocky button chrome: square corners, solid fill, no shadow. Press state
/// just nudges down a pixel instead of easing/fading.
struct PixelButtonStyle: ButtonStyle {
    var fill: Color = Theme.accent
    var textColor: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.pixelFont(13))
            .foregroundStyle(textColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(fill)
            .overlay(Rectangle().strokeBorder(Theme.textPrimary, lineWidth: 2))
            .offset(y: configuration.isPressed ? 2 : 0)
    }
}
