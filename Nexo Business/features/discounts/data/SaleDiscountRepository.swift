import Foundation

protocol SaleDiscountRepository: Sendable {
    func applyDiscount(saleId: String, input: ApplySaleDiscountInput) async throws -> SaleDiscountPreview
    func removeDiscount(saleId: String, discountId: String, reason: String) async throws -> SaleDiscountPreview
    func preview(saleId: String) async throws -> SaleDiscountPreview
}

struct RemoteSaleDiscountRepository: SaleDiscountRepository {
    let apiClient: APIClient

    func applyDiscount(saleId: String, input: ApplySaleDiscountInput) async throws -> SaleDiscountPreview {
        let request: APIRequest<SaleDiscountResultResponse> = try .json(method: .post, path: "/api/v1/business/sales/\(saleId)/discounts", body: input)
        return try await apiClient.send(request).preview
    }

    func removeDiscount(saleId: String, discountId: String, reason: String) async throws -> SaleDiscountPreview {
        let request: APIRequest<SaleDiscountResultResponse> = try .json(method: .delete, path: "/api/v1/business/sales/\(saleId)/discounts/\(discountId)", body: RemoveSaleDiscountInput(reason: reason))
        return try await apiClient.send(request).preview
    }

    func preview(saleId: String) async throws -> SaleDiscountPreview {
        try await apiClient.send(APIRequest(method: .post, path: "/api/v1/business/sales/\(saleId)/preview"))
    }
}

private struct SaleDiscountResultResponse: Decodable {
    let preview: SaleDiscountPreview
}

private struct RemoveSaleDiscountInput: Encodable {
    let reason: String
}
