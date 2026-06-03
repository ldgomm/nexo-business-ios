import Foundation
import SwiftUI

@MainActor
@Observable
final class SaleDiscountViewModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(SaleDiscountPreview)
        case failed(String)
    }

    private let saleId: String
    private let repository: SaleDiscountRepository

    var state: State = .idle
    var scope: SaleDiscountScope = .sale
    var type: SaleDiscountType = .percentage
    var value: String = ""
    var reason: String = ""
    var selectedLineIds: Set<String> = []

    init(saleId: String, repository: SaleDiscountRepository) {
        self.saleId = saleId
        self.repository = repository
    }

    func loadPreview() async {
        state = .loading
        do {
            state = .loaded(try await repository.preview(saleId: saleId))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func apply() async {
        state = .loading
        do {
            let input = ApplySaleDiscountInput(
                scope: scope,
                targetLineIds: scope == .sale ? [] : selectedLineIds,
                type: type,
                value: value,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason
            )
            state = .loaded(try await repository.applyDiscount(saleId: saleId, input: input))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func remove(discountId: String) async {
        state = .loading
        do {
            state = .loaded(try await repository.removeDiscount(saleId: saleId, discountId: discountId, reason: reason))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
