//
//  CatalogRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

protocol CatalogRepository: Sendable {
    func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSearchResponse
}
