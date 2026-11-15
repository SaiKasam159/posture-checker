import SwiftUI

/// Grid of selectable characters. Shared between onboarding and the
/// settings popover so there's one place that defines "what does picking a
/// character look like." 20 characters now, so this scrolls rather than
/// growing the parent view unbounded.
struct CharacterPickerView: View {
    @Binding var selectedID: String
    var maxHeight: CGFloat = 240

    private let columns = [GridItem(.adaptive(minimum: 96, maximum: 112), spacing: 10)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(CharacterCatalog.all) { option in
                    CharacterTile(option: option, isSelected: option.id == selectedID)
                        .onTapGesture { selectedID = option.id }
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: maxHeight)
    }
}

private struct CharacterTile: View {
    let option: CharacterOption
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Text(option.preview)
                .font(.system(size: 34))
            Text(option.name)
                .font(Theme.pixelFont(9))
                .foregroundStyle(Theme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(option.blurb)
                .font(Theme.pixelFont(7, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(8)
        .frame(width: 100, height: 112)
        .pixelPanel(
            fill: isSelected ? Theme.surfaceSelected : Theme.surface,
            border: isSelected ? Theme.textPrimary : Theme.divider
        )
    }
}

#Preview {
    CharacterPickerView(selectedID: .constant("apollo"))
        .padding()
        .background(Theme.background)
}
