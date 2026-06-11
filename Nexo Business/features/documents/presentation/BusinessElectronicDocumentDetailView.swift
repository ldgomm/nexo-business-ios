import SwiftUI

struct BusinessElectronicDocumentDetailView: View {
    @Bindable private var viewModel: BusinessElectronicDocumentDetailViewModel

    init(viewModel: BusinessElectronicDocumentDetailViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            if viewModel.isLoading && viewModel.detail == nil {
                Section {
                    ProgressView("Cargando comprobante…")
                }
            }

            if let detail = viewModel.detail {
                summarySection(detail)
                sriSection(detail)
                artifactsSection(detail)
                emailSection(detail)
                errorsSection(detail)
                timelineSection
                actionsSection
            }

            messagesSection
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Comprobante")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            if viewModel.shouldLoadOnAppear {
                await viewModel.load()
            }
        }
    }

    private func summarySection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        Section("Resumen") {
            LabeledContent("Número", value: detail.displayNumber)
            LabeledContent("Tipo", value: BusinessDocumentTypePresentation.displayName(detail.documentType))
            LabeledContent("Estado", value: BusinessDocumentStatusPresentation.displayName(detail.sriStatus))
            LabeledContent("Ambiente", value: detail.environment.uppercased())

            if let total = detail.total, !total.isEmpty {
                LabeledContent("Total", value: "\(detail.currency) \(total)")
            }

            if let saleId = detail.saleId, !saleId.isEmpty {
                LabeledContent("Venta", value: saleId)
            }

            if let issueDate = detail.issueDate {
                LabeledContent("Emitido", value: issueDate.formatted(date: .abbreviated, time: .shortened))
            }

            if let authorizedAt = detail.authorizedAt {
                LabeledContent("Autorizado", value: authorizedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func sriSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        Section("SRI") {
            if !detail.accessKey.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clave de acceso")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(detail.accessKey)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let authorizationNumber = detail.authorizationNumber, !authorizationNumber.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Número de autorización")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(authorizationNumber)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }

            if let receptionStatus = detail.sri.receptionStatus, !receptionStatus.isEmpty {
                LabeledContent("Recepción", value: BusinessDocumentStatusPresentation.displayName(receptionStatus))
            }

            if let authorizationStatus = detail.sri.authorizationStatus, !authorizationStatus.isEmpty {
                LabeledContent("Autorización", value: BusinessDocumentStatusPresentation.displayName(authorizationStatus))
            }

            if let lastCheckedAt = detail.sri.lastCheckedAt {
                LabeledContent("Última revisión", value: lastCheckedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
    }

    private func artifactsSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        Section("Archivos") {
            ArtifactAvailabilityRow(title: "RIDE", artifact: detail.artifacts.ride)
            ArtifactAvailabilityRow(title: "XML autorizado", artifact: detail.artifacts.authorizedXml ?? detail.artifacts.xml)
            ArtifactAvailabilityRow(title: "XML firmado", artifact: detail.artifacts.signedXml)

            Button {
                Task { await viewModel.downloadRide() }
            } label: {
                if viewModel.isDownloadingRide {
                    ProgressView()
                } else {
                    Label("Consultar RIDE", systemImage: "doc.richtext")
                }
            }
            .disabled(!viewModel.canDownloadRide || viewModel.isDownloadingRide)

            Button {
                Task { await viewModel.downloadXml(authorizedOnly: true) }
            } label: {
                if viewModel.isDownloadingXml {
                    ProgressView()
                } else {
                    Label("Consultar XML autorizado", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .disabled(!viewModel.canDownloadXml || viewModel.isDownloadingXml)

            if let artifact = viewModel.lastArtifact {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Último archivo consultado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(artifact.fileName)
                        .font(.caption.monospaced())
                    if let sha256 = artifact.sha256, !sha256.isEmpty {
                        Text(sha256)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func emailSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        Section("Email") {
            LabeledContent("Destinatario", value: detail.email.recipient ?? detail.customerEmail ?? "—")
            LabeledContent("Estado", value: detail.email.status.map(BusinessDocumentStatusPresentation.displayName) ?? "—")

            if let sentAt = detail.email.sentAt {
                LabeledContent("Enviado", value: sentAt.formatted(date: .abbreviated, time: .shortened))
            }

            if let lastError = detail.email.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            TextField("Correo alternativo opcional", text: $viewModel.recipientOverride)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)

            TextField("Motivo del reenvío", text: $viewModel.emailReason, axis: .vertical)
                .lineLimit(1...3)

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.resendEmail() }
            } label: {
                if viewModel.isSendingEmail {
                    ProgressView()
                } else {
                    Label("Reenviar email", systemImage: "envelope.arrow.triangle.branch")
                }
            }
            .disabled(!viewModel.canSubmitEmailResend)
        }
    }

    @ViewBuilder
    private func errorsSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        if !detail.errors.isEmpty || !detail.warnings.isEmpty {
            Section("Errores y advertencias") {
                ForEach(detail.errors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.userMessage ?? error.message ?? error.rawMessage ?? "Error SRI")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)

                        if let code = error.code, !code.isEmpty {
                            Text(code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(detail.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var timelineSection: some View {
        Section("Timeline") {
            if viewModel.timeline.isEmpty {
                Label("Sin eventos visibles", systemImage: "clock")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.timeline) { event in
                    TimelineEventRow(event: event)
                }
            }

            Button {
                Task { await viewModel.loadTimeline() }
            } label: {
                if viewModel.isLoadingTimeline {
                    ProgressView()
                } else {
                    Label("Actualizar timeline", systemImage: "clock.arrow.circlepath")
                }
            }
            .disabled(!viewModel.canViewTimeline || viewModel.isLoadingTimeline)
        }
    }

    private var actionsSection: some View {
        Section("Acciones operativas") {
            Button {
                Task { await viewModel.retryReception() }
            } label: {
                if viewModel.isRetryingReception {
                    ProgressView()
                } else {
                    Label("Reintentar recepción SRI", systemImage: "arrow.triangle.2.circlepath")
                }
            }
            .disabled(!viewModel.canRetryReception || viewModel.isRetryingReception)

            Text("Estas acciones usan el backend Business canónico. No activan producción ni generan una nueva factura.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = viewModel.errorMessage {
            Section {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }

        if let message = viewModel.infoMessage {
            Section {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ArtifactAvailabilityRow: View {
    let title: String
    let artifact: BusinessDocumentArtifact?

    var body: some View {
        HStack {
            Label(title, systemImage: artifact == nil ? "minus.circle" : "checkmark.circle")
                .foregroundStyle(artifact == nil ? .secondary : .primary)
            Spacer()
            Text(artifact?.fileName ?? "No disponible")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct TimelineEventRow: View {
    let event: BusinessElectronicDocumentTimelineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(event.title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                Spacer()
                if let createdAt = event.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = event.message, !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let actor = event.actor, !actor.isEmpty {
                Text(actor)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 3)
    }

    private var systemImage: String {
        if event.severity?.localizedCaseInsensitiveContains("error") == true {
            return "exclamationmark.triangle"
        }
        return "clock"
    }
}

#Preview {
    NavigationStack {
        BusinessElectronicDocumentDetailView(
            viewModel: BusinessElectronicDocumentDetailViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                documentId: "edoc_preview_invoice",
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                documentsRepository: PreviewBusinessDocumentsRepository()
            )
        )
    }
}
