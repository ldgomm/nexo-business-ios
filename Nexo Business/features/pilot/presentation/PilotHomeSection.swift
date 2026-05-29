//
//  PilotHomeSection.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct PilotHomeSection: View {
    private let context: BusinessContextResponse
    private let selectedBranchId: String
    private let selectedActivityId: String
    private let store: PilotChecklistStoring

    public init(
        context: BusinessContextResponse,
        selectedBranchId: String,
        selectedActivityId: String,
        store: PilotChecklistStoring = UserDefaultsPilotChecklistStore()
    ) {
        self.context = context
        self.selectedBranchId = selectedBranchId
        self.selectedActivityId = selectedActivityId
        self.store = store
    }

    public var body: some View {
        NavigationLink {
            PilotReadinessView(
                viewModel: PilotReadinessViewModel(
                    context: context,
                    selectedBranchId: selectedBranchId,
                    selectedActivityId: selectedActivityId,
                    store: store
                )
            )
        } label: {
            Label("Cierre Fase 15 / Piloto", systemImage: "checklist.checked")
        }
    }
}

#Preview {
    NavigationStack {
        List {
            Section("Piloto") {
                PilotHomeSection(
                    context: PreviewData.businessContext,
                    selectedBranchId: PreviewData.businessContext.branches.first?.id ?? "",
                    selectedActivityId: PreviewData.businessContext.activities.first?.id ?? "",
                    store: PreviewPilotChecklistStore()
                )
            }
        }
    }
}
