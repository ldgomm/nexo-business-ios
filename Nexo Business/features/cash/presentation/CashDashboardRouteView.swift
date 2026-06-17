//
//  CashDashboardRouteView.swift
//  Nexo Business
//

import SwiftUI

struct CashDashboardRouteView: View {
    @State private var viewModel: CashDashboardViewModel

    init(viewModel: CashDashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CashDashboardView(viewModel: viewModel)
    }
}
