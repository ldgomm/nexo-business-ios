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

    func searchSuggestions(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSuggestionSearchResponse

    func adoptSuggestion(
        organizationId: String,
        branchId: String?,
        activityId: String,
        template: PlatformCatalogTemplateSuggestion,
        localPrice: MoneyAmount,
        taxProfileCode: String,
        reason: String
    ) async throws -> BusinessCatalogItem
}

extension CatalogRepository {
    func searchSuggestions(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSuggestionSearchResponse {
        throw APIError.transport("La adopción desde sugerencias no está disponible en este repositorio.")
    }

    func adoptSuggestion(
        organizationId: String,
        branchId: String?,
        activityId: String,
        template: PlatformCatalogTemplateSuggestion,
        localPrice: MoneyAmount,
        taxProfileCode: String,
        reason: String
    ) async throws -> BusinessCatalogItem {
        throw APIError.transport("La adopción desde sugerencias no está disponible en este repositorio.")
    }
}
