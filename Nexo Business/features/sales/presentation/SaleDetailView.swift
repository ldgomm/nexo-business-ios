//
//  SaleDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 1/6/26.
//

import SwiftUI

struct SaleDetailView: View {
    @Bindable private var viewModel: SaleDetailViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: SaleDetailViewModel,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.customersRepository = customersRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
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
                documentAndPaymentSection(sale)
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

    private func documentAndPaymentSection(_ sale: BusinessSale) -> some View {
        Section("Pago y documento") {
            LabeledContent("Pago", value: PaymentStatusPresentation.displayName(sale.paymentStatus))

            if let documentStatus = sale.documentStatus {
                LabeledContent("Documento", value: documentStatus)
            } else {
                LabeledContent("Documento", value: "Sin estado")
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
                            receivablesRepository: receivablesRepository
                        ),
                        customersRepository: customersRepository
                    )
                } label: {
                    Label("Cobrar venta", systemImage: "dollarsign.circle")
                }
            }

            if let sale = viewModel.sale, viewModel.canManageDocuments {
                NavigationLink {
                    BusinessDocumentsView(
                        viewModel: BusinessDocumentsViewModel(
                            organizationId: viewModel.organizationId,
                            sale: sale,
                            effectivePermissions: viewModel.effectivePermissions,
                            documentsRepository: documentsRepository
                        )
                    )
                } label: {
                    Label("Comprobantes", systemImage: "doc.text")
                }
            }

            Button {
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
