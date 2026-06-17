//
//  BusinessDocumentsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import SwiftUI

struct BusinessDocumentsView: View {
    @Bindable private var viewModel: BusinessDocumentsViewModel
    private let onSaleUpdated: (BusinessSale) -> Void

    init(
        viewModel: BusinessDocumentsViewModel,
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                messagesSection
                saleHero
                electronicInvoiceSection
                documentsSection
                actionsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
        .nexoKeyboardDismissable()
        .navigationTitle("Comprobantes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.load() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
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

    private var saleHero: some View {
        BusinessDocumentsHeroCard(
            saleNumber: viewModel.sale.displayNumber,
            saleStatus: SaleStatusPresentation.title(for: viewModel.sale.status),
            paymentStatus: PaymentStatusPresentation.displayName(viewModel.sale.paymentStatus),
            invoiceStatus: viewModel.electronicInvoiceStatusText,
            total: money(viewModel.sale.totals.grandTotal)
        )
    }

    private var electronicInvoiceSection: some View {
        BusinessDocumentsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    BusinessDocumentsIconBadge(
                        systemImage: BusinessDocumentStatusPresentation.systemImage(
                            viewModel.latestElectronicInvoice?.effectiveStatus
                            ?? viewModel.sale.effectiveDocumentStatus
                            ?? "not_required"
                        ),
                        tint: invoiceTint
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Factura electrónica")
                            .font(.headline)

                        Text(viewModel.electronicInvoiceStatusText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(invoiceTint)

                        Text(viewModel.electronicInvoiceDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                if let document = viewModel.latestElectronicInvoice {
                    NavigationLink {
                        BusinessElectronicDocumentDetailView(
                            viewModel: viewModel.makeElectronicDocumentDetailViewModel(for: document)
                        )
                    } label: {
                        BusinessDocumentsInlineNavigationLabel(
                            title: "Ver detalle del comprobante",
                            subtitle: "Autorización, RIDE, XML, correo y eventos",
                            systemImage: "doc.text.magnifyingglass"
                        )
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.shouldShowElectronicInvoiceButton {
                    BusinessDocumentsActionButton(
                        title: "Emitir factura electrónica",
                        subtitle: "Genera el comprobante y consulta autorización SRI",
                        systemImage: "doc.badge.plus",
                        tint: .accentColor,
                        isLoading: viewModel.isIssuingElectronicInvoice,
                        isDisabled: !viewModel.canIssueElectronicInvoice
                    ) {
                        NexoKeyboard.dismiss()
                        Task {
                            await viewModel.issueElectronicInvoice()
                            onSaleUpdated(viewModel.sale)
                        }
                    }
                }

                if let reason = viewModel.electronicInvoiceBlockedReason {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            reason,
                            systemImage: viewModel.hasElectronicInvoiceIssuePermission ? "info.circle" : "lock"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)

                        if let detail = viewModel.sale.electronicInvoiceReadiness.detailedMessage {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        BusinessDocumentsCard(title: "Historial de comprobantes", subtitle: historySubtitle) {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                BusinessDocumentsLoadingRow(title: "Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                BusinessDocumentsEmptyState(
                    title: "Sin comprobantes registrados",
                    message: "Cuando emitas factura electrónica, ticket interno o nota física, aparecerá aquí.",
                    systemImage: "doc.text"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.documents) { document in
                        if document.isElectronicInvoiceForBusinessUI {
                            NavigationLink {
                                BusinessElectronicDocumentDetailView(
                                    viewModel: viewModel.makeElectronicDocumentDetailViewModel(for: document)
                                )
                            } label: {
                                BusinessDocumentsHistoryRow(document: document)
                            }
                            .buttonStyle(.plain)
                        } else {
                            BusinessDocumentsHistoryRow(document: document)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if viewModel.hasAnyDocumentAction {
            BusinessDocumentsCard(
                title: "Registro interno",
                subtitle: "Respaldo operativo. No reemplaza la autorización SRI de una factura electrónica."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Nota opcional", text: $viewModel.note, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(1...3)
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    BusinessDocumentsActionButton(
                        title: "Generar ticket interno",
                        subtitle: "Crea un respaldo local para la venta",
                        systemImage: "printer",
                        tint: .accentColor,
                        isLoading: viewModel.isGeneratingInternalTicket,
                        isDisabled: !viewModel.canGenerateInternalTicket
                    ) {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.generateInternalTicket() }
                    }

                    Divider()

                    TextField("Número de nota física", text: $viewModel.physicalSaleNoteNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    BusinessDocumentsActionButton(
                        title: "Registrar nota de venta física",
                        subtitle: "Guarda el número del comprobante físico",
                        systemImage: "doc.badge.plus",
                        tint: .accentColor,
                        isLoading: viewModel.isRegisteringPhysicalSaleNote,
                        isDisabled: !viewModel.canRegisterPhysicalSaleNote
                    ) {
                        NexoKeyboard.dismiss()
                        Task { await viewModel.registerPhysicalSaleNote() }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        if let message = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.errorMessage) {
            BusinessDocumentsMessageBanner(
                message: message,
                systemImage: "exclamationmark.triangle.fill",
                tint: .red
            )
        }

        if let message = BusinessDocumentTextSanitizer.sanitizedMessage(viewModel.infoMessage) {
            BusinessDocumentsMessageBanner(
                message: message,
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        }
    }

    private var historySubtitle: String {
        if viewModel.documents.isEmpty {
            return "Aún no hay documentos asociados a esta venta."
        }

        return "\(viewModel.documents.count) registro\(viewModel.documents.count == 1 ? "" : "s") asociado\(viewModel.documents.count == 1 ? "" : "s") a la venta."
    }

    private var invoiceTint: Color {
        guard let status = viewModel.latestElectronicInvoice?.effectiveStatus ?? viewModel.sale.effectiveDocumentStatus else {
            return .secondary
        }

        if BusinessDocumentStatusPresentation.isError(status) {
            return .red
        }

        if BusinessDocumentStatusPresentation.isAuthorized(status) {
            return .green
        }

        if BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) {
            return .secondary
        }

        return .accentColor
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

private struct BusinessDocumentsHeroCard: View {
    let saleNumber: String
    let saleStatus: String
    let paymentStatus: String
    let invoiceStatus: String
    let total: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                BusinessDocumentsIconBadge(systemImage: "doc.text.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Comprobantes de venta")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(saleNumber)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("Total \(total)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BusinessDocumentsPill(title: saleStatus, systemImage: "checkmark.seal", tint: .accentColor)
                BusinessDocumentsPill(title: paymentStatus, systemImage: "creditcard", tint: .green)
            }

            BusinessDocumentsStatusStrip(
                title: "Factura electrónica",
                value: invoiceStatus,
                systemImage: "bolt.horizontal.circle"
            )
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.16),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct BusinessDocumentsCard<Content: View>: View {
    private let title: String?
    private let subtitle: String?
    private let content: Content

    init(
        title: String? = nil,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 4) {
                    if let title {
                        Text(title)
                            .font(.headline)
                    }

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct BusinessDocumentsHistoryRow: View {
    let document: BusinessDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                BusinessDocumentsIconBadge(
                    systemImage: BusinessDocumentTypePresentation.systemImage(document.type),
                    tint: statusTint
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(BusinessDocumentTypePresentation.displayName(document.type))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Spacer(minLength: 8)

                        if document.isElectronicInvoiceForBusinessUI {
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    BusinessDocumentsPill(
                        title: BusinessDocumentStatusPresentation.displayName(document.effectiveStatus),
                        systemImage: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus),
                        tint: statusTint
                    )
                }
            }

            VStack(spacing: 7) {
                if let number = document.number, !number.isEmpty {
                    BusinessDocumentsMetaRow(title: "Número", value: number)
                }

                if let authorizationNumber = document.shortAuthorizationDisplay {
                    BusinessDocumentsMetaRow(title: "Autorización SRI", value: authorizationNumber, isMonospaced: true)
                }

                if let customerEmail = document.customerEmail, !customerEmail.isEmpty {
                    BusinessDocumentsMetaRow(title: "Correo", value: customerEmail)
                }

                if let total = document.total?.trimmingCharacters(in: .whitespacesAndNewlines), !total.isEmpty {
                    BusinessDocumentsMetaRow(title: "Total", value: "\(document.currency) \(total)")
                }

                if let createdAt = document.createdAt {
                    BusinessDocumentsMetaRow(
                        title: "Creado",
                        value: createdAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }

            if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusTint: Color {
        if BusinessDocumentStatusPresentation.isError(document.effectiveStatus) {
            return .red
        }

        if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
            return .green
        }

        if BusinessDocumentStatusPresentation.isMissingElectronicDocument(document.effectiveStatus) {
            return .secondary
        }

        return .accentColor
    }
}

private struct BusinessDocumentsMetaRow: View {
    let title: String
    let value: String
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

private struct BusinessDocumentsActionButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .foregroundStyle(isDisabled ? Color.secondary : tint)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isDisabled ? Color(.tertiarySystemGroupedBackground) : tint.opacity(0.10))
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
    }
}

private struct BusinessDocumentsInlineNavigationLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            BusinessDocumentsIconBadge(systemImage: systemImage, tint: .accentColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct BusinessDocumentsStatusStrip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessDocumentsPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct BusinessDocumentsIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

private struct BusinessDocumentsLoadingRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 10)
    }
}

private struct BusinessDocumentsEmptyState: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct BusinessDocumentsMessageBanner: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        BusinessDocumentsView(
            viewModel: BusinessDocumentsViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                sale: PreviewData.confirmedSaleResponse.sale,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                branchId: PreviewData.businessContext.branches.first?.id,
                activityId: PreviewData.businessContext.activities.first?.id,
                revisions: PreviewData.businessContext.revisions,
                documentsRepository: PreviewBusinessDocumentsRepository()
            )
        )
    }
}
