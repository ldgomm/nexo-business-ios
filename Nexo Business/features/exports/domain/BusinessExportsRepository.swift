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

    func downloadOperationalKardexCSV(
        organizationId: String,
        branchId: String,
        itemId: String,
        warehouseId: String?,
        from: String,
        to: String
    ) async throws -> BusinessExportDownloadedFile

    func downloadConsolidatedKardexCSV(
        organizationId: String,
        branchId: String,
        activityId: String,
        warehouseId: String?,
        movementType: String?,
        from: String,
        to: String
    ) async throws -> BusinessExportDownloadedFile


    func downloadAccountantPackDraftZip(
        organizationId: String,
        branchId: String?,
        activityId: String?,
        year: Int,
        month: Int
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

extension BusinessExportsRepository {
    func downloadOperationalKardexCSV(
        organizationId: String,
        branchId: String,
        itemId: String,
        warehouseId: String?,
        from: String,
        to: String
    ) async throws -> BusinessExportDownloadedFile {
        throw APIError.transport("La exportación de Kardex operativo no está disponible.")
    }

    func downloadConsolidatedKardexCSV(
        organizationId: String,
        branchId: String,
        activityId: String,
        warehouseId: String?,
        movementType: String?,
        from: String,
        to: String
    ) async throws -> BusinessExportDownloadedFile {
        throw APIError.transport("La exportación consolidada de Kardex no está disponible.")
    }
}
