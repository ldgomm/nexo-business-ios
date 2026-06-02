//
//  BusinessOperationalSelectionView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct BusinessOperationalSelectionView: View {
    private let context: BusinessContextResponse
    private let reason: String?
    private let continueAction: (String, String) -> Void
    private let changeOrganizationAction: () -> Void
    private let logoutAction: () -> Void

    @State private var selectedBranchId: String
    @State private var selectedActivityId: String

    init(
        context: BusinessContextResponse,
        reason: String? = nil,
        continueAction: @escaping (String, String) -> Void,
        changeOrganizationAction: @escaping () -> Void,
        logoutAction: @escaping () -> Void
    ) {
        self.context = context
        self.reason = reason
        self.continueAction = continueAction
        self.changeOrganizationAction = changeOrganizationAction
        self.logoutAction = logoutAction

        _selectedBranchId = State(initialValue: Self.initialBranchId(context: context))
        _selectedActivityId = State(initialValue: Self.initialActivityId(context: context))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Negocio") {
                    Text(context.organization.commercialName)
                        .font(.headline)
                    Text("RUC: \(context.organization.taxId)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let reason, !reason.isEmpty {
                    Section {
                        Label(reason, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Sucursal") {
                    Picker("Sucursal", selection: $selectedBranchId) {
                        ForEach(selectableBranches) { branch in
                            Text(branch.name).tag(branch.id)
                        }
                    }

                    if selectableBranches.isEmpty {
                        Label("No hay sucursales activas para operar.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Actividad") {
                    Picker("Actividad", selection: $selectedActivityId) {
                        ForEach(selectableActivities) { activity in
                            Text(activity.name).tag(activity.id)
                        }
                    }

                    if selectableActivities.isEmpty {
                        Label("No hay actividades activas para operar.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }

                Section("Continuar") {
                    Button {
                        continueAction(selectedBranchId, selectedActivityId)
                    } label: {
                        Label("Entrar a operar", systemImage: "checkmark.circle")
                    }
                    .disabled(selectedBranchId.isEmpty || selectedActivityId.isEmpty)
                }
            }
            .navigationTitle("Contexto operativo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            changeOrganizationAction()
                        } label: {
                            Label("Cambiar negocio", systemImage: "building.2")
                        }

                        Button(role: .destructive) {
                            logoutAction()
                        } label: {
                            Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var selectableBranches: [BusinessBranch] {
        let active = context.branches.filter { $0.status.lowercased() == "active" }
        return active.isEmpty ? context.branches : active
    }

    private var selectableActivities: [BusinessActivity] {
        let active = context.activities.filter { $0.status.lowercased() == "active" }
        return active.isEmpty ? context.activities : active
    }

    private static func initialBranchId(context: BusinessContextResponse) -> String {
        context.branches.first(where: { $0.status.lowercased() == "active" })?.id
            ?? context.branches.first?.id
            ?? ""
    }

    private static func initialActivityId(context: BusinessContextResponse) -> String {
        context.activities.first(where: { $0.status.lowercased() == "active" })?.id
            ?? context.activities.first?.id
            ?? ""
    }
}

#Preview {
    BusinessOperationalSelectionView(
        context: PreviewData.businessContext,
        reason: "Selecciona dónde vas a vender y cobrar.",
        continueAction: { _, _ in },
        changeOrganizationAction: {},
        logoutAction: {}
    )
}
