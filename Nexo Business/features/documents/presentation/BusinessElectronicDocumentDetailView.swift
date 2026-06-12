//
//  BusinessElectronicDocumentDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

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
                operationalSummarySection(detail)
                timelineSection
                if viewModel.hasOperationalActions {
                    actionsSection
                }
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
        .sheet(item: $viewModel.previewFile) { file in
            BusinessDocumentQuickLookPreview(fileURL: file.localURL)
        }
        .sheet(item: $viewModel.shareFile) { file in
            BusinessDocumentShareSheet(items: [file.localURL])
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

            HStack {
                Button {
                    Task { await viewModel.previewRide() }
                } label: {
                    if viewModel.isDownloadingRide {
                        ProgressView()
                    } else {
                        Label("Ver RIDE", systemImage: "doc.richtext")
                    }
                }
                .disabled(!viewModel.canDownloadRide || viewModel.isPerformingAction)

                Spacer()

                Button {
                    Task { await viewModel.shareRide() }
                } label: {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.canDownloadRide || viewModel.isPerformingAction)
            }

            HStack {
                Button {
                    Task { await viewModel.previewXml(authorizedOnly: true) }
                } label: {
                    if viewModel.isDownloadingXml {
                        ProgressView()
                    } else {
                        Label("Ver XML autorizado", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
                .disabled(!viewModel.canDownloadXml || viewModel.isPerformingAction)

                Spacer()

                Button {
                    Task { await viewModel.shareXml(authorizedOnly: true) }
                } label: {
                    Label("Compartir", systemImage: "square.and.arrow.up")
                }
                .disabled(!viewModel.canDownloadXml || viewModel.isPerformingAction)
            }

            if let file = viewModel.lastDownloadedFile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Último archivo preparado")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(file.humanName) · \(file.sizeBytes) bytes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

            if let lastError = BusinessDocumentTextSanitizer.sanitizedMessage(detail.email.lastError) {
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
            .disabled(!viewModel.canSubmitEmailResend || viewModel.isPerformingAction)
        }
    }

    @ViewBuilder
    private func errorsSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        if !detail.errors.isEmpty || !detail.warnings.isEmpty {
            Section("Errores y advertencias") {
                ForEach(detail.errors) { error in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error.safeDisplayMessage)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)

                        if let code = error.safeCode, !code.isEmpty {
                            Text(code)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ForEach(detail.warnings.compactMap(BusinessDocumentTextSanitizer.sanitizedMessage), id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }


    @ViewBuilder
    private func operationalSummarySection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        if !detail.availableActions.isEmpty || viewModel.operationalMessage != nil || !viewModel.operationalSummaryRows.isEmpty {
            Section("Operación") {
                if !detail.availableActions.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Acciones habilitadas por backend")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        FlowTextList(values: detail.availableActions.map(\.displayName))
                    }
                }

                ForEach(viewModel.operationalSummaryRows, id: \.title) { row in
                    LabeledContent(row.title, value: row.value)
                }

                if let message = viewModel.operationalMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .disabled(!viewModel.canViewTimeline || viewModel.isLoadingTimeline || viewModel.isPerformingAction)
        }
    }

    private var actionsSection: some View {
        Section("Acciones operativas") {
            if viewModel.shouldShowRetryReception {
                Button {
                    Task { await viewModel.retryReception() }
                } label: {
                    if viewModel.isRetryingReception {
                        ProgressView()
                    } else {
                        Label("Reintentar recepción SRI", systemImage: "arrow.up.doc")
                    }
                }
                .disabled(viewModel.isPerformingAction)
            }

            if viewModel.shouldShowRetryAuthorization {
                Button {
                    Task { await viewModel.retryAuthorization() }
                } label: {
                    if viewModel.isRetryingAuthorization {
                        ProgressView()
                    } else {
                        Label("Reintentar autorización SRI", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(viewModel.isPerformingAction)
            }

            if viewModel.shouldShowRegenerateRide {
                Button {
                    Task { await viewModel.regenerateRide() }
                } label: {
                    if viewModel.isRegeneratingRide {
                        ProgressView()
                    } else {
                        Label("Regenerar RIDE", systemImage: "doc.badge.gearshape")
                    }
                }
                .disabled(viewModel.isPerformingAction)
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.errorMessage) {
            Section {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }

        if let infoMessage = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.infoMessage) {
            Section {
                Label(infoMessage, systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
    }
}


private struct FlowTextList: View {
    let values: [String]

    var body: some View {
        Text(values.joined(separator: " · "))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
    }
}

private struct ArtifactAvailabilityRow: View {
    let title: String
    let artifact: BusinessDocumentArtifact?

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                if let artifact {
                    Text(artifact.safeFileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("No disponible")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if artifact == nil {
                Text("Pendiente")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Disponible")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct TimelineEventRow: View {
    let event: BusinessElectronicDocumentTimelineEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title)
                .font(.footnote.weight(.semibold))

            if let message = event.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                if let createdAt = event.createdAt {
                    Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let actor = event.actor, !actor.isEmpty {
                    Text(actor)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
