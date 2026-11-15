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

            Text("Apollo Premium")
                .font(.title2.bold())
                .foregroundStyle(Theme.textPrimary)

            Text("Keep Apollo watching your posture, with every character and future feature included.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let product = subscriptionManager.product {
                Text("\(product.displayPrice) / month")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.top, 4)
            } else if subscriptionManager.isLoading {
                ProgressView()
                    .padding(.top, 4)
            } else {
                Text("Subscription unavailable right now.")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }

            if let error = subscriptionManager.lastErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Subscribe") {
                Task {
                    await subscriptionManager.purchase()
                    if subscriptionManager.isSubscribed {
                        dismiss()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .foregroundStyle(.black)
            .disabled(subscriptionManager.product == nil)

            Button("Restore Purchases") {
                Task { await subscriptionManager.restore() }
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.textSecondary)
            .font(.caption)

            Button("Not now") { dismiss() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.textSecondary)
                .font(.caption)
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
