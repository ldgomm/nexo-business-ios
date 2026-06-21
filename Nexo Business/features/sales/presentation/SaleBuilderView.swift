//
//  SaleBuilderView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI

struct SaleBuilderView: View {
    @Bindable private var viewModel: SaleBuilderViewModel
    @State private var showStartNewOrderConfirmation = false

    init(viewModel: SaleBuilderViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(orderStateTitle)
                            .font(.headline)
                        Text(orderStateDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    NexoStatusBadge(
                        viewModel.orderState.displayName,
                        systemImage: viewModel.createdSaleNeedsCollection ? "exclamationmark.triangle" : "circle.fill",
                        style: viewModel.createdSale == nil ? .info : viewModel.createdSaleMessageStyle
                    )
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
                    NexoMessageBanner(message, style: viewModel.createdSale == nil ? .success : viewModel.createdSaleMessageStyle)
                }
            }

            Section("Acciones") {
                if viewModel.createdSale == nil {
                    Button {
                        NexoKeyboard.dismiss()
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
                        NexoKeyboard.dismiss()
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
                    requestStartNewOrder()
                } label: {
                    Label(
                        viewModel.createdSaleNeedsCollection ? "Guardar pendiente y crear otra" : "Nueva venta",
                        systemImage: "plus.circle"
                    )
                }
            }
        }
        .nexoKeyboardDismissable()
        .navigationTitle(navigationTitle)
        .alert(viewModel.startNewOrderConfirmationTitle, isPresented: $showStartNewOrderConfirmation) {
            Button("Cancelar", role: .cancel) {}
            Button("Sí, dejar pendiente", role: .destructive) {
                viewModel.startNewOrder()
            }
        } message: {
            Text(viewModel.startNewOrderConfirmationMessage)
        }
    }

    private var orderStateTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Venta sin cobrar"
        }

        return viewModel.createdSale == nil ? "Venta en curso" : "Venta registrada"
    }

    private var orderStateDescription: String {
        if viewModel.createdSaleNeedsCollection {
            return "La venta fue registrada, pero queda sin cobrar."
        }

        return viewModel.isOrderLocked ? "Esta venta ya fue registrada." : "Registra una sola venta por orden."
    }

    private var navigationTitle: String {
        if viewModel.createdSaleNeedsCollection {
            return "Venta sin cobrar"
        }

        return viewModel.createdSale == nil ? "Nueva venta" : "Venta registrada"
    }

    private func requestStartNewOrder() {
        if viewModel.createdSaleNeedsCollection {
            showStartNewOrderConfirmation = true
        } else {
            viewModel.startNewOrder()
        }
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
