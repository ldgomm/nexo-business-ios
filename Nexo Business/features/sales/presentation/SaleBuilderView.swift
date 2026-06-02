import SwiftUI

struct SaleBuilderView: View {
    @Bindable private var viewModel: SaleBuilderViewModel

    init(viewModel: SaleBuilderViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.createdSale == nil ? "Venta en curso" : "Venta cerrada")
                            .font(.headline)
                        Text(viewModel.isOrderLocked ? "Esta venta ya fue registrada." : "Registra una sola venta por orden.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    NexoStatusBadge(viewModel.orderState.displayName)
                }
            }

            if !viewModel.isOrderLocked {
                Section("Producto") {
                    TextField("Catalog item id", text: $viewModel.catalogItemId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Cantidad", text: $viewModel.quantity)
                        .keyboardType(.decimalPad)
                }
            }

            if let preview = viewModel.preview {
                Section("Cálculo validado") {
                    NexoMoneyTotalView(title: "Subtotal", amount: preview.totals.subtotalWithoutTaxes)
                    NexoMoneyTotalView(title: "Impuestos", amount: preview.totals.taxTotal)
                    NexoMoneyTotalView(title: "Total", amount: preview.totals.grandTotal, isProminent: true)
                }
            }

            if let sale = viewModel.createdSale {
                Section {
                    NexoSaleSuccessCard(sale: sale)
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    NexoMessageBanner(message, style: .error)
                }
            }

            if let message = viewModel.infoMessage {
                Section {
                    NexoMessageBanner(message, style: .success)
                }
            }

            Section("Acciones") {
                if viewModel.createdSale == nil {
                    Button {
                        Task { await viewModel.loadPreview() }
                    } label: {
                        if viewModel.isLoading && viewModel.orderState == .previewing {
                            ProgressView()
                        } else {
                            Label("Calcular total", systemImage: "doc.text.magnifyingglass")
                        }
                    }
                    .disabled(!viewModel.canPreview)

                    Button {
                        Task { await viewModel.createQuickSale() }
                    } label: {
                        if viewModel.isLoading && viewModel.orderState == .creating {
                            ProgressView()
                        } else {
                            Label("Registrar venta", systemImage: "checkmark.seal.fill")
                        }
                    }
                    .disabled(!viewModel.canCreateSale)
                }

                Button {
                    viewModel.startNewOrder()
                } label: {
                    Label("Nueva venta", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle(viewModel.createdSale == nil ? "Nueva venta" : "Venta registrada")
    }
}

#Preview {
    NavigationStack {
        SaleBuilderView(
            viewModel: SaleBuilderViewModel(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches[0].id,
                activityId: PreviewData.businessContext.activities[0].id,
                revisions: PreviewData.businessContext.revisions,
                salesRepository: PreviewSalesRepository()
            )
        )
    }
}
