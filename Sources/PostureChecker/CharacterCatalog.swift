import Foundation

/// A selectable character. `preview` is an emoji placeholder until the real
/// pixel-art assets (detailed sprites with shadows) are dropped into
/// Resources — swap `preview` for an asset/image name at that point.
struct CharacterOption: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let preview: String
}

enum CharacterCatalog {
    static let all: [CharacterOption] = [
        CharacterOption(id: "sam", name: "Slouch Sam", blurb: "The default. Chill until you're not.", preview: "🙂"),
        CharacterOption(id: "cat", name: "Lazy Cat", blurb: "Judges your posture silently.", preview: "🐱"),
        CharacterOption(id: "robot", name: "Posture Bot", blurb: "Beeps disapprovingly.", preview: "🤖"),
        CharacterOption(id: "ghost", name: "Grumpy Ghost", blurb: "Haunts your slouch.", preview: "👻"),
    ]

    static let defaultID = "sam"

    static func option(for id: String) -> CharacterOption {
        all.first { $0.id == id } ?? all[0]
    }
}
