//
//  CashDashboardRouteView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import SwiftUI

struct CashDashboardRouteView: View {
    @State private var viewModel: CashDashboardViewModel
    private let refreshOnAppear: Bool

    init(
        viewModel: CashDashboardViewModel,
        refreshOnAppear: Bool = false
    ) {
        _viewModel = State(initialValue: viewModel)
        self.refreshOnAppear = refreshOnAppear
    }

    var body: some View {
        CashDashboardView(
            viewModel: viewModel,
            refreshOnAppear: refreshOnAppear
        )
    }
}
