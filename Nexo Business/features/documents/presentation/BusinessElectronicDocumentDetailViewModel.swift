import Foundation
import Observation

@MainActor
@Observable
final class BusinessElectronicDocumentDetailViewModel {
    private(set) var detail: BusinessElectronicDocumentDetail?
    private(set) var timeline: [BusinessElectronicDocumentTimelineEvent] = []
    private(set) var lastArtifact: BusinessDocumentArtifact?
    private(set) var isLoading = false
    private(set) var isLoadingTimeline = false
    private(set) var isDownloadingRide = false
    private(set) var isDownloadingXml = false
    private(set) var isSendingEmail = false
    private(set) var isRetryingReception = false
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
        guard canDownloadRide else {
            errorMessage = "No tienes permiso para descargar el RIDE."
            return
        }

        guard !isDownloadingRide else { return }

        isDownloadingRide = true
        errorMessage = nil
        infoMessage = nil

        defer { isDownloadingRide = false }

        do {
            let response = try await repository.electronicDocumentRide(
                organizationId: organizationId,
                documentId: documentId
            )
            lastArtifact = response.ride ?? response.artifact
            infoMessage = lastArtifact.map { "RIDE disponible: \($0.fileName)" } ?? "RIDE consultado correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func downloadXml(authorizedOnly: Bool = true) async {
        guard canDownloadXml else {
            errorMessage = "No tienes permiso para descargar XML."
            return
        }

        guard !isDownloadingXml else { return }

        isDownloadingXml = true
        errorMessage = nil
        infoMessage = nil

        defer { isDownloadingXml = false }

        do {
            let response = try await repository.electronicDocumentXml(
                organizationId: organizationId,
                documentId: documentId,
                authorizedOnly: authorizedOnly
            )
            lastArtifact = response.xml ?? response.artifact
            infoMessage = lastArtifact.map { "XML disponible: \($0.fileName)" } ?? "XML consultado correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
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

    func resetMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage
        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        effectivePermissions.contains("*") || candidates.contains { effectivePermissions.contains($0) }
    }

    private func emptyToNil(_ value: String) -> String? {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
