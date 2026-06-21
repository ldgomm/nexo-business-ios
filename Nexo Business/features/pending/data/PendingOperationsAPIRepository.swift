//
//  PendingOperationsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum BusinessPendingRoutes {
    static let sales = "/api/v1/business/sales"
    static let receivables = "/api/v1/business/receivables"
    static let documents = "/api/v1/business/documents"
}

final class PendingOperationsAPIRepository: PendingOperationsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func pendingSales(
        organizationId: String,
        branchId: String,
        limit: Int = 50
    ) async throws -> PendingSalesResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessPendingRoutes.sales,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "status", value: "pending,confirmed,in_progress,ready"),
                    URLQueryItem(name: "paymentStatus", value: "unpaid,partially_paid"),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func pendingReceivables(
        organizationId: String,
        branchId: String,
        limit: Int = 50
    ) async throws -> PendingReceivablesResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessPendingRoutes.receivables,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "status", value: "open,partially_paid,partially_collected,overdue"),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    func pendingDocuments(
        organizationId: String,
        branchId: String,
        limit: Int = 50
    ) async throws -> PendingDocumentsResponse {
        try await apiClient.send(
            APIRequest(
                method: .get,
                path: BusinessPendingRoutes.documents,
                queryItems: [
                    URLQueryItem(name: "branchId", value: branchId),
                    URLQueryItem(name: "status", value: "draft,generated,sent,received,rejected,returned,error,pending_cancellation"),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }
}
