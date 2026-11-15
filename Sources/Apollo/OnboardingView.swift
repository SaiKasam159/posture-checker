import SwiftUI

/// Shown once, the first time the app launches. Explains what Apollo does,
/// why it's worth leaving on, how the controls work, and lets the user pick
/// a character before the app settles into the menu bar.
struct OnboardingView: View {
    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID
    @State private var page = 0
    let onFinish: () -> Void

    private let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                whyItMattersPage.tag(1)
                howItWorksPage.tag(2)
                controlsPage.tag(3)
                characterPage.tag(4)
            }
            .tabViewStyle(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                pageDots
                Spacer()
                if page > 0 {
                    Button("Back") { page -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.textSecondary)
                }
                Button(page == pageCount - 1 ? "Get Started" : "Next") {
                    if page == pageCount - 1 {
                        onFinish()
                    } else {
                        page += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .foregroundStyle(.black)
            }
            .padding(20)
        }
        .frame(width: 500, height: 580)
        .background(Theme.background)
        .foregroundStyle(Theme.textPrimary)
        .preferredColorScheme(.dark)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Theme.textPrimary : Theme.divider)
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var welcomePage: some View {
        OnboardingPage(
            icon: "sun.max.fill",
            title: "Apollo",
            body: "Named for the god of good physique, Apollo is the thing standing between you and another three-hour slouch you won't remember starting. It stays invisible until you need it. Then it walks right onto your screen and makes you deal with it."
        )
    }

    private var whyItMattersPage: some View {
        OnboardingPage(
            icon: "flame.fill",
            title: "Why it matters",
            customBody: {
                VStack(alignment: .leading, spacing: 14) {
                    Text("You know the feeling. Hour two of studying, your spine's given up, your eyes are glazed, and you can't remember the last three paragraphs you read. That's not just you being tired. Your posture is part of it.")
                        .font(.body)
                        .foregroundStyle(Theme.textPrimary)

                    ProofLine(text: "Research links upright sitting to better mood and lower fatigue than slouched sitting, and tired, flat mood is exactly what kills a study session.")
                    ProofLine(text: "Studies on posture and memory have found slouched positions change how easily people recall what they just took in, compared to sitting upright.")
                    ProofLine(text: "This isn't a miracle cure. The science on posture and raw focus is still mixed. But stacking small physical wins, like sitting up and catching the slump before it becomes an hour, is one of the few study habits that costs you nothing to try.")

                    Text("Apollo's job is to catch the slouch before it becomes the whole afternoon.")
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.top, 4)
                }
            }
        )
    }

    private var howItWorksPage: some View {
        OnboardingPage(
            icon: "camera.fill",
            title: "How it works",
            body: "Your webcam tracks your head and shoulders to score your posture. Everything is processed entirely on your device, and nothing is ever recorded or sent anywhere. You'll calibrate once against how you actually sit, at whatever angle your camera sees you."
        )
    }

    private var controlsPage: some View {
        OnboardingPage(
            icon: "slider.horizontal.3",
            title: "The controls",
            customBody: {
                VStack(alignment: .leading, spacing: 14) {
                    ControlExplainer(title: "Menu bar icon", detail: "Click it any time to open settings. No Dock icon, no main window. It just lives up there.")
                    ControlExplainer(title: "Recalibrate", detail: "Resets your \"good posture\" baseline to how you're sitting right now. Use it if you change chairs, camera angle, or setup.")
                    ControlExplainer(title: "Sensitivity", detail: "How many seconds of slouching before the character shows up. Lower = quicker alerts.")
                    ControlExplainer(title: "Pause", detail: "Temporarily stops watching without quitting the app.")
                    ControlExplainer(title: "Quit", detail: "Fully closes the app and stops monitoring.")
                }
            }
        )
    }

    private var characterPage: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Image(systemName: "person.crop.square")
                    .font(.largeTitle)
                    .foregroundStyle(Theme.textSecondary)
                Text("Pick your character")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.textPrimary)
                Text("This is who shows up when you slouch. Change it anytime from settings.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            CharacterPickerView(selectedID: $selectedCharacterID)
                .padding(.horizontal, 24)

            Spacer()
        }
    }
}

private struct ProofLine: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Theme.textPrimary)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

private struct OnboardingPage<CustomBody: View>: View {
    let icon: String
    let title: String
    var body_: String?
    var customBody: (() -> CustomBody)?

    init(icon: String, title: String, body: String) where CustomBody == EmptyView {
        self.icon = icon
        self.title = title
        self.body_ = body
        self.customBody = nil
    }

    init(icon: String, title: String, @ViewBuilder customBody: @escaping () -> CustomBody) {
        self.icon = icon
        self.title = title
        self.body_ = nil
        self.customBody = customBody
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 32)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)
            if let body_ {
                Text(body_)
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            if let customBody {
                customBody()
                    .padding(.horizontal, 36)
            }
            Spacer()
        }
    }
}

private struct ControlExplainer: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.subheadline.bold()).foregroundStyle(Theme.textPrimary)
            Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
