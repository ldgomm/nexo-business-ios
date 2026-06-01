//
//  CashAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessCashRoutes {
    public static let current = "/api/v1/business/cash/current"
    public static let open = "/api/v1/business/cash/open"
    
    public static func movements(cashSessionId: String) -> String {
        "/api/v1/business/cash/\(cashSessionId)/movements"
    }
    
    public static func close(cashSessionId: String) -> String {
        "/api/v1/business/cash/\(cashSessionId)/close"
    }
}

public final class CashAPIRepository: CashRepository, @unchecked Sendable {
    private let apiClient: APIClient
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    public func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCashRoutes.current,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId)
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.branchId: branchId
                ]
            )
        )
    }
    
    public func open(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request body: OpenCashSessionRequest
    ) async throws -> CashSessionResponse {
        try await apiClient.send(
            try APIRequest<CashSessionResponse>.json(
                method: .post,
                path: BusinessCashRoutes.open,
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.branchId: body.branchId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
    
    public func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request body: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse {
        try await apiClient.send(
            try APIRequest<CashMovementResponse>.json(
                method: .post,
                path: BusinessCashRoutes.movements(cashSessionId: cashSessionId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
    
    public func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request body: CloseCashSessionRequest
    ) async throws -> CashSessionResponse {
        try await apiClient.send(
            try APIRequest<CashSessionResponse>.json(
                method: .post,
                path: BusinessCashRoutes.close(cashSessionId: cashSessionId),
                body: body,
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
                ]
            )
        )
    }
}
