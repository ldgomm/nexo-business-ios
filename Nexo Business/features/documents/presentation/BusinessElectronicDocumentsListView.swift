//
//  BusinessElectronicDocumentsListView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct BusinessElectronicDocumentsListView: View {
    @Bindable private var viewModel: BusinessElectronicDocumentsViewModel
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: BusinessElectronicDocumentsViewModel,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                filtersSection

                if (viewModel.errorMessage?.isEmpty == false) || (viewModel.infoMessage?.isEmpty == false) {
                    messagesSection
                }

                documentsSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .nexoKeyboardDismissable()
        .navigationTitle("Comprobantes")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar comprobantes")
            }
        }
        .refreshable {
            await viewModel.load()
        }
        .task {
            if viewModel.shouldLoadOnAppear {
                await viewModel.load()
            }
        }
    }

    private var filtersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                BusinessElectronicDocumentIconBadge(systemImage: "doc.text.magnifyingglass", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Archivo fiscal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text("Comprobantes electrónicos")
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("Consulta facturas, autorización SRI, RIDE, XML y estado de entrega al cliente.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(columns: metricColumns, spacing: 10) {
                BusinessElectronicDocumentMetric(
                    title: "Total",
                    value: String(viewModel.documents.count),
                    systemImage: "tray.full"
                )

                BusinessElectronicDocumentMetric(
                    title: "Autorizados",
                    value: String(authorizedDocumentsCount),
                    systemImage: "checkmark.seal"
                )
            }

            VStack(spacing: 10) {
                BusinessElectronicDocumentFilterField(
                    title: "Estado",
                    placeholder: "autorizado, pendiente, fallido…",
                    systemImage: "checkmark.seal",
                    text: $viewModel.statusFilter,
                    textInputAutocapitalization: .characters,
                    autocorrectionDisabled: true
                )

                BusinessElectronicDocumentFilterField(
                    title: "Ambiente",
                    placeholder: "test o production",
                    systemImage: "server.rack",
                    text: $viewModel.environmentFilter,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )

                BusinessElectronicDocumentFilterField(
                    title: "Venta",
                    placeholder: "Buscar por venta",
                    systemImage: "cart",
                    text: $viewModel.saleIdFilter,
                    textInputAutocapitalization: .never,
                    autocorrectionDisabled: true
                )
            }

            HStack(spacing: 10) {
                BusinessElectronicDocumentActionButton(
                    title: "Aplicar",
                    systemImage: "line.3.horizontal.decrease.circle",
                    isLoading: viewModel.isLoading,
                    style: .primary
                ) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                }
                .disabled(viewModel.isLoading)

                BusinessElectronicDocumentActionButton(
                    title: "Limpiar",
                    systemImage: "xmark.circle",
                    isLoading: false,
                    style: .secondary
                ) {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.clearFiltersAndReload() }
                }
                .disabled(viewModel.isLoading)
            }

            BusinessElectronicDocumentInlineInfo(
                title: "Filtros activos",
                value: viewModel.activeFiltersDescription,
                systemImage: "slider.horizontal.3"
            )
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.green.opacity(0.16),
                    Color(uiColor: .secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var documentsSection: some View {
        BusinessElectronicDocumentsCard(
            title: "Historial electrónico",
            subtitle: documentsSubtitle,
            systemImage: "doc.text"
        ) {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                BusinessElectronicDocumentLoadingRow(title: "Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                BusinessElectronicDocumentEmptyState(
                    title: "Sin comprobantes electrónicos",
                    message: "Cuando el negocio emita facturas electrónicas, aparecerán aquí con su estado SRI, RIDE, XML y entrega al cliente.",
                    systemImage: "doc.text.magnifyingglass"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.documents) { document in
                        NavigationLink {
                            BusinessElectronicDocumentDetailView(
                                viewModel: BusinessElectronicDocumentDetailViewModel(
                                    organizationId: viewModel.organizationId,
                                    documentId: document.documentId,
                                    effectivePermissions: viewModel.effectivePermissions,
                                    documentsRepository: documentsRepository,
                                    onDocumentMutated: { await viewModel.load() }
                                )
                            )
                        } label: {
                            BusinessElectronicDocumentRow(document: document)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var messagesSection: some View {
        VStack(spacing: 10) {
            if let message = viewModel.errorMessage {
                BusinessElectronicDocumentBanner(
                    message: message,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red
                )
            }

            if let message = viewModel.infoMessage {
                BusinessElectronicDocumentBanner(
                    message: message,
                    systemImage: "info.circle.fill",
                    tint: .secondary
                )
            }
        }
    }

    private var documentsSubtitle: String {
        if viewModel.documents.isEmpty {
            return "Sin resultados con los filtros actuales."
        }

        return "\(viewModel.documents.count) comprobante\(viewModel.documents.count == 1 ? "" : "s") encontrado\(viewModel.documents.count == 1 ? "" : "s")."
    }

    private var authorizedDocumentsCount: Int {
        viewModel.documents.filter { BusinessDocumentStatusPresentation.isAuthorized($0.effectiveStatus) }.count
    }

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
}

struct BusinessElectronicDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BusinessElectronicDocumentIconBadge(
                systemImage: BusinessDocumentTypePresentation.systemImage(document.type),
                tint: statusTint
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.businessDisplayNumber)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(BusinessDocumentTypePresentation.displayName(document.type))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if let environment = document.environment, !environment.isEmpty {
                        BusinessElectronicDocumentPill(
                            title: environment.uppercased(),
                            systemImage: "server.rack",
                            tint: .secondary
                        )
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        statusPill
                        emailStatusPill
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        statusPill
                        emailStatusPill
                    }
                }

                VStack(spacing: 7) {
                    if let customerName = document.customerName, !customerName.isEmpty {
                        BusinessElectronicDocumentMetaRow(title: "Cliente", value: customerName)
                    }

                    if let total = document.total, !total.isEmpty {
                        BusinessElectronicDocumentMetaRow(title: "Total", value: "\(document.currency) \(total)")
                    }

                    if let issuedAt = document.issuedAt ?? document.createdAt {
                        BusinessElectronicDocumentMetaRow(
                            title: "Emitido",
                            value: issuedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }

                if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statusPill: some View {
        BusinessElectronicDocumentPill(
            title: BusinessDocumentStatusPresentation.displayName(document.effectiveStatus),
            systemImage: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus),
            tint: statusTint
        )
    }

    @ViewBuilder
    private var emailStatusPill: some View {
        if document.emailStatus != nil || document.effectiveCustomerEmail != nil || document.deliveredAt != nil {
            BusinessElectronicDocumentPill(
                title: BusinessDocumentEmailStatusPresentation.displayName(
                    document.emailStatus,
                    recipient: document.effectiveCustomerEmail,
                    sentAt: document.deliveredAt
                ),
                systemImage: BusinessDocumentEmailStatusPresentation.systemImage(
                    document.emailStatus,
                    sentAt: document.deliveredAt
                ),
                tint: BusinessDocumentEmailStatusPresentation.isError(document.emailStatus) ? .red : .secondary
            )
        }
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

private enum BusinessElectronicDocumentActionStyle {
    case primary
    case secondary

    var tint: Color {
        switch self {
        case .primary:
            return .accentColor
        case .secondary:
            return .secondary
        }
    }

    var isProminent: Bool {
        switch self {
        case .primary:
            return true
        case .secondary:
            return false
        }
    }
}

private struct BusinessElectronicDocumentsCard<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    private let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                BusinessElectronicDocumentIconBadge(systemImage: systemImage, tint: .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline.weight(.semibold))

                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.025), radius: 7, x: 0, y: 3)
    }
}

private struct BusinessElectronicDocumentFilterField: View {
    let title: String
    let placeholder: String
    let systemImage: String
    @Binding var text: String
    let textInputAutocapitalization: TextInputAutocapitalization
    let autocorrectionDisabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(textInputAutocapitalization)
                    .autocorrectionDisabled(autocorrectionDisabled)
                    .submitLabel(.search)
            }

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpiar \(title)")
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessElectronicDocumentMetric: View {
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
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessElectronicDocumentActionButton: View {
    let title: String
    let systemImage: String
    let isLoading: Bool
    let style: BusinessElectronicDocumentActionStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(style.isProminent ? Color.white : style.tint)
            .background(style.isProminent ? style.tint : style.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if !style.isProminent {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(style.tint.opacity(0.16), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct BusinessElectronicDocumentInlineInfo: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessElectronicDocumentMetaRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }
}

private struct BusinessElectronicDocumentPill: View {
    let title: String
    var systemImage: String? = nil
    let tint: Color

    var body: some View {
        if let systemImage {
            Label(title, systemImage: systemImage)
                .businessElectronicDocumentPillStyle(tint: tint)
        } else {
            Text(title)
                .businessElectronicDocumentPillStyle(tint: tint)
        }
    }
}

private struct BusinessElectronicDocumentIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            )
    }
}

private struct BusinessElectronicDocumentLoadingRow: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}

private struct BusinessElectronicDocumentEmptyState: View {
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

private struct BusinessElectronicDocumentBanner: View {
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
                .foregroundStyle(tint == .secondary ? .primary : tint)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

private extension View {
    func businessElectronicDocumentPillStyle(tint: Color) -> some View {
        self
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.12), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        BusinessElectronicDocumentsListView(
            viewModel: BusinessElectronicDocumentsViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                documentsRepository: PreviewBusinessDocumentsRepository()
            ),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
