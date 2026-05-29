//
//  BusinessHomeView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessHomeView: View {
    private let context: BusinessContextResponse
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onLogout: () -> Void

    public init(
        context: BusinessContextResponse,
        container: BusinessAppContainer,
        onRefresh: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {}
    ) {
        self.context = context
        self.container = container
        self.onRefresh = onRefresh
        self.onLogout = onLogout
    }

    public var body: some View {
        NavigationStack {
            loadedContent(context)
                .navigationTitle("Nexo Business")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                onRefresh()
                            } label: {
                                Label("Actualizar contexto", systemImage: "arrow.clockwise")
                            }

                            Button(role: .destructive) {
                                onLogout()
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

    private func loadedContent(_ context: BusinessContextResponse) -> some View {
        let moduleGate = ModuleGate(activeModules: context.activeModules)
        let permissionGate = PermissionGate(effectivePermissions: context.effectivePermissions)
        let branchId = context.branches.first?.id ?? ""
        let activityId = context.activities.first?.id ?? ""

        return List {
            Section("Negocio") {
                Text(context.organization.commercialName)
                    .font(.headline)
                Text("RUC: \(context.organization.taxId)")
            }

            Section("Estado") {
                LabeledContent("Readiness", value: context.readiness.status)
                LabeledContent("Catalog revision", value: context.revisions.catalogRevision)
                LabeledContent("Tax revision", value: context.revisions.taxConfigurationRevision)
            }

            Section("Operación") {
                if moduleGate.allows(.coreSales), hasSalesAccess(permissionGate) {
                    NavigationLink("Venta rápida") {
                        SaleCartView(
                            viewModel: SaleCartViewModel(
                                organizationId: context.organization.id,
                                branchId: branchId,
                                activityId: activityId,
                                revisions: context.revisions,
                                effectivePermissions: context.effectivePermissions,
                                catalogRepository: container.catalogRepository,
                                salesRepository: container.salesRepository
                            ),
                            customersRepository: container.customersRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    }
                } else {
                    Label("Ventas no habilitadas para este usuario", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }

                if hasCustomerAccess(permissionGate) {
                    NavigationLink("Clientes") {
                        CustomerDirectoryView(
                            viewModel: CustomerDirectoryViewModel(
                                organizationId: context.organization.id,
                                effectivePermissions: context.effectivePermissions,
                                customersRepository: container.customersRepository
                            )
                        )
                    }
                } else {
                    Label("Clientes no habilitado para este usuario", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }

                if moduleGate.allows(.coreCash), hasCashAccess(permissionGate) {
                    NavigationLink("Caja operativa") {
                        CashDashboardView(
                            viewModel: CashDashboardViewModel(
                                organizationId: context.organization.id,
                                branchId: branchId,
                                permissions: context.effectivePermissions,
                                cashRepository: container.cashRepository
                            )
                        )
                    }
                } else {
                    Label("Caja no habilitada para este usuario", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Módulos activos") {
                ForEach(context.activeModules.map(\.rawValue).sorted(), id: \.self) { module in
                    Text(module)
                        .font(.footnote.monospaced())
                }
            }
        }
    }

    private func hasSalesAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.sales.create") ||
        permissionGate.allows("sales.create") ||
        permissionGate.allows("business.sales.preview") ||
        permissionGate.allows("sales.preview")
    }

    private func hasCustomerAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.customers.view") ||
        permissionGate.allows("customers.view") ||
        permissionGate.allows("business.customers.create") ||
        permissionGate.allows("customers.create")
    }

    private func hasCashAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("cash.view_current") ||
        permissionGate.allows("business.cash.view_current") ||
        permissionGate.allows("cash.open") ||
        permissionGate.allows("business.cash.open") ||
        permissionGate.allows("cash.close") ||
        permissionGate.allows("business.cash.close")
    }
}


#Preview {
    BusinessHomeView(
        context: PreviewData.businessContext,
        container: .preview
    )
}
