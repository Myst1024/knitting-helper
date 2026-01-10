//
//  PurchaseManager.swift
//  knitting helper
//
//  Created by Gunnar Carlson on 1/10/26.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let premiumProductID = "premium"

    @Published var hasPremium: Bool = false
    @Published var isPaywallPresented: Bool = false

    @Published var product: Product?

    init() {
        Task {
            await refreshProducts()
            await updatePurchasedStatus()
            await listenForTransactions()
        }
    }

    func refreshProducts() async {
        do {
            let products = try await Product.products(for: [Self.premiumProductID])
            product = products.first
        } catch {
            // Silently ignore; the ProductView can still load by id.
        }
    }

    func updatePurchasedStatus() async {
        var isPremium = false
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.productID == Self.premiumProductID {
                isPremium = true
                break
            }
        }
        hasPremium = isPremium
        if isPremium {
            isPaywallPresented = false
        }
    }

    func purchasePremium() async {
        // Fallback manual purchase flow if presenting a custom UI.
        guard let product else {
            isPaywallPresented = true
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updatePurchasedStatus()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            // No-op: rely on UI to reflect state.
        }
    }

    func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                if transaction.productID == Self.premiumProductID {
                    await transaction.finish()
                    await updatePurchasedStatus()
                }
            }
        }
    }
}
