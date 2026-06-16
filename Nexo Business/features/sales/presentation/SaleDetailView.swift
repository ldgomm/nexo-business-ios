//
//  SaleDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import SwiftUI

struct SaleDetailView: View {
    @Bindable private var viewModel: SaleDetailViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository
    private let onSaleUpdated: (BusinessSale) -> Void

    init(
        viewModel: SaleDetailViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        Form {
            if viewModel.isLoading, viewModel.sale == nil {
                Section {
                    ProgressView("Cargando venta…")
                }
            }

            if let sale = viewModel.sale {
                summarySection(sale)
                itemsSection(sale)
                totalsSection(sale)
                paymentSection(sale)
                electronicDocumentSection(sale)
                messagesSection
                actionsSection
            } else if !viewModel.isLoading {
                ContentUnavailableView(
                    "Venta no disponible",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Actualiza para volver a consultar el estado de la venta.")
                )
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle("Detalle de venta")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
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
            if let sale {
                onSaleUpdated(sale)
            }
        }
    }

    private func summarySection(_ sale: BusinessSale) -> some View {
        Section("Venta") {
            LabeledContent("Venta", value: sale.displayNumber)
            SaleStatusLabel(status: sale.status)

            LabeledContent("Cliente", value: sale.displayCustomerName)

            if let createdAt = sale.createdAt {
                LabeledContent(
                    "Creada",
                    value: createdAt.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if let confirmedAt = sale.confirmedAt {
                LabeledContent(
                    "Confirmada",
                    value: confirmedAt.formatted(date: .abbreviated, time: .shortened)
                )
            }
        }
    }

    @ViewBuilder
    private func itemsSection(_ sale: BusinessSale) -> some View {
        if !sale.items.isEmpty {
            Section("Ítems") {
                ForEach(sale.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))

                        Text("Cantidad: \(item.quantity.cleanQuantityText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LabeledContent(
                            "Total línea",
                            value: money(lineTotal(for: item))
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func lineTotal(for item: BusinessSaleItem) -> MoneyAmount {
        item.total ?? item.subtotal ?? MoneyAmount(amount: "0.00")
    }

    private func totalsSection(_ sale: BusinessSale) -> some View {
        Section("Totales") {
            LabeledContent("Subtotal", value: money(sale.totals.subtotalWithoutTaxes))
            LabeledContent("Descuento", value: money(sale.totals.discountTotal))
            LabeledContent("Impuestos", value: money(sale.totals.taxTotal))
            LabeledContent("Total", value: money(sale.totals.grandTotal))
                .font(.headline)
        }
    }

    private func paymentSection(_ sale: BusinessSale) -> some View {
        Section("Cobro") {
            Label(
                PaymentStatusPresentation.displayName(sale.paymentStatus),
                systemImage: PaymentStatusPresentation.systemImage(sale.paymentStatus)
            )
            .font(.subheadline.weight(.semibold))

            if sale.needsCollection {
                Text("Registrada no significa cobrada. Esta venta todavía debe cobrarse o dejarse claramente como cuenta por cobrar.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("El estado de cobro indica que esta venta ya no está pendiente de cobro operativo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func electronicDocumentSection(_ sale: BusinessSale) -> some View {
        let status = sale.effectiveDocumentStatus ?? "not_required"
        let document = sale.primaryElectronicDocument

        return Section("Comprobante electrónico") {
            Label(
                BusinessDocumentStatusPresentation.displayName(status),
                systemImage: BusinessDocumentStatusPresentation.systemImage(status)
            )
            .font(.subheadline.weight(.semibold))

            if let document {
                LabeledContent("Número", value: document.businessDisplayNumber)

                if let authorizationNumber = document.shortAuthorizationDisplay {
                    LabeledContent("Autorización SRI", value: authorizationNumber)
                }

                if let error = BusinessDocumentTextSanitizer.sanitizedMessage(document.lastErrorMessage) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                } else if BusinessDocumentStatusPresentation.isAuthorized(document.effectiveStatus) {
                    Text(document.hasRide ? "Factura autorizada. RIDE y XML se revisan desde Comprobantes." : "Factura autorizada, pero todavía falta RIDE.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Revisa el comprobante para ver autorización, RIDE, XML, correo y errores si existieran.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else if BusinessDocumentStatusPresentation.isMissingElectronicDocument(status) {
                Text("Sin factura electrónica emitida. Esta venta puede estar cobrada y seguir como registro interno hasta que alguien con permiso emita el comprobante.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let reason = viewModel.electronicInvoiceBlockedReason {
                    Label(reason, systemImage: "lock")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let detail = sale.electronicInvoiceReadiness.detailedMessage {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if viewModel.canIssueElectronicInvoice(for: sale) {
                    Label("Puedes emitir factura electrónica desde Comprobantes.", systemImage: "doc.badge.plus")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("La venta indica un comprobante electrónico en estado \(BusinessDocumentStatusPresentation.displayName(status)). Abre Comprobantes para cargar el detalle real.")
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
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section("Acciones") {
            if let sale = viewModel.sale, viewModel.canCollect {
                NavigationLink {
                    PaymentRegisterView(
                        viewModel: PaymentRegisterViewModel(
                            organizationId: viewModel.organizationId,
                            branchId: sale.branchId,
                            sale: sale,
                            effectivePermissions: viewModel.effectivePermissions,
                            cashRepository: cashRepository,
                            paymentsRepository: paymentsRepository,
                            receivablesRepository: receivablesRepository,
                            documentsRepository: documentsRepository,
                            salesRepository: viewModel.salesRepositoryForPaymentReadiness,
                            activityId: sale.activityId,
                            revisions: viewModel.revisions
                        ),
                        customersRepository: customersRepository,
                        onSaleUpdated: { updatedSale in
                            viewModel.applySaleUpdate(updatedSale)
                        }
                    )
                } label: {
                    Label("Cobrar venta", systemImage: "dollarsign.circle")
                }
            }

            if let sale = viewModel.sale, viewModel.canViewDocuments {
                NavigationLink {
                    BusinessDocumentsView(
                        viewModel: BusinessDocumentsViewModel(
                            organizationId: viewModel.organizationId,
                            sale: sale,
                            effectivePermissions: viewModel.effectivePermissions,
                            branchId: sale.branchId,
                            activityId: sale.activityId,
                            revisions: viewModel.revisions,
                            documentsRepository: documentsRepository
                        ),
                        onSaleUpdated: { updatedSale in
                            viewModel.applySaleUpdate(updatedSale)
                        }
                    )
                } label: {
                    Label(
                        viewModel.documentActionTitle(for: sale),
                        systemImage: viewModel.documentActionSystemImage(for: sale)
                    )
                }
            }

            Button {
                NexoKeyboard.dismiss()
                Task { await viewModel.confirm() }
            } label: {
                if viewModel.isConfirming {
                    ProgressView()
                } else {
                    Label("Confirmar venta", systemImage: "checkmark.seal")
                }
            }
            .disabled(!viewModel.canConfirm)

            TextField("Motivo de cancelación opcional", text: $viewModel.cancelReason)
                .textInputAutocapitalization(.sentences)

            Button(role: .destructive) {
                NexoKeyboard.dismiss()
                Task { await viewModel.cancel() }
            } label: {
                if viewModel.isCanceling {
                    ProgressView()
                } else {
                    Label("Cancelar venta", systemImage: "xmark.circle")
                }
            }
            .disabled(!viewModel.canCancel)
        }
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

#Preview {
    NavigationStack {
        SaleDetailView(
            viewModel: SaleDetailViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                saleId: PreviewData.confirmedSaleResponse.sale.id,
                revisions: PreviewData.businessContext.revisions,
                initialSale: PreviewData.confirmedSaleResponse.sale,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                salesRepository: PreviewSalesRepository()
            ),
            customersRepository: PreviewCustomersRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository()
        )
    }
}
