//
//  SaleDetailView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
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
        List {
            if viewModel.isLoading, viewModel.sale == nil {
                Section {
                    ProgressView("Cargando venta…")
                }
            }

            if let sale = viewModel.sale {
                heroSection(sale)
                statusSection(sale)
                itemsSection(sale)
                totalsSection(sale)
                timelineSection(sale)
                actionsSection(sale)
                messagesSection
            } else if !viewModel.isLoading {
                ContentUnavailableView(
                    "Venta no disponible",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Actualiza para volver a consultar el estado de la venta.")
                )
            }
        }
        .listStyle(.insetGrouped)
        .nexoKeyboardDismissable()
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
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

    private func heroSection(_ sale: BusinessSale) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Venta")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(sale.displayNumber)
                            .font(.headline.weight(.bold))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 5) {
                        Text("Total")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(sale.totals.grandTotal.displayText)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(sale.displayCustomerName, systemImage: "person.crop.circle")

                    if !sale.displayItemsSummary.isEmpty {
                        Label(sale.displayItemsSummary, systemImage: "cart")
                            .lineLimit(2)
                    }

                    if let createdAt = sale.createdAt {
                        Label(createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func statusSection(_ sale: BusinessSale) -> some View {
        Section("Estado operativo") {
            NexoSaleDetailStatusRow(
                title: "Venta",
                value: SaleStatusPresentation.title(for: sale.status),
                systemImage: SaleStatusPresentation.systemImage(for: sale.status)
            )

            NexoSaleDetailStatusRow(
                title: "Pago",
                value: PaymentStatusPresentation.displayName(sale.paymentStatus),
                systemImage: "dollarsign.circle"
            )

            NexoSaleDetailStatusRow(
                title: "Documento",
                value: BusinessDocumentStatusPresentation.displayName(sale.documentStatus ?? "not_required"),
                systemImage: "doc.text"
            )
        }
    }

    @ViewBuilder
    private func itemsSection(_ sale: BusinessSale) -> some View {
        if !sale.items.isEmpty {
            Section("Productos y servicios") {
                ForEach(sale.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.name)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)

                                Text("Cantidad: x\(item.quantity.cleanQuantityText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 12)

                            Text(lineTotal(for: item).displayText)
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                        }

                        if let unitPrice = item.unitPrice {
                            LabeledContent("Precio unitario", value: unitPrice.displayText)
                                .font(.caption)
                        }

                        if let subtotal = item.subtotal {
                            LabeledContent("Base línea", value: subtotal.displayText)
                                .font(.caption)
                        }

                        if let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func totalsSection(_ sale: BusinessSale) -> some View {
        Section("Totales") {
            LabeledContent("Subtotal", value: money(sale.totals.subtotalWithoutTaxes))
            LabeledContent("Descuento", value: money(sale.totals.discountTotal))
            LabeledContent("Impuestos", value: money(sale.totals.taxTotal))

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text(money(sale.totals.grandTotal))
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func timelineSection(_ sale: BusinessSale) -> some View {
        if sale.createdAt != nil || sale.confirmedAt != nil || sale.closedAt != nil || sale.updatedAt != nil {
            Section("Trazabilidad") {
                if let createdAt = sale.createdAt {
                    LabeledContent("Creada", value: createdAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let confirmedAt = sale.confirmedAt {
                    LabeledContent("Confirmada", value: confirmedAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let closedAt = sale.closedAt {
                    LabeledContent("Cerrada", value: closedAt.formatted(date: .abbreviated, time: .shortened))
                }

                if let updatedAt = sale.updatedAt {
                    LabeledContent("Actualizada", value: updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
    }

    @ViewBuilder
    private func actionsSection(_ sale: BusinessSale) -> some View {
        Section("Acciones") {
            if viewModel.canCollect {
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

            if viewModel.canManageDocuments {
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

            if viewModel.canConfirm {
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
            }

            if viewModel.canCancel {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Motivo de cancelación opcional", text: $viewModel.cancelReason, axis: .vertical)
                            .textInputAutocapitalization(.sentences)
                            .lineLimit(1...3)

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
                    }
                    .padding(.vertical, 6)
                } label: {
                    Label("Cancelar venta", systemImage: "xmark.circle")
                }
            }

            if !viewModel.canCollect && !viewModel.canManageDocuments && !viewModel.canConfirm && !viewModel.canCancel {
                Text("No hay acciones pendientes para esta venta.")
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

    private func lineTotal(for item: BusinessSaleItem) -> MoneyAmount {
        item.total ?? item.subtotal ?? MoneyAmount(amount: "0.00")
    }

    private func money(_ value: MoneyAmount) -> String {
        value.displayText
    }
}

private struct NexoSaleDetailStatusRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
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
