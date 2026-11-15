import Foundation

/// A selectable character. `preview` is an emoji placeholder until the real
/// pixel-art assets (detailed sprites with shadows) are dropped into
/// Resources — swap `preview` for an asset/image name at that point.
/// `quote` is what shows up in the overlay when the user hits `.alert` —
/// each character tells you off in their own voice.
struct CharacterOption: Identifiable, Equatable {
    let id: String
    let name: String
    let blurb: String
    let preview: String
    let quote: String
}

enum CharacterCatalog {
    /// Trimmed to Greek mythology + this fixed set of historical figures
    /// per the user's direction — the earlier roster (Trump, Putin,
    /// Wreck-It Ralph, The Soldier) was dropped, which also resolves the
    /// real-person/third-party-IP legal flags noted on that version.
    static let all: [CharacterOption] = [
        CharacterOption(id: "apollo", name: "Apollo", blurb: "The default. Watches quietly, acts when needed.", preview: "☀️", quote: "ENOUGH SLOUCHING, MORTAL."),
        CharacterOption(id: "zeus", name: "Zeus", blurb: "Thunders in. Hard to ignore.", preview: "⚡", quote: "STRAIGHTEN UP OR I STRIKE."),
        CharacterOption(id: "athena", name: "Athena", blurb: "Calm, sharp, unimpressed by your slouch.", preview: "🦉", quote: "WISDOM STARTS WITH YOUR SPINE."),
        CharacterOption(id: "aphrodite", name: "Aphrodite", blurb: "Gentle nudge, zero patience for bad posture.", preview: "🌹", quote: "SLOUCHING ISN'T A GOOD LOOK."),
        CharacterOption(id: "poseidon", name: "Poseidon", blurb: "Rolls in slow, then all at once.", preview: "🔱", quote: "RISE, BEFORE I SEND A WAVE."),
        CharacterOption(id: "hades", name: "Hades", blurb: "Shows up when you least expect it.", preview: "🔥", quote: "EVEN THE DEAD SIT UP STRAIGHTER."),
        CharacterOption(id: "agamemnon", name: "Agamemnon", blurb: "Commands you to sit up straight. Literally.", preview: "🛡️", quote: "ATTENTION! SIT UP NOW."),
        CharacterOption(id: "medusa", name: "Medusa", blurb: "One look and you'll freeze up straight.", preview: "🐍", quote: "LOOK AT ME. NOW FREEZE UP STRAIGHT."),
        CharacterOption(id: "satyr", name: "Satyr", blurb: "Mischievous. Won't let the slouch slide.", preview: "🐐", quote: "COME ON NOW, UP YOU GET."),
        CharacterOption(id: "franklin", name: "Benjamin Franklin", blurb: "An investment in your spine is the best investment.", preview: "💵", quote: "A STITCH IN TIME SAVES YOUR SPINE."),
        CharacterOption(id: "napoleon", name: "Napoleon", blurb: "Short temper for long slouches.", preview: "🎩", quote: "NOT TONIGHT. SIT UP, SOLDIER."),
        CharacterOption(id: "alexander", name: "Alexander the Great", blurb: "Conquered most of the known world. Coming for your slouch next.", preview: "🐎", quote: "CONQUER YOUR SLOUCH."),
        CharacterOption(id: "khan", name: "Genghis Khan", blurb: "Rides in fast. Leaves no slouch standing.", preview: "🐎", quote: "RIDE TALL OR DON'T RIDE AT ALL."),
    ]

    static let defaultID = "apollo"

    static func option(for id: String) -> CharacterOption {
        all.first { $0.id == id } ?? all[0]
    }
}
