//
//  BusinessProcurementAttachmentsViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/7/26.
//

import Foundation
import Observation
import UniformTypeIdentifiers

struct BusinessProcurementEvidenceItem: Identifiable, Equatable, Sendable {
    let id: String
    let position: Int

    var displayName: String {
        "Evidencia \(position)"
    }
}

struct BusinessProcurementPendingAttachmentUpload: Equatable, Sendable {
    let fileName: String
    let mediaType: BusinessProcurementAttachmentMediaType
    let data: Data
    let idempotencyKey: IdempotencyKey
    let expectedSourceVersion: Int64?
}

@MainActor
@Observable
final class BusinessProcurementAttachmentsViewModel {
    private(set) var downloadedFiles: [String: BusinessProcurementDownloadedFile] = [:]
    private(set) var downloadingAttachmentIds: Set<String> = []
    private(set) var lastFailedAttachmentId: String?
    private(set) var ignoredReferenceCount = 0
    private(set) var pendingUpload: BusinessProcurementPendingAttachmentUpload?
    private(set) var isUploading = false
    private(set) var deletingAttachmentId: String?
    private(set) var isRefreshingSource = false
    private(set) var needsSourceRefresh = false
    private(set) var sourceVersion: Int64?
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let sourceType: BusinessProcurementAttachmentSourceType
    let sourceId: String
    let sourceDisplayName: String
    let accessPolicy: BusinessProcurementAccessPolicy
    let repository: BusinessProcurementRepository

    private var attachmentIds: [String]

    init(
        organizationId: String,
        sourceType: BusinessProcurementAttachmentSourceType,
        sourceId: String,
        sourceVersion: Int64,
        sourceDisplayName: String,
        attachmentIds: [String],
        activeModules: Set<ModuleCode>,
        effectivePermissions: Set<String>,
        repository: BusinessProcurementRepository
    ) {
        self.organizationId = organizationId
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceType = sourceType
        self.sourceId = sourceId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.sourceVersion = sourceVersion > 0 ? sourceVersion : nil
        self.sourceDisplayName = sourceDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.accessPolicy = BusinessProcurementAccessPolicy(
            activeModules: activeModules,
            effectivePermissions: effectivePermissions
        )
        self.repository = repository

        let normalised = Self.normalizedAttachmentIds(attachmentIds)
        self.attachmentIds = normalised.ids
        self.ignoredReferenceCount = normalised.ignoredCount
    }

    var requiredViewPermissions: Set<String> {
        switch sourceType {
        case .supplier:
            return [
                BusinessProcurementPermission.suppliersView,
                BusinessProcurementPermission.suppliersSensitiveView,
            ]
        case .purchaseOrder:
            return [
                BusinessProcurementPermission.purchaseOrdersView,
                BusinessProcurementPermission.purchaseOrdersCostView,
            ]
        case .purchaseReceipt:
            return [BusinessProcurementPermission.purchaseReceiptsView]
        case .supplierDocument:
            return [BusinessProcurementPermission.supplierDocumentsView]
        case .supplierPayment:
            return [
                BusinessProcurementPermission.supplierPaymentsView,
                BusinessProcurementPermission.supplierPaymentsSensitiveView,
            ]
        }
    }

    var canViewEvidence: Bool {
        accessPolicy.isModuleActive && requiredViewPermissions.allSatisfy {
            accessPolicy.hasPermission($0)
        }
    }

    var supportsAttachmentMutations: Bool {
        sourceType != .supplier
            && Self.isSafeResourceId(sourceId)
            && sourceVersion != nil
            && !needsSourceRefresh
    }

    var canUploadEvidence: Bool {
        canViewEvidence
            && supportsAttachmentMutations
            && accessPolicy.allows(BusinessProcurementPermission.attachmentsUpload)
    }

    var canDeleteEvidence: Bool {
        canViewEvidence
            && supportsAttachmentMutations
            && accessPolicy.allows(BusinessProcurementPermission.attachmentsDelete)
    }

    var evidenceItems: [BusinessProcurementEvidenceItem] {
        attachmentIds.enumerated().map { index, attachmentId in
            BusinessProcurementEvidenceItem(
                id: attachmentId,
                position: index + 1
            )
        }
    }

    var attachmentCountText: String {
        attachmentIds.count == 1
            ? "1 evidencia"
            : "\(attachmentIds.count) evidencias"
    }

    var integrityWarning: String? {
        guard ignoredReferenceCount > 0 else { return nil }
        return ignoredReferenceCount == 1
            ? "Se omitió una referencia de evidencia no válida."
            : "Se omitieron \(ignoredReferenceCount) referencias de evidencia no válidas."
    }

    var isDownloading: Bool {
        !downloadingAttachmentIds.isEmpty
    }

    var isMutating: Bool {
        isUploading || deletingAttachmentId != nil || isRefreshingSource
    }

    func isDownloading(_ item: BusinessProcurementEvidenceItem) -> Bool {
        downloadingAttachmentIds.contains(item.id)
    }

    func isDeleting(_ item: BusinessProcurementEvidenceItem) -> Bool {
        deletingAttachmentId == item.id
    }

    func downloadedFile(
        for item: BusinessProcurementEvidenceItem
    ) -> BusinessProcurementDownloadedFile? {
        downloadedFiles[item.id]
    }

    func download(_ item: BusinessProcurementEvidenceItem) async {
        guard validateViewAccess() else { return }
        guard !isMutating else { return }
        guard attachmentIds.contains(item.id) else {
            errorMessage = "La referencia de evidencia no pertenece a este recurso."
            infoMessage = nil
            return
        }
        guard !downloadingAttachmentIds.contains(item.id) else { return }
        if downloadedFiles[item.id] != nil {
            infoMessage = "\(item.displayName) está lista para compartir."
            errorMessage = nil
            return
        }

        downloadingAttachmentIds.insert(item.id)
        lastFailedAttachmentId = item.id
        errorMessage = nil
        infoMessage = nil
        defer { downloadingAttachmentIds.remove(item.id) }

        do {
            let file = try await repository.downloadAttachment(
                organizationId: organizationId,
                attachmentId: item.id
            )
            guard Self.isAcceptedDownloadedFile(file) else {
                errorMessage = "El servidor no devolvió una evidencia PDF o imagen válida."
                return
            }
            downloadedFiles[item.id] = file
            lastFailedAttachmentId = nil
            infoMessage = "\(item.displayName) está lista para compartir."
        } catch {
            errorMessage = Self.userMessage(
                for: error,
                fallback: "No se pudo descargar la evidencia. Inténtalo nuevamente."
            )
        }
    }

    func retryLastDownload() async {
        guard let lastFailedAttachmentId,
              let item = evidenceItems.first(where: { $0.id == lastFailedAttachmentId }) else {
            return
        }
        await download(item)
    }

    func importAndUpload(from fileURL: URL) async {
        guard validateMutationAccess(permission: BusinessProcurementPermission.attachmentsUpload) else {
            return
        }
        guard !isDownloading else { return }
        do {
            pendingUpload = try Self.pendingUpload(from: fileURL)
            errorMessage = nil
            infoMessage = "Archivo validado. Preparando la carga segura…"
        } catch {
            pendingUpload = nil
            errorMessage = Self.userMessage(
                for: error,
                fallback: "Selecciona un archivo PDF, JPEG o PNG válido de hasta 10 MB."
            )
            infoMessage = nil
            return
        }
        await uploadPendingFile()
    }

    #if DEBUG
    func prepareUploadForTesting(
        fileName: String,
        mediaType: BusinessProcurementAttachmentMediaType,
        data: Data,
        idempotencyKey: IdempotencyKey = .generate(prefix: "procurement-attachment-upload")
    ) {
        pendingUpload = BusinessProcurementPendingAttachmentUpload(
            fileName: fileName,
            mediaType: mediaType,
            data: data,
            idempotencyKey: idempotencyKey,
            expectedSourceVersion: nil
        )
    }
    #endif

    func uploadPendingFile() async {
        guard validateMutationAccess(permission: BusinessProcurementPermission.attachmentsUpload),
              !isMutating,
              !isDownloading,
              var candidate = pendingUpload else {
            return
        }

        isUploading = true
        errorMessage = nil
        infoMessage = nil
        defer { isUploading = false }

        var uploadWasSent = false
        do {
            if candidate.expectedSourceVersion == nil {
                let state = try await authoritativeSourceState()
                applyAuthoritativeState(state)
                candidate = BusinessProcurementPendingAttachmentUpload(
                    fileName: candidate.fileName,
                    mediaType: candidate.mediaType,
                    data: candidate.data,
                    idempotencyKey: candidate.idempotencyKey,
                    expectedSourceVersion: state.version
                )
                self.pendingUpload = candidate
            }
            guard let expectedSourceVersion = candidate.expectedSourceVersion else {
                throw BusinessProcurementAttachmentStateError.invalidServerState
            }
            uploadWasSent = true
            let response = try await repository.uploadAttachment(
                organizationId: organizationId,
                idempotencyKey: candidate.idempotencyKey,
                upload: BusinessProcurementAttachmentUpload(
                    sourceType: sourceType,
                    sourceId: sourceId,
                    expectedSourceVersion: expectedSourceVersion,
                    fileName: candidate.fileName,
                    mediaType: candidate.mediaType,
                    data: candidate.data
                )
            )
            guard response.data.sourceType == sourceType,
                  response.data.sourceId == sourceId,
                  Self.isSafeAttachmentId(response.data.id),
                  response.data.mediaType == candidate.mediaType.rawValue,
                  response.data.sizeBytes == Int64(candidate.data.count),
                  response.data.sizeBytes > 0,
                  response.data.sizeBytes <= Int64(BusinessProcurementContractDecision.maximumAttachmentBytes),
                  response.data.version > 0 else {
                throw BusinessProcurementAttachmentStateError.invalidServerState
            }

            if !attachmentIds.contains(response.data.id) {
                attachmentIds.append(response.data.id)
            }
            self.pendingUpload = nil
            await reconcileSourceState(
                successMessage: "La evidencia se adjuntó y quedó ligada al recurso.",
                requiredPresentAttachmentId: response.data.id
            )
        } catch {
            if let apiError = error as? APIError, apiError.isRevisionConflict {
                await recoverFromUploadConflict(apiError)
                return
            }
            if uploadWasSent, error is BusinessProcurementAttachmentStateError {
                await recoverFromUntrustedUploadResponse()
                return
            }
            errorMessage = Self.userMessage(
                for: error,
                fallback: "No se pudo adjuntar la evidencia. Reintenta la misma carga."
            )
        }
    }

    func delete(_ item: BusinessProcurementEvidenceItem) async {
        guard validateMutationAccess(permission: BusinessProcurementPermission.attachmentsDelete),
              !isMutating,
              !isDownloading else {
            return
        }
        guard attachmentIds.contains(item.id) else {
            errorMessage = "La referencia de evidencia no pertenece a este recurso."
            infoMessage = nil
            return
        }

        deletingAttachmentId = item.id
        errorMessage = nil
        infoMessage = nil
        defer { deletingAttachmentId = nil }

        do {
            let state = try await authoritativeSourceState()
            applyAuthoritativeState(state)
            guard attachmentIds.contains(item.id) else {
                throw BusinessProcurementAttachmentStateError.attachmentNoLongerBound
            }
            try await repository.deleteAttachment(
                organizationId: organizationId,
                attachmentId: item.id,
                expectedSourceVersion: state.version
            )
            attachmentIds.removeAll { $0 == item.id }
            removeDownloadedFile(for: item.id)
            await reconcileSourceState(
                successMessage: "La evidencia se eliminó del recurso.",
                requiredAbsentAttachmentId: item.id
            )
        } catch let deletionError {
            do {
                let state = try await authoritativeSourceState()
                applyAuthoritativeState(state)
                needsSourceRefresh = false
                if !attachmentIds.contains(item.id) {
                    removeDownloadedFile(for: item.id)
                    errorMessage = nil
                    infoMessage = "La evidencia ya no está ligada al recurso."
                } else {
                    errorMessage = Self.userMessage(
                        for: deletionError,
                        fallback: "No se pudo eliminar la evidencia. El recurso se actualizó y no se repitió la eliminación."
                    )
                }
            } catch {
                needsSourceRefresh = true
                self.sourceVersion = nil
                errorMessage = "No se pudo confirmar la eliminación. Actualiza el recurso antes de intentarlo otra vez."
            }
        }
    }

    func refreshSourceState() async {
        guard validateViewAccess(), !isMutating else { return }
        isRefreshingSource = true
        errorMessage = nil
        defer { isRefreshingSource = false }

        do {
            let state = try await authoritativeSourceState()
            applyAuthoritativeState(state)
            needsSourceRefresh = false
            pendingUpload = nil
            infoMessage = "La evidencia y la versión del recurso están actualizadas."
        } catch {
            needsSourceRefresh = true
            sourceVersion = nil
            errorMessage = Self.userMessage(
                for: error,
                fallback: "No se pudo actualizar el recurso. Inténtalo nuevamente."
            )
        }
    }

    private func reconcileSourceState(
        successMessage: String,
        requiredPresentAttachmentId: String? = nil,
        requiredAbsentAttachmentId: String? = nil
    ) async {
        do {
            let state = try await authoritativeSourceState()
            applyAuthoritativeState(state)
            if let requiredPresentAttachmentId,
               !state.attachmentIds.contains(requiredPresentAttachmentId) {
                throw BusinessProcurementAttachmentStateError.invalidServerState
            }
            if let requiredAbsentAttachmentId,
               state.attachmentIds.contains(requiredAbsentAttachmentId) {
                throw BusinessProcurementAttachmentStateError.invalidServerState
            }
            needsSourceRefresh = false
            infoMessage = successMessage
            errorMessage = nil
        } catch {
            needsSourceRefresh = true
            sourceVersion = nil
            infoMessage = "La operación terminó, pero debes actualizar el recurso antes de otra carga o eliminación."
            errorMessage = nil
        }
    }

    private func recoverFromUploadConflict(_ error: APIError) async {
        pendingUpload = nil
        do {
            let state = try await authoritativeSourceState()
            applyAuthoritativeState(state)
            needsSourceRefresh = false
            errorMessage = "\(error.userMessage) Selecciona el archivo nuevamente para crear una solicitud nueva."
        } catch {
            needsSourceRefresh = true
            sourceVersion = nil
            errorMessage = "La versión del recurso cambió y no se pudo actualizar. Actualiza antes de volver a seleccionar el archivo."
        }
    }

    private func recoverFromUntrustedUploadResponse() async {
        pendingUpload = nil
        do {
            let state = try await authoritativeSourceState()
            applyAuthoritativeState(state)
            needsSourceRefresh = false
            errorMessage = "La carga respondió con datos no válidos. El recurso se actualizó y la solicitud no se repetirá."
        } catch {
            needsSourceRefresh = true
            sourceVersion = nil
            errorMessage = "La carga no pudo verificarse. Actualiza el recurso antes de otra carga o eliminación."
        }
    }

    private func authoritativeSourceState() async throws -> BusinessProcurementAttachmentSourceState {
        let values: (id: String, attachmentIds: [String], version: Int64)
        switch sourceType {
        case .purchaseOrder:
            let response = try await repository.getPurchaseOrder(
                organizationId: organizationId,
                orderId: sourceId
            )
            values = (response.data.id, response.data.attachmentIds, response.data.version)
        case .purchaseReceipt:
            let response = try await repository.getPurchaseReceipt(
                organizationId: organizationId,
                receiptId: sourceId
            )
            values = (response.data.id, response.data.attachmentIds, response.data.version)
        case .supplierDocument:
            let response = try await repository.getSupplierDocument(
                organizationId: organizationId,
                documentId: sourceId
            )
            values = (response.data.id, response.data.attachmentIds, response.data.version)
        case .supplierPayment:
            let response = try await repository.getSupplierPayment(
                organizationId: organizationId,
                paymentId: sourceId
            )
            guard let attachmentIds = response.data.attachmentIds else {
                throw BusinessProcurementAttachmentStateError.unavailableAttachmentState
            }
            values = (response.data.id, attachmentIds, response.data.version)
        case .supplier:
            throw BusinessProcurementAttachmentStateError.unavailableAttachmentState
        }

        let normalised = Self.normalizedAttachmentIds(values.attachmentIds)
        guard values.id == sourceId,
              values.version > 0,
              normalised.ignoredCount == 0 else {
            throw BusinessProcurementAttachmentStateError.invalidServerState
        }
        return BusinessProcurementAttachmentSourceState(
            attachmentIds: normalised.ids,
            version: values.version
        )
    }

    private func applyAuthoritativeState(_ state: BusinessProcurementAttachmentSourceState) {
        let removedIds = Set(downloadedFiles.keys).subtracting(state.attachmentIds)
        for attachmentId in removedIds {
            removeDownloadedFile(for: attachmentId)
        }
        attachmentIds = state.attachmentIds
        sourceVersion = state.version
        ignoredReferenceCount = 0
    }

    private func removeDownloadedFile(for attachmentId: String) {
        if let file = downloadedFiles[attachmentId] {
            try? FileManager.default.removeItem(at: file.localURL)
        }
        downloadedFiles[attachmentId] = nil
    }

    private func validateViewAccess() -> Bool {
        guard accessPolicy.isModuleActive else {
            errorMessage = "El módulo Compras no está activo para esta organización."
            infoMessage = nil
            return false
        }
        guard !organizationId.isEmpty else {
            errorMessage = "Selecciona una organización válida antes de consultar evidencia."
            infoMessage = nil
            return false
        }
        guard canViewEvidence else {
            errorMessage = "No tienes permisos suficientes para consultar la evidencia de este recurso."
            infoMessage = nil
            return false
        }
        return true
    }

    private func validateMutationAccess(permission: String) -> Bool {
        guard validateViewAccess() else { return false }
        guard sourceType != .supplier,
              Self.isSafeResourceId(sourceId),
              sourceVersion != nil,
              !needsSourceRefresh else {
            errorMessage = "Actualiza el recurso antes de modificar su evidencia."
            infoMessage = nil
            return false
        }
        guard accessPolicy.allows(permission) else {
            errorMessage = "No tienes permiso para modificar la evidencia de este recurso."
            infoMessage = nil
            return false
        }
        return true
    }

    private static func pendingUpload(
        from fileURL: URL
    ) throws -> BusinessProcurementPendingAttachmentUpload {
        guard fileURL.isFileURL else {
            throw BusinessProcurementAttachmentStateError.invalidLocalFile
        }
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try fileURL.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey, .contentTypeKey]
        )
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize > 0,
              fileSize <= BusinessProcurementContractDecision.maximumAttachmentBytes else {
            throw BusinessProcurementAttachmentStateError.invalidLocalFile
        }

        let fileName = fileURL.lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let mediaType = try mediaType(for: fileName)
        guard isCompatibleContentType(values.contentType, mediaType: mediaType) else {
            throw BusinessProcurementAttachmentStateError.unsupportedMediaType
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        guard data.count == fileSize,
              data.count <= BusinessProcurementContractDecision.maximumAttachmentBytes,
              isValidSignature(data, mediaType: mediaType) else {
            throw BusinessProcurementAttachmentStateError.invalidLocalFile
        }

        return BusinessProcurementPendingAttachmentUpload(
            fileName: fileName,
            mediaType: mediaType,
            data: data,
            idempotencyKey: .generate(prefix: "procurement-attachment-upload"),
            expectedSourceVersion: nil
        )
    }

    private static func mediaType(
        for fileName: String
    ) throws -> BusinessProcurementAttachmentMediaType {
        guard !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            throw BusinessProcurementAttachmentStateError.invalidLocalFile
        }
        switch URL(fileURLWithPath: fileName).pathExtension.lowercased() {
        case "pdf": return .pdf
        case "jpg", "jpeg": return .jpeg
        case "png": return .png
        default: throw BusinessProcurementAttachmentStateError.unsupportedMediaType
        }
    }

    private static func isValidSignature(
        _ data: Data,
        mediaType: BusinessProcurementAttachmentMediaType
    ) -> Bool {
        switch mediaType {
        case .pdf:
            return data.starts(with: Data("%PDF-".utf8))
        case .jpeg:
            return data.starts(with: Data([0xFF, 0xD8, 0xFF]))
        case .png:
            return data.starts(with: Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        }
    }

    private static func isCompatibleContentType(
        _ contentType: UTType?,
        mediaType: BusinessProcurementAttachmentMediaType
    ) -> Bool {
        guard let contentType else { return false }
        switch mediaType {
        case .pdf:
            return contentType.conforms(to: .pdf)
        case .jpeg:
            return contentType.conforms(to: .jpeg)
        case .png:
            return contentType.conforms(to: .png)
        }
    }

    private static func normalizedAttachmentIds(
        _ values: [String]
    ) -> (ids: [String], ignoredCount: Int) {
        var ids: [String] = []
        var seen: Set<String> = []
        var ignoredCount = 0

        for value in values {
            let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isSafeAttachmentId(candidate), seen.insert(candidate).inserted else {
                ignoredCount += 1
                continue
            }
            ids.append(candidate)
        }
        return (ids, ignoredCount)
    }

    private static func isSafeResourceId(_ value: String) -> Bool {
        isSafeAttachmentId(value)
    }

    private static func isSafeAttachmentId(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 128 else { return false }
        return value.range(
            of: "^[A-Za-z0-9][A-Za-z0-9_-]*$",
            options: .regularExpression
        ) != nil
    }

    private static func isAcceptedDownloadedFile(
        _ file: BusinessProcurementDownloadedFile
    ) -> Bool {
        let contentType = file.contentType
            .split(separator: ";", maxSplits: 1)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let allowedContentTypes: Set<String> = [
            BusinessProcurementAttachmentMediaType.pdf.rawValue,
            BusinessProcurementAttachmentMediaType.jpeg.rawValue,
            BusinessProcurementAttachmentMediaType.png.rawValue,
        ]
        let fileName = file.fileName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard file.localURL.isFileURL,
              file.sizeBytes > 0,
              file.sizeBytes <= BusinessProcurementContractDecision.maximumAttachmentBytes,
              let contentType,
              allowedContentTypes.contains(contentType),
              !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/"),
              !fileName.contains("\\") else {
            return false
        }

        guard let values = try? file.localURL.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]
        ), values.isRegularFile == true, values.fileSize == file.sizeBytes else {
            return false
        }
        return true
    }

    private static func userMessage(for error: Error, fallback: String) -> String {
        if let error = error as? APIError {
            return error.userMessage
        }
        if let error = error as? BusinessProcurementRepositoryError {
            return error.errorDescription ?? fallback
        }
        if let error = error as? BusinessProcurementAttachmentStateError {
            return error.errorDescription ?? fallback
        }
        return fallback
    }
}

private struct BusinessProcurementAttachmentSourceState: Sendable {
    let attachmentIds: [String]
    let version: Int64
}

private enum BusinessProcurementAttachmentStateError: LocalizedError {
    case invalidLocalFile
    case unsupportedMediaType
    case unavailableAttachmentState
    case invalidServerState
    case attachmentNoLongerBound

    var errorDescription: String? {
        switch self {
        case .invalidLocalFile:
            return "El archivo no es una evidencia válida o supera el límite de 10 MB."
        case .unsupportedMediaType:
            return "Solo puedes adjuntar archivos PDF, JPEG o PNG."
        case .unavailableAttachmentState:
            return "El servidor no devolvió un estado de evidencia administrable para este recurso."
        case .invalidServerState:
            return "El servidor devolvió un estado de evidencia no válido."
        case .attachmentNoLongerBound:
            return "La evidencia ya no pertenece a este recurso."
        }
    }
}
