import AppKit
import StoreKit

/// Everything Apollo needs to know about its own subscription state,
/// entirely through StoreKit 2. No backend, no accounts, no database:
/// Apple ties entitlement to the user's Apple ID, and the system
/// "manage subscriptions" sheet (see SettingsView) handles cancellation,
/// plan changes, and billing problems without any UI we have to build.
@MainActor
final class SubscriptionManager: ObservableObject {
    /// Must match a subscription product created in App Store Connect
    /// (or in the local Apollo.storekit config for development testing).
    static let productID = "com.apollo.posture.monthly"

    @Published private(set) var isSubscribed = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = Task { [weak self] in
            await self?.observeTransactionUpdates()
        }
        Task { [weak self] in
            await self?.loadProduct()
            await self?.refreshEntitlement()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    func loadProduct() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            product = nil
            lastErrorMessage = "Couldn't load subscription info."
        }
    }

    /// Checks Apple's own record of what this Apple ID currently has access
    /// to. This is the entire "is the user subscribed" check — no server
    /// round-trip, no local database.
    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.productID == Self.productID {
                active = transaction.revocationDate == nil
            }
        }
        isSubscribed = active
    }

    func purchase() async {
        guard let product else { return }
        lastErrorMessage = nil
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                } else {
                    lastErrorMessage = "Purchase could not be verified."
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastErrorMessage = "Purchase failed. Try again."
        }
    }

    /// Re-pulls entitlements from Apple. Covers "I subscribed on my phone"
    /// or "I want to double check" without any account system of ours.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            lastErrorMessage = "Restore failed. Try again."
        }
        await refreshEntitlement()
    }

    /// macOS has no in-app "manage subscriptions" sheet (that's iOS-only).
    /// The standard approach is sending the user to Apple's own
    /// subscriptions page, which handles everything from there.
    static func openManageSubscriptions() {
        guard let url = URL(string: "https://apps.apple.com/account/subscriptions") else { return }
        NSWorkspace.shared.open(url)
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
