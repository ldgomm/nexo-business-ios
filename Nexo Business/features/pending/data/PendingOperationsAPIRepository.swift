//
//  PendingOperationsAPIRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessPendingRoutes {
    public static let sales = "/api/v1/business/sales"
    public static let receivables = "/api/v1/business/receivables"
    public static let documents = "/api/v1/business/documents"
}

public final class PendingOperationsAPIRepository: PendingOperationsRepository, @unchecked Sendable {
    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func pendingSales(
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

    public func pendingReceivables(
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
                    URLQueryItem(name: "status", value: "pending,partially_collected,overdue"),
                    URLQueryItem(name: "limit", value: String(limit))
                ],
                headers: [
                    BusinessHeaders.organizationId: organizationId
                ]
            )
        )
    }

    public func pendingDocuments(
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
