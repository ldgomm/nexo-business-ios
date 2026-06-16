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
        Form {
            saleSection
            electronicInvoiceSection
            documentsSection
            actionsSection
            messagesSection
        }
        .nexoKeyboardDismissable()
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
        .onChange(of: viewModel.sale) { _, sale in
            onSaleUpdated(sale)
        }
    }

    private var saleSection: some View {
        Section("Venta") {
            LabeledContent("Venta", value: viewModel.sale.displayNumber)
            LabeledContent("Estado", value: SaleStatusPresentation.title(for: viewModel.sale.status))
            LabeledContent("Estado de cobro", value: PaymentStatusPresentation.displayName(viewModel.sale.paymentStatus))
            LabeledContent("Total", value: money(viewModel.sale.totals.grandTotal))
        }
    }

    private var electronicInvoiceSection: some View {
        Section("Factura electrónica") {
            Label(
                viewModel.electronicInvoiceStatusText,
                systemImage: BusinessDocumentStatusPresentation.systemImage(viewModel.latestElectronicInvoice?.effectiveStatus ?? viewModel.sale.effectiveDocumentStatus ?? "not_required")
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(viewModel.latestElectronicInvoice.map { BusinessDocumentStatusPresentation.isError($0.effectiveStatus) } == true ? Color.red : Color.primary)

            Text(viewModel.electronicInvoiceDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let document = viewModel.latestElectronicInvoice {
                NavigationLink {
                    BusinessElectronicDocumentDetailView(
                        viewModel: viewModel.makeElectronicDocumentDetailViewModel(for: document)
                    )
                } label: {
                    Label("Ver detalle del comprobante", systemImage: "doc.text.magnifyingglass")
                }
            }

            if viewModel.shouldShowElectronicInvoiceButton {
                Button {
                    NexoKeyboard.dismiss()
                    Task { await viewModel.issueElectronicInvoice() }
                } label: {
                    if viewModel.isIssuingElectronicInvoice {
                        ProgressView()
                    } else {
                        Label("Emitir factura electrónica", systemImage: "doc.badge.plus")
                    }
                }
                .disabled(!viewModel.canIssueElectronicInvoice)
            }

            if let reason = viewModel.electronicInvoiceBlockedReason {
                Label(reason, systemImage: viewModel.hasElectronicInvoiceIssuePermission ? "info.circle" : "lock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let detail = viewModel.sale.electronicInvoiceReadiness.detailedMessage {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var documentsSection: some View {
        Section("Historial de comprobantes") {
            if viewModel.isLoading && viewModel.documents.isEmpty {
                ProgressView("Cargando comprobantes…")
            } else if viewModel.documents.isEmpty {
                ContentUnavailableView(
                    "Sin comprobantes registrados",
                    systemImage: "doc.text",
                    description: Text("Cuando emitas factura electrónica, ticket interno o nota física, aparecerá aquí.")
                )
            } else {
                ForEach(viewModel.documents) { document in
                    if document.isElectronicInvoiceForBusinessUI {
                        NavigationLink {
                            BusinessElectronicDocumentDetailView(
                                viewModel: viewModel.makeElectronicDocumentDetailViewModel(for: document)
                            )
                        } label: {
                            BusinessDocumentRow(document: document)
                        }
                    } else {
                        BusinessDocumentRow(document: document)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var actionsSection: some View {
        if viewModel.hasAnyDocumentAction {
            Section("Registro interno") {
                Text("Usa estas acciones solo si necesitas respaldo interno o registrar una nota física. No reemplazan la autorización SRI de una factura electrónica.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                TextField("Nota opcional", text: $viewModel.note)
                    .textInputAutocapitalization(.sentences)

                Button {
                    NexoKeyboard.dismiss()
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
                    NexoKeyboard.dismiss()
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
        value.displayText
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
                        BusinessDocumentStatusPresentation.displayName(document.effectiveStatus),
                        systemImage: BusinessDocumentStatusPresentation.systemImage(document.effectiveStatus)
                    )
                    .font(.caption)
                    .foregroundStyle(BusinessDocumentStatusPresentation.isError(document.effectiveStatus) ? .red : .secondary)
                }

                Spacer()
            }

            if let number = document.number, !number.isEmpty {
                LabeledContent("Número", value: number)
                    .font(.caption)
            }

            if let authorizationNumber = document.shortAuthorizationDisplay {
                LabeledContent("Autorización SRI", value: authorizationNumber)
                    .font(.caption.monospaced())
            }

            if let customerEmail = document.customerEmail, !customerEmail.isEmpty {
                LabeledContent("Correo", value: customerEmail)
                    .font(.caption)
            }

            if let total = document.total?.trimmingCharacters(in: .whitespacesAndNewlines), !total.isEmpty {
                LabeledContent("Total", value: "\(document.currency) \(total)")
                    .font(.caption)
            }

            if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if let createdAt = document.createdAt {
                Text("Creado: \(createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                branchId: PreviewData.businessContext.branches.first?.id,
                activityId: PreviewData.businessContext.activities.first?.id,
                revisions: PreviewData.businessContext.revisions,
                documentsRepository: PreviewBusinessDocumentsRepository()
            )
        )
    }
}
