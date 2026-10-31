// MeldStoreKit: StoreKit 2 for the MeldStore plugin (Swift; StoreKit 2 has no
// Objective-C API, so meld_store.mm calls this @objc wrapper).
// Compiled in CI (ios-plugins workflow); run on a device: unverified.
// Everything lives on the main actor: Godot calls in on the main thread and
// the callbacks go back to Godot there, so no state crosses threads.
import Foundation
import StoreKit

@MainActor @objc public class MeldStoreKit: NSObject {
    @objc public static let shared = MeldStoreKit()

    /// Called on the main queue with results; meld_store.mm forwards them
    /// to Godot as signals.
    @objc public var onPurchased: ((String) -> Void)?
    @objc public var onRestored: (([String]) -> Void)?
    @objc public var onFailed: ((String, String) -> Void)?
    @objc public var onProducts: (([[String: String]]) -> Void)?

    private var products: [String: Product] = [:]
    private var updates: Task<Void, Never>?

    /// Load the products and listen for transactions made elsewhere
    /// (Ask to Buy approved later, a purchase on another device).
    @objc public func start(_ ids: [String]) {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result {
                    await t.finish()
                    self?.onPurchased?(t.productID)
                }
            }
        }
        Task {
            do {
                let list = try await Product.products(for: ids)
                var out: [[String: String]] = []
                for p in list {
                    products[p.id] = p
                    out.append(["id": p.id, "price": p.displayPrice])
                }
                self.onProducts?(out)
            } catch {
                self.onProducts?([])
            }
        }
    }

    @objc public func purchase(_ id: String) {
        Task {
            guard let p = products[id] else {
                self.onFailed?(id, "not available")
                return
            }
            do {
                switch try await p.purchase() {
                case .success(let result):
                    if case .verified(let t) = result {
                        await t.finish()
                        self.onPurchased?(id)
                    } else {
                        self.onFailed?(id, "not verified")
                    }
                case .userCancelled:
                    self.onFailed?(id, "cancelled")
                case .pending:
                    self.onFailed?(id, "waiting for approval")
                @unknown default:
                    self.onFailed?(id, "unknown")
                }
            } catch {
                self.onFailed?(id, error.localizedDescription)
            }
        }
    }

    /// Restore: sync with the App Store, then report every owned product.
    @objc public func restore() {
        Task {
            try? await AppStore.sync()
            var owned: [String] = []
            for await result in Transaction.currentEntitlements {
                if case .verified(let t) = result, t.revocationDate == nil {
                    owned.append(t.productID)
                }
            }
            self.onRestored?(owned)
        }
    }
}
