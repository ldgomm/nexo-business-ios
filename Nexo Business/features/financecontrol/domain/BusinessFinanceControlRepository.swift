//
//  BusinessFinanceControlRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

protocol BusinessFinanceControlRepository: Sendable {
    func loadSnapshot(
        scope: BusinessFinanceControlScope
    ) async throws -> BusinessFinanceControlSnapshot
}

enum BusinessFinanceControlRepositoryError: Error, Equatable, Sendable {
    case runtimeEndpointUnavailable
    case invalidResponse
}

