//
//  BusinessDocumentsView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct BusinessDocumentsView: View {
    @Bindable private var viewModel: BusinessDocumentsViewModel

    init(viewModel: BusinessDocumentsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            saleSection
            documentsSection
            actionsSection
            electronicInvoiceWarningSection
            messagesSection
        }
        .navigationTitle("Comprobantes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
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

    private var saleSection: some View {
        Section("Venta") {
            LabeledContent("ID", value: viewModel.sale.id)
            LabeledContent("Estado", value: SaleStatusPresentation.title(for: viewModel.sale.status))
            LabeledContent("Total", value: money(viewModel.sale.totals.grandTotal))
            LabeledContent("Documento", value: BusinessDocumentStatusPresentation.displayName(viewModel.sale.documentStatus ?? "not_required"))
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        Section("Documentos") {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView("Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Sin comprobantes",
                    systemImage: "doc.text",
                    description: Text("Genera un ticket interno o registra una nota de venta física según corresponda.")
                )
            } else {
                ForEach(viewModel.documents) { document in
                    BusinessDocumentRow(document: document)
                }
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if viewModel.hasAnyDocumentAction {
            Section("Acciones permitidas") {
                TextField("Nota opcional", text: $viewModel.note)
                    .textInputAutocapitalization(.sentences)

                Button {
                    Task { await viewModel.generateInternalTicket() }
                } label: {
                    if viewModel.isGeneratingInternalTicket {
                        ProgressView()
                    } else {
                        Label("Generar ticket interno", systemImage: "printer")
                    }
                }
                .disabled(!viewModel.canGenerateInternalTicket)

                TextField("Número de nota física", text: $viewModel.physicalSaleNoteNumber)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()

                Button {
                    Task { await viewModel.registerPhysicalSaleNote() }
                } label: {
                    if viewModel.isRegisteringPhysicalSaleNote {
                        ProgressView()
                    } else {
                        Label("Registrar nota de venta física", systemImage: "doc.badge.plus")
                    }
                }
                .disabled(!viewModel.canRegisterPhysicalSaleNote)
            }
        }
    }

    @ViewBuilder
    private var electronicInvoiceWarningSection: some View {
        if viewModel.hasElectronicInvoiceWarning {
            Section("Factura electrónica") {
                Label(
                    "La factura electrónica fuerte no se emite desde la app todavía. Debe pasar por backend, readiness SRI, firma activa, secuencia y autorización.",
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                Label(message, systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        "\(value.currency) \(value.amount)"
    }
}

private struct BusinessDocumentRow: View {
    let document: BusinessDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: BusinessDocumentTypePresentation.systemImage(document.type))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(BusinessDocumentTypePresentation.displayName(document.type))
                        .font(.subheadline.weight(.semibold))

                    Label(
                        BusinessDocumentStatusPresentation.displayName(document.status),
                        systemImage: BusinessDocumentStatusPresentation.systemImage(document.status)
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if let number = document.number, !number.isEmpty {
                LabeledContent("Número", value: number)
                    .font(.caption)
            }

            if let accessKey = document.accessKey, !accessKey.isEmpty {
                LabeledContent("Clave", value: accessKey)
                    .font(.caption.monospaced())
            }

            if let authorizationNumber = document.authorizationNumber, !authorizationNumber.isEmpty {
                LabeledContent("Autorización", value: authorizationNumber)
                    .font(.caption.monospaced())
            }

            if let customerEmail = document.customerEmail, !customerEmail.isEmpty {
                LabeledContent("Correo", value: customerEmail)
                    .font(.caption)
            }

            if let createdAt = document.createdAt {
                Text("Creado: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let pdfUrl = document.pdfUrl, !pdfUrl.isEmpty {
                Text(pdfUrl)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        BusinessDocumentsView(
            viewModel: BusinessDocumentsViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                sale: PreviewData.confirmedSaleResponse.sale,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                documentsRepository: PreviewBusinessDocumentsRepository()
            )
        )
    }
}
