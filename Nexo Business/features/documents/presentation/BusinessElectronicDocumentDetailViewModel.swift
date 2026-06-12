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
    private(set) var isDownloadingRide = false
    private(set) var isDownloadingXml = false
    private(set) var isSendingEmail = false
    private(set) var isRetryingReception = false
    var previewFile: BusinessDocumentDownloadedFile?
    var shareFile: BusinessDocumentDownloadedFile?
    var recipientOverride = ""
    var emailReason = "Reenvío solicitado por el cliente"
    var errorMessage: String?
    var infoMessage: String?
    
    let organizationId: String
    let documentId: String
    let effectivePermissions: Set<String>
    private let repository: BusinessDocumentsRepository
    
    init(
        organizationId: String,
        documentId: String,
        effectivePermissions: Set<String>,
        documentsRepository: BusinessDocumentsRepository,
        initialDetail: BusinessElectronicDocumentDetail? = nil
    ) {
        self.organizationId = organizationId
        self.documentId = documentId
        self.effectivePermissions = effectivePermissions
        self.repository = documentsRepository
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
        hasPermission([
            "documents.electronic_invoice.download_ride",
            "documents.download_pdf"
        ])
    }
    
    var canDownloadXml: Bool {
        hasPermission([
            "documents.electronic_invoice.download_xml",
            "documents.download_xml"
        ])
    }
    
    var canViewTimeline: Bool {
        hasPermission([
            "documents.electronic_invoice.view_audit",
            "documents.electronic_invoice.view_errors"
        ])
    }
    
    var canSendEmail: Bool {
        hasPermission([
            "documents.electronic_invoice.email"
        ])
    }
    
    var canRetryReception: Bool {
        hasPermission([
            "documents.electronic_invoice.retry",
            "documents.electronic_invoice.issue",
            "documents.issue_electronic_invoice",
            "business.documents.issue_electronic_invoice"
        ])
    }
    
    var canSubmitEmailResend: Bool {
        canSendEmail && !isSendingEmail && !emailReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var shouldShowRetryReception: Bool {
        guard canRetryReception else { return false }
        guard let detail else { return false }
        
        if detail.isAuthorizedForBusinessDisplay { //Value of type 'BusinessElectronicDocumentDetail' has no member 'isAuthorizedForBusinessDisplay'
            return false
        }
        
        let statusCandidates = [
            detail.sriStatus,
            detail.status,
            detail.sri.receptionStatus,
            detail.sri.authorizationStatus
        ]
            .compactMap { $0?.lowercased() }
        
        return statusCandidates.contains { value in
            value.contains("failed")
            || value.contains("error")
            || value.contains("transport")
            || value.contains("returned")
            || value.contains("devuelta")
            || value.contains("rejected")
            || value.contains("rechaz")
            || value.contains("pending")
            || value.contains("pendiente")
        }
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
        infoMessage = "RIDE listo para visualizar."
    }
    
    func shareRide() async {
        guard let file = await prepareRideFile() else { return }
        shareFile = file
        infoMessage = "RIDE listo para compartir."
    }
    
    func previewXml(authorizedOnly: Bool = true) async {
        guard let file = await prepareXmlFile(authorizedOnly: authorizedOnly) else { return }
        previewFile = file
        infoMessage = "XML autorizado listo para visualizar."
    }
    
    func shareXml(authorizedOnly: Bool = true) async {
        guard let file = await prepareXmlFile(authorizedOnly: authorizedOnly) else { return }
        shareFile = file
        infoMessage = "XML autorizado listo para compartir."
    }
    
    func resendEmail() async {
        guard canSubmitEmailResend else {
            errorMessage = canSendEmail
            ? "Ingresa un motivo para reenviar el email."
            : "No tienes permiso para reenviar comprobantes por email."
            return
        }
        
        guard !isSendingEmail else { return }
        
        isSendingEmail = true
        errorMessage = nil
        infoMessage = nil
        
        defer { isSendingEmail = false }
        
        do {
            let response = try await repository.resendElectronicDocumentEmail(
                organizationId: organizationId,
                documentId: documentId,
                request: BusinessDocumentEmailResendRequest(
                    recipientOverride: emptyToNil(recipientOverride),
                    reason: emailReason,
                    allowResend: true
                )
            )
            infoMessage = response.recipient.map { "Email reenviado a \($0)." } ?? response.message
            await load()
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
        
        guard !isRetryingReception else { return }
        
        isRetryingReception = true
        errorMessage = nil
        infoMessage = nil
        
        defer { isRetryingReception = false }
        
        do {
            _ = try await repository.retryElectronicInvoiceReception(
                organizationId: organizationId,
                documentId: documentId,
                branchId: detail?.summary.branchId,
                activityId: nil,
                idempotencyKey: .generate(prefix: "document-retry-reception"),
                request: RetryBusinessElectronicInvoiceReceptionRequest(queryAuthorizationImmediately: true)
            )
            infoMessage = "Reintento enviado correctamente."
            await load()
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func prepareRideFile() async -> BusinessDocumentDownloadedFile? {
        guard canDownloadRide else {
            errorMessage = "No tienes permiso para descargar el RIDE."
            return nil
        }
        
        guard !isDownloadingRide else { return nil }
        guard let repository = fileDownloadingRepository else {
            errorMessage = "La descarga de archivos no está disponible en esta versión."
            return nil
        }
        
        isDownloadingRide = true
        errorMessage = nil
        infoMessage = nil
        
        defer { isDownloadingRide = false }
        
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
        guard canDownloadXml else {
            errorMessage = "No tienes permiso para descargar XML."
            return nil
        }
        
        guard !isDownloadingXml else { return nil }
        guard let repository = fileDownloadingRepository else {
            errorMessage = "La descarga de archivos no está disponible en esta versión."
            return nil
        }
        
        isDownloadingXml = true
        errorMessage = nil
        infoMessage = nil
        
        defer { isDownloadingXml = false }
        
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
