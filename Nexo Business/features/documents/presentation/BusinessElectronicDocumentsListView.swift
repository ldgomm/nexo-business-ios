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
        List {
            filtersSection
            documentsSection
            messagesSection
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Comprobantes electrónicos")
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

    private var filtersSection: some View {
        Section("Filtros") {
            TextField("Estado: autorizado, no autorizado, fallido…", text: $viewModel.statusFilter)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()

            TextField("Ambiente: test o production", text: $viewModel.environmentFilter)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("Buscar por venta", text: $viewModel.saleIdFilter)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            LabeledContent("Actual", value: viewModel.activeFiltersDescription)

            HStack {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.load() }
                } label: {
                    Label("Aplicar", systemImage: "line.3.horizontal.decrease.circle")
                }
                .disabled(viewModel.isLoading)

                Spacer()

                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.clearFiltersAndReload() }
                } label: {
                    Text("Limpiar")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        Section("Historial") {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView("Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Sin comprobantes",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Aquí aparecerán las facturas electrónicas emitidas por el negocio.")
                )
            } else {
                ForEach(viewModel.documents) { document in
                    NavigationLink {
                        BusinessElectronicDocumentDetailView(
                            viewModel: BusinessElectronicDocumentDetailViewModel(
                                organizationId: viewModel.organizationId,
                                documentId: document.documentId,
                                effectivePermissions: viewModel.effectivePermissions,
                                documentsRepository: documentsRepository
                            )
                        )
                    } label: {
                        BusinessElectronicDocumentRow(document: document)
                    }
                }
            }
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

struct BusinessElectronicDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: BusinessDocumentTypePresentation.systemImage(document.type))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(document.businessDisplayNumber)
                        .font(.subheadline.weight(.semibold))

                    Text(BusinessDocumentTypePresentation.displayName(document.type))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(
                        BusinessDocumentStatusPresentation.displayName(document.effectiveStatus),
                        systemImage: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus)
                    )
                    .font(.caption)
                    .foregroundStyle(BusinessDocumentStatusPresentation.isError(document.effectiveStatus) ? .red : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if let environment = document.environment, !environment.isEmpty {
                        Text(environment.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    if document.hasRide {
                        Image(systemName: "doc.richtext")
                            .foregroundStyle(.secondary)
                    }

                    if document.hasXml {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let customerName = document.customerName, !customerName.isEmpty {
                Text(customerName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let total = document.total, !total.isEmpty {
                LabeledContent("Total", value: "\(document.currency) \(total)")
                    .font(.caption)
            }

            if let issuedAt = document.issuedAt ?? document.createdAt {
                Text("Emitido: \(issuedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
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
