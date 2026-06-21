//
//  BusinessElectronicDocumentDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct BusinessElectronicDocumentDetailView: View {
    @Bindable private var viewModel: BusinessElectronicDocumentDetailViewModel
    private let customer360Dependencies: Customer360Dependencies?
    private let customersRepository: CustomersRepository?
    @State private var resolvedCustomer: BusinessCustomer?
    @State private var isResolvingCustomer = false
    @State private var customerResolveMessage: String?
    
    init(
        viewModel: BusinessElectronicDocumentDetailViewModel,
        customer360Dependencies: Customer360Dependencies? = nil,
        customersRepository: CustomersRepository? = nil
    ) {
        self.viewModel = viewModel
        self.customer360Dependencies = customer360Dependencies
        self.customersRepository = customersRepository
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if viewModel.isLoading && viewModel.detail == nil {
                    BusinessDocumentLoadingCard()
                }
                
                if let detail = viewModel.detail {
                    messagesSection
                    heroSection(detail)
                    summarySection(detail)
                    customerSection(detail)
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
                
                if viewModel.detail == nil && !viewModel.isLoading {
                    BusinessDocumentEmptyCard(
                        title: "No se pudo mostrar el comprobante",
                        message: "Actualiza la pantalla para consultar nuevamente el estado del comprobante.",
                        systemImage: "doc.text.magnifyingglass"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Comprobante")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar comprobante")
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
            if let detail = viewModel.detail {
                await resolveCustomerIfPossible(detail)
            }
        }
        .onChange(of: viewModel.detail?.documentId) { _, _ in
            Task {
                if let detail = viewModel.detail {
                    await resolveCustomerIfPossible(detail)
                }
            }
        }
    }
    
    private func heroSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentHeroCard(
            number: detail.displayNumber,
            type: BusinessDocumentTypePresentation.displayName(detail.documentType),
            status: BusinessDocumentStatusPresentation.displayName(detail.sriStatus),
            statusSymbol: BusinessDocumentVisual.statusSymbol(for: detail.sriStatus),
            statusTint: BusinessDocumentVisual.statusTint(for: detail.sriStatus),
            environment: detail.environment.uppercased(),
            amount: heroAmount(for: detail),
            issueDate: detail.issueDate,
            authorizedAt: detail.authorizedAt
        )
    }
    
    private func summarySection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentCard(title: "Resumen", systemImage: "doc.text") {
            BusinessDocumentInfoGrid {
                BusinessDocumentInfoTile(
                    title: "Número",
                    value: detail.displayNumber,
                    systemImage: "number"
                )
                BusinessDocumentInfoTile(
                    title: "Tipo",
                    value: BusinessDocumentTypePresentation.displayName(detail.documentType),
                    systemImage: "doc.plaintext"
                )
                BusinessDocumentInfoTile(
                    title: "Ambiente",
                    value: detail.environment.uppercased(),
                    systemImage: "server.rack"
                )
                
                if let total = detail.total, !total.isEmpty {
                    BusinessDocumentInfoTile(
                        title: "Total",
                        value: "\(detail.currency) \(total)",
                        systemImage: "banknote"
                    )
                }
            }
            
            BusinessDocumentDivider()
            
            VStack(spacing: 10) {
                if let issueDate = detail.issueDate {
                    BusinessDocumentInfoRow(
                        title: "Emitido",
                        value: issueDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                }
                
                if let authorizedAt = detail.authorizedAt {
                    BusinessDocumentInfoRow(
                        title: "Autorizado",
                        value: authorizedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "checkmark.seal"
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private func customerSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentCard(title: "Cliente", systemImage: "person.text.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                if let name = detail.customerName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    BusinessDocumentInfoRow(title: "Nombre", value: name, systemImage: "person")
                }

                if let identification = detail.customerIdentification?.trimmingCharacters(in: .whitespacesAndNewlines), !identification.isEmpty {
                    BusinessDocumentInfoRow(title: "Identificación", value: identification, systemImage: "number")
                }

                if let customer = Customer360SeedFactory.customer(from: detail, resolvedCustomer: resolvedCustomer),
                   let customer360Dependencies {
                    NavigationLink {
                        Customer360RouteView(customer: customer, dependencies: customer360Dependencies)
                    } label: {
                        Customer360NavigationLabel(
                            title: "Ver cliente",
                            subtitle: "Ventas, cuentas por cobrar y comprobantes relacionados"
                        )
                    }
                    .buttonStyle(.plain)
                } else if isResolvingCustomer {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Buscando cliente en el directorio…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let customerResolveMessage {
                    BusinessDocumentInlineNotice(message: customerResolveMessage, systemImage: "info.circle", tint: .secondary)
                } else if detail.customerName == nil && detail.customerIdentification == nil {
                    BusinessDocumentInlineNotice(message: "Este comprobante no trae datos de cliente suficientes para abrir ficha 360.", systemImage: "person.crop.circle.badge.questionmark", tint: .secondary)
                }
            }
        }
    }

    private func sriSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentCard(title: "SRI", systemImage: "building.columns") {
            VStack(spacing: 12) {
                if !detail.accessKey.isEmpty {
                    BusinessDocumentCopyBlock(
                        title: "Clave de acceso",
                        value: detail.accessKey,
                        systemImage: "key"
                    )
                }
                
                if let authorizationNumber = detail.authorizationNumber, !authorizationNumber.isEmpty {
                    BusinessDocumentCopyBlock(
                        title: "Número de autorización",
                        value: authorizationNumber,
                        systemImage: "signature"
                    )
                }
                
                if let receptionStatus = detail.sri.receptionStatus, !receptionStatus.isEmpty {
                    BusinessDocumentStatusRow(
                        title: "Recepción",
                        status: BusinessDocumentStatusPresentation.displayName(receptionStatus),
                        rawStatus: receptionStatus
                    )
                }
                
                if let authorizationStatus = detail.sri.authorizationStatus, !authorizationStatus.isEmpty {
                    BusinessDocumentStatusRow(
                        title: "Autorización",
                        status: BusinessDocumentStatusPresentation.displayName(authorizationStatus),
                        rawStatus: authorizationStatus
                    )
                }
                
                if let lastCheckedAt = detail.sri.lastCheckedAt {
                    BusinessDocumentInfoRow(
                        title: "Última revisión",
                        value: lastCheckedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "clock.arrow.circlepath"
                    )
                }
            }
        }
    }
    
    private func artifactsSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentCard(title: "Archivos", systemImage: "folder") {
            VStack(spacing: 10) {
                ArtifactAvailabilityRow(title: "RIDE", artifact: detail.artifacts.ride)
                ArtifactAvailabilityRow(title: "XML autorizado", artifact: detail.artifacts.authorizedXml ?? detail.artifacts.xml)
                ArtifactAvailabilityRow(title: "XML firmado", artifact: detail.artifacts.signedXml)
            }
            
            if let hint = viewModel.artifactAvailabilityHint {
                BusinessDocumentInlineNotice(
                    message: hint,
                    systemImage: "info.circle",
                    tint: .secondary
                )
            }
            
            BusinessDocumentDivider()
            
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    BusinessDocumentActionButton(
                        title: "Ver RIDE",
                        systemImage: "doc.richtext",
                        isLoading: viewModel.isDownloadingRide,
                        isDisabled: !viewModel.canDownloadRide || viewModel.isDownloadingRide,
                        style: .primary
                    ) {
                        Task { await viewModel.previewRide() }
                    }
                    
                    BusinessDocumentActionButton(
                        title: "Compartir",
                        systemImage: "square.and.arrow.up",
                        isLoading: false,
                        isDisabled: !viewModel.canDownloadRide || viewModel.isDownloadingRide,
                        style: .secondary
                    ) {
                        Task { await viewModel.shareRide() }
                    }
                }
                
                HStack(spacing: 10) {
                    BusinessDocumentActionButton(
                        title: viewModel.primaryXmlButtonTitle,
                        systemImage: "chevron.left.forwardslash.chevron.right",
                        isLoading: viewModel.isDownloadingXml,
                        isDisabled: !viewModel.canDownloadXml || viewModel.isDownloadingXml,
                        style: .primary
                    ) {
                        Task { await viewModel.previewPrimaryXml() }
                    }
                    
                    BusinessDocumentActionButton(
                        title: viewModel.primaryXmlShareTitle,
                        systemImage: "square.and.arrow.up",
                        isLoading: false,
                        isDisabled: !viewModel.canDownloadXml || viewModel.isDownloadingXml,
                        style: .secondary
                    ) {
                        Task { await viewModel.sharePrimaryXml() }
                    }
                }
            }
            
            if let summary = viewModel.lastPreparedFileSummary {
                BusinessDocumentPreparedFileSummary(summary: summary)
            }
        }
    }
    
    private func emailSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        BusinessDocumentCard(title: "Email", systemImage: "envelope") {
            VStack(spacing: 10) {
                BusinessDocumentInfoRow(
                    title: "Destinatario",
                    value: detail.email.recipient ?? detail.customerEmail ?? "—",
                    systemImage: "person.crop.circle"
                )
                
                BusinessDocumentInfoRow(
                    title: "Estado",
                    value: BusinessDocumentEmailStatusPresentation.displayName(
                        detail.email.status,
                        recipient: detail.email.recipient ?? detail.customerEmail,
                        sentAt: detail.email.sentAt
                    ),
                    systemImage: BusinessDocumentEmailStatusPresentation.systemImage(
                        detail.email.status,
                        sentAt: detail.email.sentAt
                    )
                )
                
                if let sentAt = detail.email.sentAt {
                    BusinessDocumentInfoRow(
                        title: "Enviado",
                        value: sentAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar.badge.checkmark"
                    )
                }
            }
            
            if let lastError = BusinessDocumentTextSanitizer.sanitizedMessage(detail.email.lastError) {
                BusinessDocumentInlineNotice(
                    message: lastError,
                    systemImage: "exclamationmark.triangle",
                    tint: .red
                )
            }
            
            BusinessDocumentDivider()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Reenvío")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                TextField("Correo alternativo opcional", text: $viewModel.recipientOverride)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textFieldStyle(.roundedBorder)
                
                TextField("Motivo del reenvío", text: $viewModel.emailReason, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                
                BusinessDocumentActionButton(
                    title: "Reenviar email",
                    systemImage: "envelope.arrow.triangle.branch",
                    isLoading: viewModel.isSendingEmail,
                    isDisabled: !viewModel.canSubmitEmailResend || viewModel.isSendingEmail,
                    style: .primary
                ) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.resendEmail() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func errorsSection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        if !detail.errors.isEmpty || !detail.warnings.isEmpty {
            BusinessDocumentCard(title: "Errores y advertencias", systemImage: "exclamationmark.triangle") {
                VStack(spacing: 10) {
                    ForEach(detail.errors) { error in
                        BusinessDocumentIssueRow(
                            title: error.safeDisplayMessage,
                            detail: error.safeCode,
                            systemImage: "xmark.octagon",
                            tint: .red
                        )
                    }
                    
                    ForEach(detail.warnings.compactMap(BusinessDocumentTextSanitizer.sanitizedMessage), id: \.self) { warning in
                        BusinessDocumentIssueRow(
                            title: warning,
                            detail: nil,
                            systemImage: "exclamationmark.circle",
                            tint: .orange
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func operationalSummarySection(_ detail: BusinessElectronicDocumentDetail) -> some View {
        if !detail.availableActions.isEmpty || viewModel.operationalMessage != nil || !viewModel.operationalSummaryRows.isEmpty {
            BusinessDocumentCard(title: "Operación", systemImage: "slider.horizontal.3") {
                if !detail.availableActions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Acciones habilitadas por backend")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                        
                        FlowTextList(values: detail.availableActions.map(\.displayName))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                if !viewModel.operationalSummaryRows.isEmpty {
                    BusinessDocumentDivider()
                    
                    VStack(spacing: 10) {
                        ForEach(viewModel.operationalSummaryRows, id: \.title) { row in
                            BusinessDocumentInfoRow(
                                title: row.title,
                                value: row.value,
                                systemImage: "smallcircle.filled.circle"
                            )
                        }
                    }
                }
                
                if let message = viewModel.operationalMessage {
                    BusinessDocumentInlineNotice(
                        message: message,
                        systemImage: "info.circle",
                        tint: .secondary
                    )
                }
            }
        }
    }
    
    private var timelineSection: some View {
        BusinessDocumentCard(title: "Timeline", systemImage: "clock") {
            if viewModel.timeline.isEmpty {
                BusinessDocumentEmptyCard(
                    title: "Sin eventos visibles",
                    message: "Cuando el backend registre movimientos del comprobante, aparecerán aquí.",
                    systemImage: "clock.badge.questionmark",
                    compact: true
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.timeline.enumerated()), id: \.element.id) { index, event in
                        TimelineEventRow(
                            event: event,
                            isLast: index == viewModel.timeline.count - 1
                        )
                    }
                }
            }
            
            BusinessDocumentActionButton(
                title: "Actualizar timeline",
                systemImage: "clock.arrow.circlepath",
                isLoading: viewModel.isLoadingTimeline,
                isDisabled: !viewModel.canViewTimeline || viewModel.isLoadingTimeline,
                style: .secondary
            ) {
                Task { await viewModel.loadTimeline() }
            }
        }
    }
    
    private var actionsSection: some View {
        BusinessDocumentCard(title: "Acciones operativas", systemImage: "wrench.and.screwdriver") {
            VStack(spacing: 10) {
                if viewModel.shouldShowRetryReception {
                    BusinessDocumentActionButton(
                        title: "Reintentar recepción SRI",
                        systemImage: "arrow.up.doc",
                        isLoading: viewModel.isRetryingReception,
                        isDisabled: viewModel.isPerformingAction,
                        style: .warning
                    ) {
                        Task { await viewModel.retryReception() }
                    }
                }
                
                if viewModel.shouldShowRetryAuthorization {
                    BusinessDocumentActionButton(
                        title: "Reintentar autorización SRI",
                        systemImage: "arrow.triangle.2.circlepath",
                        isLoading: viewModel.isRetryingAuthorization,
                        isDisabled: viewModel.isPerformingAction,
                        style: .warning
                    ) {
                        Task { await viewModel.retryAuthorization() }
                    }
                }
                
                if viewModel.shouldShowRegenerateRide {
                    BusinessDocumentActionButton(
                        title: "Regenerar RIDE",
                        systemImage: "doc.badge.gearshape",
                        isLoading: viewModel.isRegeneratingRide,
                        isDisabled: viewModel.isPerformingAction,
                        style: .secondary
                    ) {
                        Task { await viewModel.regenerateRide() }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var messagesSection: some View {
        if let errorMessage = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.errorMessage) {
            BusinessDocumentBanner(
                message: errorMessage,
                systemImage: "exclamationmark.triangle",
                tint: .red
            )
        }
        
        if let infoMessage = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.infoMessage) {
            BusinessDocumentBanner(
                message: infoMessage,
                systemImage: "checkmark.circle",
                tint: .green
            )
        }
    }
    
    private func resolveCustomerIfPossible(_ detail: BusinessElectronicDocumentDetail) async {
        guard resolvedCustomer == nil else { return }
        guard let customersRepository, customer360Dependencies != nil else { return }
        guard let query = customerLookupQuery(for: detail) else {
            customerResolveMessage = isFinalConsumer(detail) ? "Consumidor final no abre ficha 360." : nil
            return
        }

        isResolvingCustomer = true
        customerResolveMessage = nil
        defer { isResolvingCustomer = false }

        do {
            let response = try await customersRepository.search(
                organizationId: viewModel.organizationId,
                query: query,
                limit: 5
            )

            resolvedCustomer = response.customers.first { customer in
                customer.identificationType != .finalConsumer && (
                    normalized(customer.identificationNumber) == normalized(detail.customerIdentification) ||
                    normalized(customer.displayName) == normalized(detail.customerName)
                )
            } ?? response.customers.first(where: { $0.identificationType != .finalConsumer })

            if resolvedCustomer == nil {
                customerResolveMessage = "El comprobante tiene datos del cliente, pero no encontramos una ficha activa para abrir el 360."
            }
        } catch {
            customerResolveMessage = "No se pudo buscar el cliente ahora. El comprobante sigue disponible."
        }
    }

    private func customerLookupQuery(for detail: BusinessElectronicDocumentDetail) -> String? {
        guard !isFinalConsumer(detail) else { return nil }

        return [
            detail.customerIdentification,
            detail.customerName,
            detail.customerEmail
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func isFinalConsumer(_ detail: BusinessElectronicDocumentDetail) -> Bool {
        normalized(detail.customerName) == "consumidor final" || normalized(detail.customerIdentification) == "9999999999999"
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }

    private func heroAmount(for detail: BusinessElectronicDocumentDetail) -> String? {
        guard let total = detail.total, !total.isEmpty else { return nil }
        return "\(detail.currency) \(total)"
    }
}

private enum BusinessDocumentVisual {
    static func statusTint(for status: String) -> Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if normalized.contains("authorized") || normalized.contains("autoriz") || normalized.contains("delivered") {
            return .green
        }
        
        if normalized.contains("rejected") || normalized.contains("error") || normalized.contains("failed") || normalized.contains("denied") || normalized.contains("rechaz") {
            return .red
        }
        
        if normalized.contains("pending") || normalized.contains("processing") || normalized.contains("generated") || normalized.contains("sent") || normalized.contains("submitted") || normalized.contains("signed") {
            return .orange
        }
        
        return .accentColor
    }
    
    static func statusSymbol(for status: String) -> String {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if normalized.contains("authorized") || normalized.contains("autoriz") || normalized.contains("delivered") {
            return "checkmark.seal.fill"
        }
        
        if normalized.contains("rejected") || normalized.contains("error") || normalized.contains("failed") || normalized.contains("denied") || normalized.contains("rechaz") {
            return "xmark.octagon.fill"
        }
        
        if normalized.contains("pending") || normalized.contains("processing") || normalized.contains("generated") || normalized.contains("sent") || normalized.contains("submitted") || normalized.contains("signed") {
            return "clock.badge.exclamationmark.fill"
        }
        
        return "doc.text.fill"
    }
}

private struct BusinessDocumentHeroCard: View {
    let number: String
    let type: String
    let status: String
    let statusSymbol: String
    let statusTint: Color
    let environment: String
    let amount: String?
    let issueDate: Date?
    let authorizedAt: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: statusSymbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 48, height: 48)
                    .background(statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(type.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                            .tracking(0.7)
                        
                        BusinessDocumentPill(text: environment, tint: .secondary)
                    }
                    
                    Text(number)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    
                    BusinessDocumentPill(text: status, systemImage: statusSymbol, tint: statusTint)
                }
                
                Spacer(minLength: 0)
            }
            
            HStack(spacing: 10) {
                if let amount {
                    BusinessDocumentHeroMetric(title: "Total", value: amount, systemImage: "banknote")
                }
                
                if let issueDate {
                    BusinessDocumentHeroMetric(
                        title: "Emitido",
                        value: issueDate.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                }
            }
            
            if let authorizedAt {
                BusinessDocumentInfoRow(
                    title: "Autorizado",
                    value: authorizedAt.formatted(date: .abbreviated, time: .shortened),
                    systemImage: "checkmark.seal"
                )
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 16, x: 0, y: 8)
        )
    }
}

private struct BusinessDocumentHeroMetric: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentCard<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content
    
    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer(minLength: 0)
            }
            
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.035), radius: 12, x: 0, y: 6)
        )
    }
}

private struct BusinessDocumentInfoGrid<Content: View>: View {
    private let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            content
        }
    }
}

private struct BusinessDocumentInfoTile: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentInfoRow: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22)
            
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 12)
            
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BusinessDocumentStatusRow: View {
    let title: String
    let status: String
    let rawStatus: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: BusinessDocumentVisual.statusSymbol(for: rawStatus))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(BusinessDocumentVisual.statusTint(for: rawStatus))
                .frame(width: 22)
            
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            Spacer(minLength: 12)
            
            BusinessDocumentPill(
                text: status,
                tint: BusinessDocumentVisual.statusTint(for: rawStatus)
            )
        }
    }
}

private struct BusinessDocumentCopyBlock: View {
    let title: String
    let value: String
    let systemImage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentPill: View {
    let text: String
    var systemImage: String? = nil
    let tint: Color
    
    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct BusinessDocumentDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.16))
            .frame(height: 1)
    }
}

private struct FlowTextList: View {
    let values: [String]
    
    var body: some View {
        Text(values.joined(separator: " · "))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct ArtifactAvailabilityRow: View {
    let title: String
    let artifact: BusinessDocumentArtifact?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: artifact == nil ? "doc.badge.clock" : "doc.badge.checkmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(artifact == nil ? .secondary : Color.green)
                .frame(width: 32, height: 32)
                .background((artifact == nil ? Color.secondary : Color.green).opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Text(artifact?.safeFileName ?? "No disponible")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            BusinessDocumentPill(
                text: artifact == nil ? "Pendiente" : "Disponible",
                tint: artifact == nil ? .secondary : .green
            )
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentPreparedFileSummary: View {
    let summary: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Último archivo preparado")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private enum BusinessDocumentActionButtonStyle {
    case primary
    case secondary
    case warning
    
    var tint: Color {
        switch self {
        case .primary:
            return .accentColor
        case .secondary:
            return .secondary
        case .warning:
            return .orange
        }
    }
    
    var isProminent: Bool {
        switch self {
        case .primary, .warning:
            return true
        case .secondary:
            return false
        }
    }
}

private struct BusinessDocumentActionButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let isDisabled: Bool
    let style: BusinessDocumentActionButtonStyle
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                } else {
                    Image(systemName: systemImage)
                }
                
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(style.isProminent ? Color.white : style.tint)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(buttonBackgroundColor)
            }
            .overlay {
                if !style.isProminent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(style.tint.opacity(0.18), lineWidth: 1)
                }
            }
            .opacity(isDisabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
    
    private var buttonBackgroundColor: Color {
        style.isProminent ? style.tint : style.tint.opacity(0.10)
    }
}

private struct BusinessDocumentInlineNotice: View {
    let message: String
    let systemImage: String
    let tint: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)
            
            Text(message)
                .font(.footnote)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentIssueRow: View {
    let title: String
    let detail: String?
    let systemImage: String
    let tint: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct TimelineEventRow: View {
    let event: BusinessElectronicDocumentTimelineEvent
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 4)
                }
            }
            .frame(width: 16)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                
                if let message = event.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                HStack(spacing: 8) {
                    if let createdAt = event.createdAt {
                        Label(createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    }
                    
                    if let actor = event.actor, !actor.isEmpty {
                        Label(actor, systemImage: "person.crop.circle")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            .padding(.bottom, isLast ? 0 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct BusinessDocumentBanner: View {
    let message: String
    let systemImage: String
    let tint: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            
            Text(message)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.15), lineWidth: 1)
        )
    }
}

private struct BusinessDocumentLoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Cargando comprobante…")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct BusinessDocumentEmptyCard: View {
    let title: String
    let message: String
    let systemImage: String
    var compact: Bool = false
    
    var body: some View {
        VStack(spacing: compact ? 8 : 12) {
            Image(systemName: systemImage)
                .font(compact ? .title3 : .title2)
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 14 : 22)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
