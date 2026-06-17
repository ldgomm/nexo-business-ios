//
//  BusinessElectronicDocumentDetailViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessElectronicDocumentDetailViewModel {
    private(set) var detail: BusinessElectronicDocumentDetail?
    private(set) var timeline: [BusinessElectronicDocumentTimelineEvent] = []
    private(set) var lastArtifact: BusinessDocumentArtifact?
    private(set) var lastDownloadedFile: BusinessDocumentDownloadedFile?
    private(set) var isLoading = false
    private(set) var isLoadingTimeline = false
    private(set) var loadingAction: BusinessElectronicDocumentAction?
    var isDownloadingRide: Bool { loadingAction == .downloadRide }
    var isDownloadingXml: Bool { loadingAction == .downloadXml }
    var isSendingEmail: Bool { loadingAction == .resendEmail }
    var isRetryingReception: Bool { loadingAction == .retryReception }
    var isRetryingAuthorization: Bool { loadingAction == .retryAuthorization }
    var isRegeneratingRide: Bool { loadingAction == .regenerateRide }
    var isPerformingAction: Bool { loadingAction != nil }
    var lastPreparedFileSummary: String? { lastDownloadedFile?.preparedSummaryText }
    var previewFile: BusinessDocumentDownloadedFile?
    var shareFile: BusinessDocumentDownloadedFile?
    var recipientOverride = ""
    var emailReason = "Reenvío solicitado por el cliente"
    var retryReason = "Reintento solicitado desde Nexo Business"
    var rideRegenerationReason = "Regeneración de RIDE solicitada desde Nexo Business"
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let documentId: String
    let effectivePermissions: Set<String>
    private let repository: BusinessDocumentsRepository
    private let onDocumentMutated: (() async -> Void)?

    init(
        organizationId: String,
        documentId: String,
        effectivePermissions: Set<String>,
        documentsRepository: BusinessDocumentsRepository,
        initialDetail: BusinessElectronicDocumentDetail? = nil,
        onDocumentMutated: (() async -> Void)? = nil
    ) {
        self.organizationId = organizationId
        self.documentId = documentId
        self.effectivePermissions = effectivePermissions
        self.repository = documentsRepository
        self.onDocumentMutated = onDocumentMutated
        self.detail = initialDetail
        self.timeline = initialDetail?.timeline ?? []
    }

    var shouldLoadOnAppear: Bool {
        detail == nil && !isLoading
    }

    var canView: Bool {
        hasPermission([
            "documents.electronic_invoice.view",
            "documents.electronic_invoice.list",
            "business.documents.view",
            "documents.view"
        ])
    }

    var canDownloadRide: Bool {
        guard let detail else { return false }

        // No habilitar RIDE solo por permiso. Si no existe artefacto ni acción del backend,
        // el botón confunde y termina intentando descargar un PDF inexistente.
        return detail.allows(.downloadRide) || detail.artifacts.ride != nil || detail.summary.hasRide
    }

    var canDownloadXml: Bool {
        canDownloadAuthorizedXml || canDownloadSignedXml
    }

    var canDownloadAuthorizedXml: Bool {
        guard let detail else { return false }

        return detail.artifacts.authorizedXml != nil ||
            detail.artifacts.xml?.kind == .authorizedXml ||
            (detail.allows(.downloadXml) && BusinessDocumentStatusPresentation.isAuthorized(detail.sriStatus))
    }

    var canDownloadSignedXml: Bool {
        guard let detail else { return false }

        return detail.artifacts.signedXml != nil ||
            (!BusinessDocumentStatusPresentation.isAuthorized(detail.sriStatus) && detail.allows(.downloadXml))
    }

    var primaryXmlButtonTitle: String {
        canDownloadAuthorizedXml ? "Ver XML autorizado" : "Ver XML firmado"
    }

    var primaryXmlShareTitle: String {
        canDownloadAuthorizedXml ? "Compartir XML autorizado" : "Compartir XML firmado"
    }

    var primaryXmlAuthorizedOnly: Bool {
        canDownloadAuthorizedXml
    }

    var artifactAvailabilityHint: String? {
        guard let detail else { return nil }

        if !BusinessDocumentStatusPresentation.isAuthorized(detail.sriStatus), detail.artifacts.ride == nil {
            return "El RIDE solo estará disponible cuando la factura sea autorizada o cuando el backend permita regenerarlo."
        }

        if canDownloadSignedXml && !canDownloadAuthorizedXml {
            return "Esta factura aún no tiene XML autorizado. Puedes revisar el XML firmado para diagnóstico."
        }

        return nil
    }

    var canViewTimeline: Bool {
        guard detail != nil else { return false }

        return true
    }

    var canSendEmail: Bool {
        guard let detail else { return false }

        let backendAllowsEmail = detail.allows(.resendEmail) || detail.retrySummary.canResendEmail
        let hasRecipient =
            emptyToNil(recipientOverride) != nil ||
            emptyToNil(detail.email.recipient ?? "") != nil ||
            emptyToNil(detail.customerEmail ?? "") != nil ||
            emptyToNil(detail.summary.effectiveCustomerEmail ?? "") != nil
        let hasEmailPermission = hasPermission([
            "documents.electronic_invoice.email",
            "documents.electronic_invoice.resend_email",
            "documents.resend_email"
        ])

        // El usuario puede escribir un correo alternativo, pero la acción solo se habilita
        // si backend la expone y el usuario tiene permiso. iOS no inventa acciones.
        return backendAllowsEmail && hasRecipient && hasEmailPermission
    }

    var canRetryReception: Bool {
        guard let detail else { return false }

        return detail.allows(.retryReception) || detail.retrySummary.canRetryReception
    }

    var canRetryAuthorization: Bool {
        guard let detail else { return false }

        return detail.allows(.retryAuthorization) || detail.retrySummary.canRetryAuthorization
    }

    var canRegenerateRide: Bool {
        guard let detail else { return false }

        return detail.allows(.regenerateRide) || detail.retrySummary.canRegenerateRide
    }

    var canSubmitEmailResend: Bool {
        canSendEmail && !emailReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var operationalSummaryRows: [(title: String, value: String)] {
        guard let detail else { return [] }
        var rows: [(String, String)] = []
        if detail.retrySummary.receptionRetryCount > 0 {
            rows.append(("Reintentos recepción", "\(detail.retrySummary.receptionRetryCount)"))
        }
        if detail.retrySummary.authorizationRetryCount > 0 {
            rows.append(("Reintentos autorización", "\(detail.retrySummary.authorizationRetryCount)"))
        }
        if detail.retrySummary.emailAttempts > 0 {
            rows.append(("Intentos email", "\(detail.retrySummary.emailAttempts)"))
        }
        if detail.retrySummary.rideRegenerationCount > 0 {
            rows.append(("Regeneraciones RIDE", "\(detail.retrySummary.rideRegenerationCount)"))
        }
        return rows
    }

    var operationalMessage: String? {
        detail?.retrySummary.message.flatMap(BusinessDocumentTextSanitizer.sanitizedMessage)
    }

    var shouldShowRetryReception: Bool { canRetryReception }

    var shouldShowRetryAuthorization: Bool { canRetryAuthorization }

    var shouldShowRegenerateRide: Bool { canRegenerateRide }

    var hasOperationalActions: Bool {
        shouldShowRetryReception || shouldShowRetryAuthorization || shouldShowRegenerateRide
    }

    func load() async {
        guard canView else {
            errorMessage = "No tienes permiso para consultar este comprobante."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer { isLoading = false }

        do {
            let response = try await repository.electronicDocumentDetail(
                organizationId: organizationId,
                documentId: documentId
            )
            detail = response.document
            timeline = response.document.timeline
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadTimeline() async {
        guard canViewTimeline else {
            errorMessage = "No tienes permiso para consultar la auditoría del comprobante."
            return
        }

        guard !isLoadingTimeline else { return }

        isLoadingTimeline = true
        errorMessage = nil
        infoMessage = nil

        defer { isLoadingTimeline = false }

        do {
            let response = try await repository.electronicDocumentTimeline(
                organizationId: organizationId,
                documentId: documentId,
                limit: 100
            )
            timeline = response.events
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadRide() async {
        await previewRide()
    }

    func downloadXml(authorizedOnly: Bool = true) async {
        await previewXml(authorizedOnly: authorizedOnly)
    }

    func previewRide() async {
        guard let file = await prepareRideFile() else { return }
        previewFile = file
        infoMessage = "\(file.humanName) listo para visualizar."
    }

    func shareRide() async {
        guard let file = await prepareRideFile() else { return }
        shareFile = file
        infoMessage = "\(file.humanName) listo para compartir."
    }

    func previewPrimaryXml() async {
        await previewXml(authorizedOnly: primaryXmlAuthorizedOnly)
    }

    func sharePrimaryXml() async {
        await shareXml(authorizedOnly: primaryXmlAuthorizedOnly)
    }

    func previewXml(authorizedOnly: Bool = true) async {
        guard let file = await prepareXmlFile(authorizedOnly: authorizedOnly) else { return }
        previewFile = file
        infoMessage = "\(file.humanName) listo para visualizar."
    }

    func shareXml(authorizedOnly: Bool = true) async {
        guard let file = await prepareXmlFile(authorizedOnly: authorizedOnly) else { return }
        shareFile = file
        infoMessage = "\(file.humanName) listo para compartir."
    }

    func resendEmail() async {
        guard canSubmitEmailResend else {
            errorMessage = canSendEmail
            ? "Ingresa un motivo para reenviar el email."
            : "No tienes permiso para reenviar comprobantes por email."
            return
        }

        guard beginAction(.resendEmail) else { return }
        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.resendEmail) }

        do {
            let response = try await repository.resendElectronicDocumentEmail(
                organizationId: organizationId,
                documentId: documentId,
                idempotencyKey: .generate(prefix: "document-resend-email"),
                request: BusinessDocumentEmailResendRequest(
                    recipientOverride: emptyToNil(recipientOverride),
                    reason: emailReason,
                    allowResend: true
                )
            )
            infoMessage = response.recipient.map { "Email reenviado a \($0)." } ?? response.message
            await refreshAfterMutation()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryReception() async {
        guard canRetryReception else {
            errorMessage = "No tienes permiso para reintentar recepción."
            return
        }

        guard beginAction(.retryReception) else { return }
        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.retryReception) }

        do {
            _ = try await repository.retryElectronicInvoiceReception(
                organizationId: organizationId,
                documentId: documentId,
                branchId: detail?.summary.branchId,
                activityId: nil,
                idempotencyKey: .generate(prefix: "document-retry-reception"),
                request: RetryBusinessElectronicInvoiceReceptionRequest(queryAuthorizationImmediately: true, reason: retryReason)
            )
            infoMessage = "Reintento de recepción enviado correctamente."
            await refreshAfterMutation()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryAuthorization() async {
        guard canRetryAuthorization else {
            errorMessage = "No tienes permiso para reintentar autorización."
            return
        }

        guard beginAction(.retryAuthorization) else { return }
        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.retryAuthorization) }

        do {
            let response = try await repository.retryElectronicInvoiceAuthorization(
                organizationId: organizationId,
                documentId: documentId,
                branchId: detail?.summary.branchId,
                activityId: nil,
                idempotencyKey: .generate(prefix: "document-retry-authorization"),
                request: RetryBusinessElectronicInvoiceAuthorizationRequest(reason: retryReason)
            )
            infoMessage = response.message
            await refreshAfterMutation()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func regenerateRide() async {
        guard canRegenerateRide else {
            errorMessage = "No tienes permiso para regenerar el RIDE."
            return
        }

        guard beginAction(.regenerateRide) else { return }
        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.regenerateRide) }

        do {
            let response = try await repository.regenerateElectronicDocumentRide(
                organizationId: organizationId,
                documentId: documentId,
                branchId: detail?.summary.branchId,
                activityId: nil,
                idempotencyKey: .generate(prefix: "document-regenerate-ride"),
                request: RegenerateBusinessElectronicDocumentRideRequest(reason: rideRegenerationReason, forceRegenerateRide: true)
            )
            infoMessage = response.message
            await refreshAfterMutation()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshAfterMutation() async {
        await load()
        if canViewTimeline {
            await loadTimeline()
        }
        await onDocumentMutated?()
    }

    private func prepareRideFile() async -> BusinessDocumentDownloadedFile? {
        guard canDownloadRide else {
            errorMessage = "No tienes permiso para descargar el RIDE."
            return nil
        }

        guard beginAction(.downloadRide) else { return nil }
        guard let repository = fileDownloadingRepository else {
            finishAction(.downloadRide)
            errorMessage = "La descarga de archivos no está disponible en esta versión."
            return nil
        }

        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.downloadRide) }

        do {
            let file = try await repository.downloadElectronicDocumentRideFile(
                organizationId: organizationId,
                documentId: documentId
            )
            lastDownloadedFile = file
            lastArtifact = detail?.artifacts.ride
            return file
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    private func prepareXmlFile(authorizedOnly: Bool) async -> BusinessDocumentDownloadedFile? {
        guard authorizedOnly ? canDownloadAuthorizedXml : canDownloadSignedXml else {
            errorMessage = authorizedOnly
                ? "El XML autorizado todavía no está disponible para este comprobante."
                : "El XML firmado todavía no está disponible para este comprobante."
            return nil
        }

        guard beginAction(.downloadXml) else { return nil }
        guard let repository = fileDownloadingRepository else {
            finishAction(.downloadXml)
            errorMessage = "La descarga de archivos no está disponible en esta versión."
            return nil
        }

        errorMessage = nil
        infoMessage = nil

        defer { finishAction(.downloadXml) }

        do {
            let file = try await repository.downloadElectronicDocumentXmlFile(
                organizationId: organizationId,
                documentId: documentId,
                authorizedOnly: authorizedOnly
            )
            lastDownloadedFile = file
            lastArtifact = authorizedOnly
            ? (detail?.artifacts.authorizedXml ?? detail?.artifacts.xml)
            : detail?.artifacts.signedXml
            return file
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }

        return nil
    }

    private func beginAction(_ action: BusinessElectronicDocumentAction) -> Bool {
        guard loadingAction == nil else { return false }
        loadingAction = action
        return true
    }

    private func finishAction(_ action: BusinessElectronicDocumentAction) {
        if loadingAction == action {
            loadingAction = nil
        }
    }

    private var fileDownloadingRepository: BusinessDocumentFileDownloadingRepository? {
        repository as? BusinessDocumentFileDownloadingRepository
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        if effectivePermissions.contains("*") { return true }
        if effectivePermissions.contains("admin") { return true }
        return candidates.contains { effectivePermissions.contains($0) }
    }

    private func emptyToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func handle(apiError: APIError) {
        switch apiError {
        case .server(let statusCode, _, let message, _):
            if statusCode == 401 {
                errorMessage = "Tu sesión expiró. Vuelve a iniciar sesión."
            } else if statusCode == 403 {
                errorMessage = "No tienes permiso para realizar esta acción."
            } else if statusCode == 404 {
                errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(message) ?? "Comprobante no encontrado."
            } else {
                errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(message) ?? "No se pudo completar la solicitud."
            }
        case .missingAccessToken:
            errorMessage = "Tu sesión expiró. Vuelve a iniciar sesión."
        case .transport(let message):
            errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(message) ?? "No se pudo conectar con el servidor."
        case .decodingFailed(_):
            errorMessage = "La respuesta del servidor no tiene el formato esperado."
        case .emptyResponse:
            errorMessage = "El servidor respondió sin contenido."
        case .invalidURL:
            errorMessage = "La dirección del servidor no es válida."
        case .encodingFailed(let message):
            errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(message) ?? "No se pudo preparar la solicitud."
        }
    }
}

extension BusinessElectronicDocumentDetail {
    var isAuthorizedForBusinessDisplay: Bool {
        if authorizedAt != nil { return true }

        if let authorizationNumber,
           !authorizationNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }

        let values = [
            sriStatus,
            status,
            sri.authorizationStatus,
            summary.sriStatus,
            summary.status
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return values.contains { value in
            value == "authorized" ||
            value == "autorizado" ||
            value.contains("authorized") ||
            value.contains("autorizado") ||
            value.contains("autorizada") ||
            value.contains("autoriz")
        }
    }
}
