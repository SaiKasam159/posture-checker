import SwiftUI

/// Shown once, the first time the app launches. Explains what the app does,
/// why it's worth leaving on, how the controls work, and lets the user pick
/// a character before the app settles into the menu bar.
struct OnboardingView: View {
    @AppStorage("selectedCharacterID") private var selectedCharacterID = CharacterCatalog.defaultID
    @State private var page = 0
    let onFinish: () -> Void

    private let pageCount = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                controlsPage.tag(2)
                characterPage.tag(3)
            }
            .tabViewStyle(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                pageDots
                Spacer()
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Button(page == pageCount - 1 ? "Get Started" : "Next") {
                    if page == pageCount - 1 {
                        onFinish()
                    } else {
                        page += 1
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 480, height: 540)
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var welcomePage: some View {
        OnboardingPage(
            icon: "figure.seated.side",
            title: "Posture Checker",
            body: "Most posture apps nag until you turn them off. This one stays invisible until you actually slouch — then a character walks onto your screen to call it out. Sit up, and it leaves you alone."
        )
    }

    private var howItWorksPage: some View {
        OnboardingPage(
            icon: "camera.fill",
            title: "How it works",
            body: "Your webcam tracks your head and shoulders to score your posture — processed entirely on your device, nothing is ever recorded or sent anywhere. You'll calibrate once against how you actually sit, at whatever angle your camera sees you."
        )
    }

    private var controlsPage: some View {
        OnboardingPage(
            icon: "slider.horizontal.3",
            title: "The controls",
            customBody: {
                VStack(alignment: .leading, spacing: 14) {
                    ControlExplainer(title: "Menu bar icon", detail: "Click it any time to open settings. No Dock icon, no main window — it just lives up there.")
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
                    .foregroundStyle(.secondary)
                Text("Pick your character")
                    .font(.title2.bold())
                Text("This is who shows up when you slouch. Change it anytime from settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            CharacterPickerView(selectedID: $selectedCharacterID)
                .padding(.horizontal, 24)

            Spacer()
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
                .foregroundStyle(Color.accentColor)
                .padding(.top, 32)
            Text(title)
                .font(.title2.bold())
            if let body_ {
                Text(body_)
                    .font(.body)
                    .foregroundStyle(.secondary)
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
            Text(title).font(.subheadline.bold())
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }
}

#Preview {
    OnboardingView(onFinish: {})
}
