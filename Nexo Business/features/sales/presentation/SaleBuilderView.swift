//
//  SaleBuilderView.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct SaleBuilderView: View {
    @Bindable private var viewModel: SaleBuilderViewModel

    public init(viewModel: SaleBuilderViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        Form {
            Section("Producto") {
                TextField("Catalog item id", text: $viewModel.catalogItemId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Cantidad", text: $viewModel.quantity)
                    .keyboardType(.decimalPad)
            }

            if let preview = viewModel.preview {
                Section("Preview") {
                    LabeledContent("Subtotal", value: preview.totals.subtotalWithoutTaxes.amount)
                    LabeledContent("Impuestos", value: preview.totals.taxTotal.amount)
                    LabeledContent("Total", value: preview.totals.grandTotal.amount)
                }
            }

            if let sale = viewModel.createdSale {
                Section("Venta") {
                    LabeledContent("ID", value: sale.id)
                    LabeledContent("Estado", value: sale.status)
                    LabeledContent("Total", value: sale.totals.grandTotal.amount)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Section {
                Button("Previsualizar") {
                    Task { await viewModel.loadPreview() }
                }
                .disabled(viewModel.catalogItemId.isEmpty || viewModel.isLoading)

                Button("Crear venta rápida") {
                    Task { await viewModel.createQuickSale() }
                }
                .disabled(viewModel.catalogItemId.isEmpty || viewModel.isLoading)
            }
        }
        .navigationTitle("Venta rápida")
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
