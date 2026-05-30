//
//  SaleCartView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct SaleCartView: View {
    @Bindable private var viewModel: SaleCartViewModel
    private let customersRepository: CustomersRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    public init(
        viewModel: SaleCartViewModel,
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

    public var body: some View {
        Form {
            customerSection
            searchSection
            resultsSection
            cartSection
            previewSection
            saleSection
            messagesSection
            actionsSection
        }
        .navigationTitle("Venta rápida")
    }

    private var customerSection: some View {
        Section("Cliente") {
            if let customer = viewModel.selectedCustomer {
                CustomerRowView(customer: customer)

                Button(role: .destructive) {
                    viewModel.clearCustomer()
                } label: {
                    Label("Quitar cliente", systemImage: "xmark.circle")
                }
            } else {
                Label("Sin cliente identificado", systemImage: "person.crop.circle.badge.questionmark")
                    .foregroundStyle(.secondary)
            }

            NavigationLink {
                CustomerPickerView(
                    viewModel: CustomerPickerViewModel(
                        organizationId: viewModel.organizationId,
                        effectivePermissions: viewModel.effectivePermissions,
                        customersRepository: customersRepository
                    ),
                    onSelect: { customer in
                        viewModel.selectCustomer(customer)
                    }
                )
            } label: {
                Label("Seleccionar cliente", systemImage: "person.text.rectangle")
            }
        }
    }

    private var searchSection: some View {
        Section("Buscar producto o servicio") {
            TextField("Nombre, SKU o código", text: $viewModel.searchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.searchCatalog() }
                }

            Button {
                Task { await viewModel.searchCatalog() }
            } label: {
                if viewModel.isSearching {
                    ProgressView()
                } else {
                    Label("Buscar", systemImage: "magnifyingglass")
                }
            }
            .disabled(viewModel.isSearching)
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        if !viewModel.searchResults.isEmpty {
            Section("Resultados") {
                ForEach(viewModel.searchResults) { item in
                    Button {
                        viewModel.addToCart(item)
                    } label: {
                        CatalogResultRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cartSection: some View {
        Section("Carrito") {
            if viewModel.cartItems.isEmpty {
                ContentUnavailableView(
                    "Carrito vacío",
                    systemImage: "cart",
                    description: Text("Busca productos o servicios y agrégalos a la venta.")
                )
            } else {
                ForEach(viewModel.cartItems) { item in
                    SaleCartRow(
                        item: item,
                        quantity: quantityBinding(for: item),
                        removeAction: {
                            viewModel.removeFromCart(cartItemId: item.id)
                        }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if let preview = viewModel.preview {
            Section("Preview validado por backend") {
                ForEach(preview.items, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.subheadline.weight(.semibold))

                        Text("Cantidad: \(item.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LabeledContent(
                            "Total línea",
                            value: money(item.total ?? item.subtotal ?? MoneyAmount(amount: "0.00"))
                        )
                    }
                    .padding(.vertical, 4)
                }

                LabeledContent("Subtotal", value: money(preview.totals.subtotalWithoutTaxes))
                LabeledContent("Impuestos", value: money(preview.totals.taxTotal))
                LabeledContent("Total", value: money(preview.totals.grandTotal))
            }
        }
    }

    @ViewBuilder
    private var saleSection: some View {
        if let sale = viewModel.createdSale {
            Section("Venta creada") {
                LabeledContent("ID", value: sale.id)
                LabeledContent("Estado", value: sale.status)
                if let paymentStatus = sale.paymentStatus {
                    LabeledContent("Pago", value: paymentStatus)
                }
                if let documentStatus = sale.documentStatus {
                    LabeledContent("Documento", value: documentStatus)
                }
                LabeledContent("Total", value: money(sale.totals.grandTotal))

                NavigationLink("Abrir detalle de venta") {
                    SaleDetailView(
                        viewModel: viewModel.makeSaleDetailViewModel(for: sale),
                        customersRepository: customersRepository,
                        cashRepository: cashRepository,
                        paymentsRepository: paymentsRepository,
                        receivablesRepository: receivablesRepository,
                        documentsRepository: documentsRepository
                    )
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

    private var actionsSection: some View {
        Section {
            Button {
                Task { await viewModel.loadPreview() }
            } label: {
                if viewModel.isPreviewing {
                    ProgressView()
                } else {
                    Label("Previsualizar venta", systemImage: "doc.text.magnifyingglass")
                }
            }
            .disabled(!viewModel.canPreview)

            Button {
                Task { await viewModel.createQuickSale() }
            } label: {
                if viewModel.isCreatingSale {
                    ProgressView()
                } else {
                    Label("Crear venta rápida", systemImage: "checkmark.circle")
                }
            }
            .disabled(!viewModel.canCreateSale)

            Button(role: .destructive) {
                viewModel.clearCart()
            } label: {
                Label("Limpiar carrito", systemImage: "trash")
            }
            .disabled(viewModel.cartItems.isEmpty)
        }
    }

    private func quantityBinding(for item: SaleCartItem) -> Binding<String> {
        Binding(
            get: {
                viewModel.quantity(for: item.id)
            },
            set: { newValue in
                viewModel.updateQuantity(
                    cartItemId: item.id,
                    quantity: newValue
                )
            }
        )
    }

    private func money(_ value: MoneyAmount) -> String {
        "\(value.currency) \(value.amount)"
    }
}

private struct CatalogResultRow: View {
    let item: BusinessCatalogItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let sku = item.sku, !sku.isEmpty {
                    Text("SKU: \(sku)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let description = item.itemDescription, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let price = item.price {
                    Text("\(price.currency) \(price.amount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch item.type {
        case "service":
            return "person.text.rectangle"
        case "activity":
            return "calendar.badge.clock"
        case "package", "combo":
            return "shippingbox"
        default:
            return "tag"
        }
    }
}

private struct SaleCartRow: View {
    let item: SaleCartItem
    @Binding var quantity: String
    let removeAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.catalogItem.name)
                    .font(.subheadline.weight(.semibold))

                if let price = item.catalogItem.price {
                    Text("\(price.currency) \(price.amount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            TextField("Cant.", text: $quantity)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
                .textFieldStyle(.roundedBorder)

            Button(role: .destructive, action: removeAction) {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        SaleCartView(
            viewModel: SaleCartViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                activityId: PreviewData.businessContext.activities[0].id,
                revisions: PreviewData.businessContext.revisions,
                effectivePermissions: PreviewData.businessContext.effectivePermissions,
                catalogRepository: PreviewCatalogRepository(),
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
