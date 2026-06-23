//
//  BusinessExportsRepository.swift
//  Nexo Business
//

import Foundation

protocol BusinessExportsRepository: Sendable {
    func catalog(organizationId: String) async throws -> BusinessExportsCatalogResponse

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
