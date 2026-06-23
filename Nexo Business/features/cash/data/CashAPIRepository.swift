//
//  CashAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessCashRoutes {
    static let current = "/api/v1/business/cash/current"
    static let sessions = "/api/v1/business/cash/sessions"
    static let open = "/api/v1/business/cash/open"
    
    static func movements(cashSessionId: String) -> String {
        "/api/v1/business/cash/\(cashSessionId)/movements"
    }
    
    static func close(cashSessionId: String) -> String {
        "/api/v1/business/cash/\(cashSessionId)/close"
    }
}

final class CashAPIRepository: CashRepository, @unchecked Sendable {
    private let apiClient: APIClient
    
    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }
    
    func current(
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
    

    func listSessions(
        organizationId: String,
        branchId: String,
        limit: Int = 20
    ) async throws -> CashSessionsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCashRoutes.sessions,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.branchId: branchId
                ]
            )
        )
    }

    func listMovements(
        organizationId: String,
        cashSessionId: String,
        limit: Int = 20
    ) async throws -> CashMovementsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessCashRoutes.movements(cashSessionId: cashSessionId),
                queryItems: [URLQueryItem(name: "limit", value: String(limit))],
                headers: [BusinessHeaders.organizationId: organizationId]
            )
        )
    }

    func open(
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
    
    func registerMovement(
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
    
    func close(
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
