//
//  BusinessHomeView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

public struct BusinessHomeView: View {
    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onChangeOrganization: () -> Void
    private let onChangeOperation: () -> Void
    private let onLogout: () -> Void

    public init(
        context: BusinessContextResponse,
        operationalSelection: BusinessOperationalSelection,
        container: BusinessAppContainer,
        onRefresh: @escaping () -> Void = {},
        onChangeOrganization: @escaping () -> Void = {},
        onChangeOperation: @escaping () -> Void = {},
        onLogout: @escaping () -> Void = {}
    ) {
        self.context = context
        self.operationalSelection = operationalSelection
        self.container = container
        self.onRefresh = onRefresh
        self.onChangeOrganization = onChangeOrganization
        self.onChangeOperation = onChangeOperation
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

                            Button {
                                onChangeOperation()
                            } label: {
                                Label("Cambiar sucursal/actividad", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                onChangeOrganization()
                            } label: {
                                Label("Cambiar negocio", systemImage: "building.2")
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
        let organizationId = context.organization.id
        let branchId = operationalSelection.branchId
        let activityId = operationalSelection.activityId
        let revisions = context.revisions
        let permissions = context.effectivePermissions

        return List {
            Section("Negocio") {
                Text(context.organization.commercialName)
                    .font(.headline)
                Text("RUC: \(context.organization.taxId)")
            }

            Section("Contexto operativo") {
                LabeledContent("Sucursal", value: selectedBranchName)
                LabeledContent("Actividad", value: selectedActivityName)

                Button {
                    onChangeOperation()
                } label: {
                    Label("Cambiar sucursal o actividad", systemImage: "slider.horizontal.3")
                }
            }

            Section("Estado") {
                LabeledContent("Readiness", value: context.readiness.status)
                LabeledContent("Catalog revision", value: revisions.catalogRevision)
                LabeledContent("Tax revision", value: revisions.taxConfigurationRevision)
            }

            Section("Operación") {
                if moduleGate.allows(.coreSales), hasSalesAccess(permissionGate) {
                    NavigationLink("Venta rápida") {
                        SaleCartView(
                            viewModel: SaleCartViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                activityId: activityId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                catalogRepository: container.catalogRepository,
                                salesRepository: container.salesRepository
                            ),
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

                if moduleGate.allows(.coreCash), hasCashAccess(permissionGate) {
                    NavigationLink("Caja operativa") {
                        CashDashboardView(
                            viewModel: CashDashboardViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                permissions: permissions,
                                cashRepository: container.cashRepository
                            )
                        )
                    }
                } else {
                    Label("Caja no habilitada para este usuario", systemImage: "lock")
                        .foregroundStyle(.secondary)
                }

                if hasCustomerAccess(permissionGate) {
                    NavigationLink("Clientes") {
                        CustomerDirectoryView(
                            viewModel: CustomerDirectoryViewModel(
                                organizationId: organizationId,
                                effectivePermissions: permissions,
                                customersRepository: container.customersRepository
                            )
                        )
                    }
                }

                if hasPendingAccess(permissionGate) {
                    NavigationLink("Pendientes y cierre diario") {
                        DailyClosureView(
                            viewModel: DailyClosureViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                pendingRepository: container.pendingOperationsRepository,
                                dailyReportRepository: container.dailyReportRepository,
                                cashRepository: container.cashRepository
                            ),
                            salesRepository: container.salesRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    }
                }

                if hasHistoryAccess(permissionGate) {
                    NavigationLink("Historial y búsqueda") {
                        SalesHistoryView(
                            viewModel: SalesHistoryViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                historyRepository: container.salesHistoryRepository
                            ),
                            salesRepository: container.salesRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    }
                }

                if hasInventoryAccess(permissionGate) {
                    BusinessHomeInventorySection(
                        organizationId: organizationId,
                        branchId: branchId,
                        activityId: activityId,
                        catalogRevision: revisions.catalogRevision,
                        effectivePermissions: permissions,
                        inventoryRepository: container.inventoryRepository
                    )
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

    private var selectedBranchName: String {
        context.branches.first(where: { $0.id == operationalSelection.branchId })?.name
            ?? operationalSelection.branchId
    }

    private var selectedActivityName: String {
        context.activities.first(where: { $0.id == operationalSelection.activityId })?.name
            ?? operationalSelection.activityId
    }

    private func hasSalesAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.sales.create") ||
        permissionGate.allows("sales.create") ||
        permissionGate.allows("business.sales.preview") ||
        permissionGate.allows("sales.preview")
    }

    private func hasCashAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("cash.view_current") ||
        permissionGate.allows("business.cash.view_current") ||
        permissionGate.allows("cash.open") ||
        permissionGate.allows("business.cash.open") ||
        permissionGate.allows("cash.close") ||
        permissionGate.allows("business.cash.close")
    }

    private func hasCustomerAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.customers.view") ||
        permissionGate.allows("customers.view") ||
        permissionGate.allows("business.customers.create") ||
        permissionGate.allows("customers.create")
    }

    private func hasPendingAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.pending.view") ||
        permissionGate.allows("pending.view") ||
        permissionGate.allows("business.reports.today") ||
        permissionGate.allows("reports.today") ||
        permissionGate.allows("business.reports.daily") ||
        permissionGate.allows("reports.daily")
    }

    private func hasHistoryAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.sales.view") ||
        permissionGate.allows("sales.view") ||
        permissionGate.allows("business.sales.history") ||
        permissionGate.allows("sales.history")
    }

    private func hasInventoryAccess(_ permissionGate: PermissionGate) -> Bool {
        permissionGate.allows("business.inventory.view") ||
        permissionGate.allows("inventory.view") ||
        permissionGate.allows("business.inventory.adjust") ||
        permissionGate.allows("inventory.adjust")
    }
}

#Preview {
    BusinessHomeView(
        context: PreviewData.businessContext,
        operationalSelection: PreviewData.operationalSelection,
        container: .preview
    )
}
