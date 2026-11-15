import Foundation

/// A selectable character. `preview` is an emoji placeholder until the real
/// pixel-art assets (detailed sprites with shadows) are dropped into
/// Resources — swap `preview` for an asset/image name at that point.
///
/// NOTE on this roster: several entries are real public figures (Trump,
/// Putin) or third-party IP (Wreck-It Ralph is Disney's). They're kept here
/// as placeholders for prototyping only. Before any real art ships:
/// - Trump/Putin carry right-of-publicity and App Store policy risk around
///   depicting real political leaders — get legal eyes on it first.
/// - Wreck-It Ralph needs to become an original redesign, not a likeness
///   of Disney's character, or it's copyright/trademark infringement.
/// - "German Soldier" needs careful, deliberately non-Nazi-adjacent art
///   direction; Apple explicitly bars that imagery.
struct CharacterOption: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let preview: String
}

enum CharacterCatalog {
    static let all: [CharacterOption] = [
        CharacterOption(id: "apollo", name: "Apollo", blurb: "The default. Watches quietly, acts when needed.", preview: "☀️"),
        CharacterOption(id: "zeus", name: "Zeus", blurb: "Thunders in. Hard to ignore.", preview: "⚡"),
        CharacterOption(id: "athena", name: "Athena", blurb: "Calm, sharp, unimpressed by your slouch.", preview: "🦉"),
        CharacterOption(id: "aphrodite", name: "Aphrodite", blurb: "Gentle nudge, zero patience for bad posture.", preview: "🌹"),
        CharacterOption(id: "poseidon", name: "Poseidon", blurb: "Rolls in slow, then all at once.", preview: "🔱"),
        CharacterOption(id: "hades", name: "Hades", blurb: "Shows up when you least expect it.", preview: "🔥"),
        CharacterOption(id: "agamemnon", name: "Agamemnon", blurb: "Commands you to sit up straight. Literally.", preview: "🛡️"),
        CharacterOption(id: "medusa", name: "Medusa", blurb: "One look and you'll freeze up straight.", preview: "🐍"),
        CharacterOption(id: "satyr", name: "Satyr", blurb: "Mischievous. Won't let the slouch slide.", preview: "🐐"),
        CharacterOption(id: "escobar", name: "Pablo Escobar", blurb: "Runs a tight operation. Posture included.", preview: "🕶️"),
        CharacterOption(id: "franklin", name: "Benjamin Franklin", blurb: "An investment in your spine is the best investment.", preview: "💵"),
        CharacterOption(id: "napoleon", name: "Napoleon", blurb: "Short temper for long slouches.", preview: "🎩"),
        CharacterOption(id: "ramsay", name: "Gordon Ramsay", blurb: "This posture is RAW.", preview: "🔪"),
        CharacterOption(id: "ralph", name: "Wreck-It Ralph", blurb: "Wrecks your slouch, not your day.", preview: "🔨"),
        CharacterOption(id: "godfather", name: "The Godfather", blurb: "Makes your spine an offer it can't refuse.", preview: "🕴️"),
        CharacterOption(id: "trump", name: "Donald Trump", blurb: "Says your posture is the worst he's ever seen. Tremendous potential though.", preview: "🦅"),
        CharacterOption(id: "putin", name: "Vladimir Putin", blurb: "Stares. Says nothing. You sit up anyway.", preview: "🐻"),
        CharacterOption(id: "alexander", name: "Alexander the Great", blurb: "Conquered most of the known world. Coming for your slouch next.", preview: "🐎"),
        CharacterOption(id: "khan", name: "Genghis Khan", blurb: "Rides in fast. Leaves no slouch standing.", preview: "🐎"),
        CharacterOption(id: "soldier", name: "The Soldier", blurb: "At ease. Well, almost. Sit up first.", preview: "🪖"),
    ]

    static let defaultID = "apollo"

    static func option(for id: String) -> CharacterOption {
        all.first { $0.id == id } ?? all[0]
    }
}
