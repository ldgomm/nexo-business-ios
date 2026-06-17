//
//  BusinessDocumentsRouteView.swift
//  Nexo Business
//
//  Created by José Ruiz on 16/6/26.
//

import SwiftUI

struct BusinessDocumentsRouteView: View {
    @State private var viewModel: BusinessDocumentsViewModel
    private let onSaleUpdated: (BusinessSale) -> Void

    init(
        viewModel: BusinessDocumentsViewModel,
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onSaleUpdated = onSaleUpdated
    }

    init(
        organizationId: String,
        sale: BusinessSale,
        effectivePermissions: Set<String>,
        branchId: String? = nil,
        activityId: String? = nil,
        revisions: BusinessRevisions? = nil,
        documentsRepository: BusinessDocumentsRepository,
        onSaleUpdated: @escaping (BusinessSale) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: BusinessDocumentsViewModel(
            organizationId: organizationId,
            sale: sale,
            effectivePermissions: effectivePermissions,
            branchId: branchId,
            activityId: activityId,
            revisions: revisions,
            documentsRepository: documentsRepository
        ))
        self.onSaleUpdated = onSaleUpdated
    }

    var body: some View {
        BusinessDocumentsView(
            viewModel: viewModel,
            onSaleUpdated: onSaleUpdated
        )
    }
}
