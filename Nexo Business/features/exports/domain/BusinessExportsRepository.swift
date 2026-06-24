//
//  BusinessExportsRepository.swift
//  Nexo Business
//
//  Created by José Ruiz on 23/6/26.
//

import Foundation

protocol BusinessExportsRepository: Sendable {
    func catalog(organizationId: String) async throws -> BusinessExportsCatalogResponse

    func operationalSummary(
        organizationId: String,
        branchId: String?,
        from: String,
        to: String,
        label: String?
    ) async throws -> BusinessOperationalSummaryResponse

    func downloadOperationalZip(
        organizationId: String,
        branchId: String?,
        from: String,
        to: String,
        label: String?
    ) async throws -> BusinessExportDownloadedFile

    func dailyMetadata(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportGenerateResponse

    func generateDaily(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessExportGenerateRequest
    ) async throws -> BusinessExportGenerateResponse

    func downloadDailyZip(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportDownloadedFile
}
