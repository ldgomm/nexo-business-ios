//
//  BusinessHomeView.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import SwiftUI

struct BusinessHomeView: View {
    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onChangeOrganization: () -> Void
    private let onChangeOperation: () -> Void
    private let onLogout: () -> Void

    init(
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

    var body: some View {
        TabView {
            sellTab
                .tabItem {
                    Label("Vender", systemImage: "cart.badge.plus")
                }

            todayTab
                .tabItem {
                    Label("Hoy", systemImage: "chart.bar.doc.horizontal")
                }

            cashTab
                .tabItem {
                    Label("Caja", systemImage: "banknote")
                }

            historyTab
                .tabItem {
                    Label("Historial", systemImage: "clock.arrow.circlepath")
                }

            businessTab
                .tabItem {
                    Label("Negocio", systemImage: "building.2")
                }
        }
    }

    private var sellTab: some View {
        NavigationStack {
            if capabilityGate.canAccessSales {
                SaleCartView(
                    viewModel: SaleCartViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        activityId: activityId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        catalogRepository: container.catalogRepository,
                        salesRepository: container.salesRepository,
                        salesHistoryRepository: container.salesHistoryRepository,
                        contextRepository: container.contextRepository
                    ),
                    customersRepository: container.customersRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    salesHistoryRepository: container.salesHistoryRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Ventas no habilitadas",
                    message: "Tu usuario no tiene permiso para crear ventas en este contexto.",
                    systemImage: "lock"
                )
                .navigationTitle("Vender")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }

    private var todayTab: some View {
        NavigationStack {
            if capabilityGate.canAccessToday {
                DailyClosureView(
                    viewModel: DailyClosureViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        pendingRepository: container.pendingOperationsRepository,
                        dailyReportRepository: container.dailyReportRepository,
                        cashRepository: container.cashRepository,
                        historyRepository: container.salesHistoryRepository
                    ),
                    salesRepository: container.salesRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Hoy no habilitado",
                    message: "Tu usuario no tiene permiso para consultar ventas del día, pendientes o cierre diario.",
                    systemImage: "chart.bar.doc.horizontal"
                )
                .navigationTitle("Hoy")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }

    private var cashTab: some View {
        NavigationStack {
            if capabilityGate.canAccessCash {
                CashDashboardView(
                    viewModel: CashDashboardViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        permissions: permissions,
                        cashCapabilities: context.capabilities.cash,
                        cashRepository: container.cashRepository
                    )
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Caja no habilitada",
                    message: "Tu usuario no tiene permiso para abrir, consultar o cerrar caja.",
                    systemImage: "banknote"
                )
                .navigationTitle("Caja")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }

    private var historyTab: some View {
        NavigationStack {
            if capabilityGate.canAccessHistory {
                SalesHistoryView(
                    viewModel: SalesHistoryViewModel(
                        organizationId: organizationId,
                        branchId: branchId,
                        revisions: revisions,
                        effectivePermissions: permissions,
                        historyRepository: container.salesHistoryRepository,
                        documentsRepository: container.documentsRepository
                    ),
                    salesRepository: container.salesRepository,
                    salesHistoryRepository: container.salesHistoryRepository,
                    cashRepository: container.cashRepository,
                    paymentsRepository: container.paymentsRepository,
                    receivablesRepository: container.receivablesRepository,
                    documentsRepository: container.documentsRepository
                )
                .toolbar {
                    commonToolbar
                }
            } else {
                LockedOperationalView(
                    title: "Historial no habilitado",
                    message: "Tu usuario no tiene permiso para consultar ventas anteriores.",
                    systemImage: "clock.arrow.circlepath"
                )
                .navigationTitle("Historial")
                .toolbar {
                    commonToolbar
                }
            }
        }
    }

    private var businessTab: some View {
        BusinessView(
            context: context,
            operationalSelection: operationalSelection,
            container: container,
            onRefresh: onRefresh,
            onChangeOrganization: onChangeOrganization,
            onChangeOperation: onChangeOperation,
            onLogout: onLogout
        )
    }

    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
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

    private var capabilityGate: BusinessCapabilityGate {
        BusinessCapabilityGate(capabilities: context.capabilities)
    }

    private var organizationId: String {
        context.organization.id
    }

    private var branchId: String {
        operationalSelection.branchId
    }

    private var activityId: String {
        operationalSelection.activityId
    }

    private var revisions: BusinessRevisions {
        context.revisions
    }

    private var permissions: Set<String> {
        context.effectivePermissions
    }
}

private struct LockedOperationalView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 84, height: 84)
                    .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06))
            )
            .padding(16)
            .padding(.top, 36)
        }
        .background(Color(.systemGroupedBackground))
    }
}
