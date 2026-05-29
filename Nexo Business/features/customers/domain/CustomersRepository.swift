//
//  CustomersRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public protocol CustomersRepository: Sendable {
    func search(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CustomersSearchResponse

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateCustomerRequest
    ) async throws -> CustomerResponse
}

public final class UnavailableCustomersRepository: CustomersRepository, @unchecked Sendable {
    public init() {}

    public func search(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CustomersSearchResponse {
        throw APIError.server(
            statusCode: 501,
            code: "customers_repository_unavailable",
            message: "El módulo de clientes no está disponible en este contexto.",
            requestId: nil
        )
    }

    public func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateCustomerRequest
    ) async throws -> CustomerResponse {
        throw APIError.server(
            statusCode: 501,
            code: "customers_repository_unavailable",
            message: "El módulo de clientes no está disponible en este contexto.",
            requestId: nil
        )
    }
}
