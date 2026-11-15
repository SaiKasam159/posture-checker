import SwiftUI

/// Grid of selectable characters. Shared between onboarding and the
/// settings popover so there's one place that defines "what does picking a
/// character look like."
struct CharacterPickerView: View {
    @Binding var selectedID: String

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CharacterCatalog.all) { option in
                CharacterTile(option: option, isSelected: option.id == selectedID)
                    .onTapGesture { selectedID = option.id }
            }
        }
    }
}

private struct CharacterTile: View {
    let option: CharacterOption
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(option.preview)
                .font(.system(size: 40))
            Text(option.name)
                .font(.caption.bold())
                .multilineTextAlignment(.center)
            Text(option.blurb)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
        .frame(width: 104, height: 110)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    CharacterPickerView(selectedID: .constant("sam"))
        .padding()
}
