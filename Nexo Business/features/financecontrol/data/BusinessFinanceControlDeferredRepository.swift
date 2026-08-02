//
//  BusinessFinanceControlDeferredRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

struct BusinessFinanceControlDeferredRepository: BusinessFinanceControlRepository {
    func loadSnapshot(
        scope: BusinessFinanceControlScope
    ) async throws -> BusinessFinanceControlSnapshot {
        throw BusinessFinanceControlRepositoryError.runtimeEndpointUnavailable
    }
}
