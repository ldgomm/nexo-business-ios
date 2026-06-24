//
//  BusinessExportsViewModel.swift
//  Nexo Business
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessExportsViewModel {
    private(set) var state: AsyncViewState<[BusinessExportDescriptor]> = .idle
    private(set) var exports: [BusinessExportDescriptor] = []
    private(set) var downloadedFile: BusinessExportDownloadedFile?
    private(set) var isLoading = false
    private(set) var isGenerating = false
    var businessDate = Date()
    var errorMessage: String?
    var successMessage: String?

    let organizationId: String
    let branchId: String
    let effectivePermissions: Set<String>

    private let exportsRepository: BusinessExportsRepository

    init(
        organizationId: String,
        branchId: String,
        effectivePermissions: Set<String>,
        exportsRepository: BusinessExportsRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.effectivePermissions = effectivePermissions
        self.exportsRepository = exportsRepository
    }

    var canExport: Bool {
        hasPermission(Self.exportPermissions)
    }

    var selectedBusinessDateString: String {
        Self.businessDateFormatter.string(from: businessDate)
    }

    func loadIfNeeded() async {
        guard case .idle = state else { return }
        await load()
    }

    func load() async {
        guard canExport else {
            exports = []
            state = .failed("No tienes permiso para exportar la operación diaria.")
            errorMessage = "No tienes permiso para exportar la operación diaria."
            return
        }

        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        successMessage = nil
        state = .loading

        defer { isLoading = false }

        do {
            let response = try await exportsRepository.catalog(organizationId: organizationId)
            exports = response.exports
            state = .loaded(response.exports)
            if response.exports.isEmpty {
                successMessage = "No hay exportaciones disponibles todavía."
            }
        } catch let error as APIError {
            let message = humanMessage(for: error)
            errorMessage = message
            state = .failed(message)
        } catch {
            errorMessage = error.localizedDescription
            state = .failed(error.localizedDescription)
        }
    }

    func generateAndDownloadDailyZip() async {
        guard canExport else {
            errorMessage = "No tienes permiso para generar o descargar exportaciones."
            return
        }

        guard !organizationId.isEmpty, !branchId.isEmpty else {
            errorMessage = "Falta negocio o sucursal activa. Actualiza el contexto."
            return
        }

        guard !isGenerating else { return }
        isGenerating = true
        errorMessage = nil
        successMessage = nil
        downloadedFile = nil

        defer { isGenerating = false }

        do {
            let file = try await exportsRepository.downloadDailyZip(
                organizationId: organizationId,
                branchId: branchId,
                businessDate: selectedBusinessDateString
            )
            downloadedFile = file
            successMessage = "Exportación lista: \(file.fileName)."
            await load()
        } catch let error as APIError {
            errorMessage = humanMessage(for: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearDownloadedFile() {
        downloadedFile = nil
    }

    func sizeText(for export: BusinessExportDescriptor) -> String? {
        guard let sizeBytes = export.sizeBytes else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(sizeBytes), countStyle: .file)
    }

    private func humanMessage(for error: APIError) -> String {
        switch error.statusCode ?? 0 {
        case 401:
            return "Tu sesión caducó. Vuelve a iniciar sesión."
        case 403:
            return "No tienes permiso para exportar esta información."
        case 404:
            return "La exportación diaria aún no está disponible."
        case 409:
            return "La exportación ya fue procesada. Actualiza e intenta de nuevo."
        case 422:
            return error.userMessage
        case 500...599:
            return "El servidor no respondió correctamente. Intenta de nuevo."
        default:
            return error.userMessage
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private static let exportPermissions = [
        "business.exports.view",
        "business.exports.generate",
        "business.exports.download",
        "exports.view",
        "exports.generate",
        "exports.download",
        "reports.export",
        "reports.dashboard.view",
        "reports.sales.view",
        "reports.cash.view",
        "reports.documents.view"
    ]

    private static let businessDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

final class PreviewBusinessExportsRepository: BusinessExportsRepository, @unchecked Sendable {
    func catalog(organizationId: String) async throws -> BusinessExportsCatalogResponse {
        BusinessExportsCatalogResponse(
            exports: [
                BusinessExportDescriptor(
                    id: "daily_operational_21d_v1",
                    kind: BusinessExportKind.dailyOperational.rawValue,
                    version: "21D.v1",
                    title: "Exportación operativa diaria",
                    description: "ZIP con ventas, pagos, caja, documentos y cuentas por cobrar del día.",
                    contentType: "application/zip",
                    fileName: "nexo_daily_operational_preview.zip",
                    sizeBytes: 4096
                )
            ]
        )
    }

    func dailyMetadata(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportGenerateResponse {
        throw APIError.transport("Vista previa sin exportación real.")
    }

    func generateDaily(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessExportGenerateRequest
    ) async throws -> BusinessExportGenerateResponse {
        throw APIError.transport("Vista previa sin exportación real.")
    }

    func downloadDailyZip(
        organizationId: String,
        branchId: String?,
        businessDate: String?
    ) async throws -> BusinessExportDownloadedFile {
        throw APIError.transport("Vista previa sin exportación real.")
    }
}
