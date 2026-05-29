//
//  PreviewCustomersRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class PreviewCustomersRepository: CustomersRepository, @unchecked Sendable {
    public init() {}

    public func search(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CustomersSearchResponse {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let filtered = normalized.isEmpty
            ? PreviewCustomersData.customers
            : PreviewCustomersData.customers.filter { customer in
                customer.displayName.lowercased().contains(normalized) ||
                customer.identificationNumber.lowercased().contains(normalized) ||
                (customer.email?.lowercased().contains(normalized) ?? false) ||
                (customer.phone?.lowercased().contains(normalized) ?? false)
            }

        return CustomersSearchResponse(
            customers: Array(filtered.prefix(limit)),
            nextCursor: nil
        )
    }

    public func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateCustomerRequest
    ) async throws -> CustomerResponse {
        CustomerResponse(
            customer: BusinessCustomer(
                id: "cus_\(UUID().uuidString.prefix(8).lowercased())",
                displayName: request.displayName,
                identificationType: BusinessCustomerIdentificationType(rawValue: request.identificationType) ?? .unknown,
                identificationNumber: request.identificationNumber,
                email: request.email,
                phone: request.phone,
                address: request.address,
                status: "active",
                createdAt: Date(),
                updatedAt: Date()
            ),
            idempotencyReplayed: false
        )
    }
}
