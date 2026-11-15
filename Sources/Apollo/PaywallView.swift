import SwiftUI
import StoreKit

/// Shown when the user taps "Subscribe" in settings. Purely a purchase
/// prompt, Apple's own checkout sheet takes over from `purchase()`.
struct PaywallView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.stand")
                .font(.system(size: 36))
                .foregroundStyle(Theme.textPrimary)
                .padding(.top, 28)

            Text("APOLLO PREMIUM")
                .font(Theme.pixelFont(18))
                .foregroundStyle(Theme.textPrimary)

            Text("Keep Apollo watching your posture, with every character and future feature included.")
                .font(Theme.pixelFont(11, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let product = subscriptionManager.product {
                Text("\(product.displayPrice) / MONTH")
                    .font(Theme.pixelFont(15))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 4)
            } else if subscriptionManager.isLoading {
                ProgressView()
                    .padding(.top, 4)
            } else {
                Text("Subscription unavailable right now.")
                    .font(Theme.pixelFont(10, weight: .regular))
                    .foregroundStyle(Theme.textSecondary)
            }

            if let error = subscriptionManager.lastErrorMessage {
                Text(error)
                    .font(Theme.pixelFont(10, weight: .regular))
                    .foregroundStyle(.red)
            }

            Button("SUBSCRIBE") {
                Task {
                    await subscriptionManager.purchase()
                    if subscriptionManager.isSubscribed {
                        dismiss()
                    }
                }
            }
            .buttonStyle(PixelButtonStyle())
            .disabled(subscriptionManager.product == nil)

            Button("Restore Purchases") {
                Task { await subscriptionManager.restore() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .font(Theme.pixelFont(10, weight: .regular))

            Button("Not now") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .font(Theme.pixelFont(10, weight: .regular))
                .padding(.bottom, 20)
        }
        .frame(width: 340)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    PaywallView(subscriptionManager: SubscriptionManager())
}
