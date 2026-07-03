//
//  BusinessView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI
import Foundation
import Observation

struct BusinessView: View {
    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onChangeOrganization: () -> Void
    private let onChangeOperation: () -> Void
    private let onLogout: () -> Void

    @State private var isLogoutConfirmationPresented = false
    @State private var supportNotificationsViewModel: BusinessSupportNotificationsViewModel

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
        self._supportNotificationsViewModel = State(
            wrappedValue: BusinessSupportNotificationsViewModel(
                repository: container.supportNotificationsRepository,
                organizationId: context.organization.id,
                branchId: operationalSelection.branchId
            )
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    operationHero
                    restaurantContextCard
                    dailyOperationCard
                    toolsCard
                    reportingCard
                    contextCard
                    businessCard
                    accountCard
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 11)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Centro del Negocio")
            .toolbar {
                commonToolbar
            }
        }
        .confirmationDialog(
            "¿Cerrar sesión?",
            isPresented: $isLogoutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Cerrar sesión", role: .destructive) {
                onLogout()
            }

            Button("Cancelar", role: .cancel) { }
        } message: {
            Text("Saldrás de este dispositivo. Puedes volver a entrar con tus credenciales.")
        }
    }
    private var operationHero: some View {
        BusinessHeroCard(
            organizationName: context.organization.commercialName,
            subtitle: "\(selectedBranchName) · \(selectedActivityName)",
            readiness: context.readiness.status,
            taxId: context.organization.taxId,
            countryCode: context.organization.countryCode,
            readinessTint: readinessTint
        )
    }

    @ViewBuilder
    private var restaurantContextCard: some View {
        if let restaurant = context.verticals.restaurant {
            BusinessCard(
                title: "Restaurante v1 activo",
                subtitle: "Venta rápida sigue siendo el flujo principal. Mesas y tipo de servicio son soporte operativo."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        BusinessPill(title: restaurant.displayName, systemImage: "fork.knife", tint: .accentColor)
                        BusinessPill(title: restaurant.status.capitalized, systemImage: "checkmark.seal", tint: restaurant.status.lowercased() == "active" ? .green : .orange)
                        BusinessPill(title: "v\(restaurant.packageVersion)", systemImage: "number", tint: .secondary)
                    }

                    BusinessMetaRow(
                        title: "Modo",
                        value: context.verticals.workMode ?? restaurant.defaultWorkMode ?? "quick_sale",
                        isMonospaced: true
                    )

                    BusinessRestaurantOperationalStatusCard(
                        workMode: context.verticals.workMode ?? restaurant.defaultWorkMode ?? "quick_sale",
                        hasTables: hasRestaurantTablesCapability
                    )

                    NavigationLink {
                        BusinessTechnicalStatusView(
                            context: context,
                            operationalSelection: operationalSelection,
                            container: container,
                            onRefresh: onRefresh
                        )
                    } label: {
                        BusinessActionLabel(
                            title: "Ver estado técnico",
                            subtitle: "Readiness, capacidades y checks de Restaurante v1",
                            systemImage: "stethoscope",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var supportNotificationsCard: some View {
        NavigationLink {
            BusinessSupportEntryPointsView(
                notificationUnreadCount: supportNotificationsViewModel.unreadCount,
                latestNotificationTitle: supportNotificationsViewModel.latestTitle,
                latestNotificationSummary: supportNotificationsViewModel.latestSummary,
                onRefreshNotifications: {
                    Task {
                        await supportNotificationsViewModel.refresh()
                    }
                }
            )
            .task {
                await supportNotificationsViewModel.refreshIfNeeded()
            }
        } label: {
            BusinessSupportHomeRow(
                unreadCount: supportNotificationsViewModel.unreadCount,
                latestTitle: supportNotificationsViewModel.latestTitle,
                latestSummary: supportNotificationsViewModel.latestSummary
            )
        }
        .buttonStyle(.plain)
        .task {
            await supportNotificationsViewModel.refreshIfNeeded()
        }
    }

    @ViewBuilder
    private var dailyOperationCard: some View {
        BusinessCard(
            title: "Operación diaria",
            subtitle: "Lo que se usa durante el turno: vender, cobrar, revisar caja y cerrar el día."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 12) {
                if capabilityGate.canAccessSales {
                    NavigationLink {
                        makeSaleCartView()
                    } label: {
                        BusinessToolTile(
                            title: "Venta rápida",
                            subtitle: "Vender y cobrar",
                            systemImage: "cart.badge.plus",
                            tint: .accentColor
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Venta rápida",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if hasRestaurantTablesCapability {
                    if canAccessRestaurantTables {
                        NavigationLink {
                            makeRestaurantTablesView()
                        } label: {
                            BusinessToolTile(
                                title: "Mesas",
                                subtitle: "Ocupación",
                                systemImage: "tablecells",
                                tint: .orange
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        BusinessToolTile(
                            title: "Mesas",
                            subtitle: "Sin permiso",
                            systemImage: "lock",
                            tint: .secondary,
                            isDisabled: true
                        )
                    }
                }

                if capabilityGate.canAccessCash {
                    NavigationLink {
                        makeCashDashboardView(refreshOnAppear: true)
                    } label: {
                        BusinessToolTile(
                            title: "Caja",
                            subtitle: "Apertura y cierre",
                            systemImage: "banknote",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Caja",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessHistory {
                    NavigationLink {
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
                            customersRepository: container.customersRepository,
                            catalogRepository: container.catalogRepository,
                            contextRepository: container.contextRepository,
                            verticalContext: context.verticals,
                            salesHistoryRepository: container.salesHistoryRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Historial",
                            subtitle: "Ventas y pagos",
                            systemImage: "clock.arrow.circlepath",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Historial",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessHistory {
                    NavigationLink {
                        UnpaidSalesListView(
                            viewModel: UnpaidSalesListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                revisions: revisions,
                                effectivePermissions: permissions,
                                pendingRepository: container.pendingOperationsRepository
                            ),
                            salesRepository: container.salesRepository,
                            customersRepository: container.customersRepository,
                            catalogRepository: container.catalogRepository,
                            contextRepository: container.contextRepository,
                            verticalContext: context.verticals,
                            salesHistoryRepository: container.salesHistoryRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Ventas pendientes",
                            subtitle: "Continuar cobro",
                            systemImage: "bookmark",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Ventas pendientes",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessToday {
                    NavigationLink {
                        makeDailyClosureView()
                    } label: {
                        BusinessToolTile(
                            title: "Reporte de hoy",
                            subtitle: "Corte del día",
                            systemImage: "chart.bar.doc.horizontal",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Reporte de hoy",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }
            }

            BusinessInlineMessage(
                message: "Ventas pendientes son guardadas o cobros incompletos. Las deudas reales viven en Por cobrar.",
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    @ViewBuilder
    private var toolsCard: some View {
        BusinessCard(
            title: "Gestión comercial",
            subtitle: "Clientes, productos, cotizaciones, cartera e inventario."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 12) {
                if capabilityGate.canAccessCustomers {
                    NavigationLink {
                        CustomerDirectoryView(
                            viewModel: CustomerDirectoryViewModel(
                                organizationId: organizationId,
                                effectivePermissions: permissions,
                                customersRepository: container.customersRepository
                            ),
                            branchId: branchId,
                            revisions: context.revisions,
                            salesHistoryRepository: container.salesHistoryRepository,
                            salesRepository: container.salesRepository,
                            cashRepository: container.cashRepository,
                            paymentsRepository: container.paymentsRepository,
                            receivablesRepository: container.receivablesRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Clientes",
                            subtitle: "Directorio",
                            systemImage: "person.2",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessSales {
                    NavigationLink {
                        ProductsListView(
                            viewModel: ProductsListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                activityId: activityId,
                                catalogRevision: revisions.catalogRevision,
                                repository: container.productsRepository
                            )
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Productos",
                            subtitle: "Catálogo y precios",
                            systemImage: "shippingbox.fill",
                            tint: .teal
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessSales {
                    NavigationLink {
                        makeBusinessProformasView()
                    } label: {
                        BusinessToolTile(
                            title: "Proformas",
                            subtitle: "Cotizar sin cobrar",
                            systemImage: "doc.badge.plus",
                            tint: .indigo
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Proformas",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if capabilityGate.canAccessReceivables {
                    NavigationLink {
                        ReceivablesListView(
                            viewModel: ReceivablesListViewModel(
                                organizationId: organizationId,
                                branchId: branchId,
                                effectivePermissions: permissions,
                                receivablesRepository: container.receivablesRepository,
                                customersRepository: container.customersRepository
                            ),
                            cashRepository: container.cashRepository,
                            receivablesRepository: container.receivablesRepository,
                            revisions: context.revisions,
                            salesHistoryRepository: container.salesHistoryRepository,
                            salesRepository: container.salesRepository,
                            paymentsRepository: container.paymentsRepository,
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Por cobrar",
                            subtitle: "Cartera real",
                            systemImage: "person.crop.circle.badge.clock",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                }

                if capabilityGate.canAccessInventory {
                    NavigationLink {
                        makeInventoryDashboardView()
                    } label: {
                        BusinessToolTile(
                            title: "Inventario",
                            subtitle: "Stock y movimientos",
                            systemImage: "shippingbox",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Inventario",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if canAccessTeamManagement {
                    NavigationLink {
                        BusinessTeamView(
                            viewModel: BusinessTeamViewModel(
                                repository: container.teamRepository,
                                effectivePermissions: permissions
                            )
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Equipo",
                            subtitle: "Usuarios y roles",
                            systemImage: "person.3.sequence",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            BusinessInlineMessage(
                message: "Proformas no cobra, no factura y no toca SRI. Solo convierte a venta cuando el cliente acepta.",
                systemImage: "doc.badge.plus",
                tint: .secondary
            )
        }
    }

    @ViewBuilder
    private var reportingCard: some View {
        BusinessCard(
            title: "Reportes y documentos",
            subtitle: "Comprobantes, exportación operativa y paquete mensual para contador."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 12) {
                if canAccessElectronicDocumentVault {
                    NavigationLink {
                        BusinessElectronicDocumentsListView(
                            viewModel: BusinessElectronicDocumentsViewModel(
                                organizationId: organizationId,
                                effectivePermissions: permissions,
                                documentsRepository: container.documentsRepository
                            ),
                            documentsRepository: container.documentsRepository
                        )
                    } label: {
                        BusinessToolTile(
                            title: "Comprobantes",
                            subtitle: "RIDE y XML",
                            systemImage: "doc.text.magnifyingglass",
                            tint: .green
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Comprobantes",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if canAccessOperationalExports {
                    NavigationLink {
                        makeBusinessExportsView()
                    } label: {
                        BusinessToolTile(
                            title: "Exportación diaria",
                            subtitle: "ZIP operativo",
                            systemImage: "square.and.arrow.down",
                            tint: .purple
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Exportación diaria",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }

                if canAccessOperationalExports {
                    NavigationLink {
                        BusinessAccountantPackSurfaceView(container: container)
                    } label: {
                        BusinessToolTile(
                            title: "Paquete contador",
                            subtitle: "ZIP mensual",
                            systemImage: "doc.zipper",
                            tint: .teal
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    BusinessToolTile(
                        title: "Paquete contador",
                        subtitle: "Sin permiso",
                        systemImage: "lock",
                        tint: .secondary,
                        isDisabled: true
                    )
                }
            }

            BusinessInlineMessage(
                message: "Estas salidas son administrativas. No reemplazan el cierre contable ni obligaciones tributarias.",
                systemImage: "info.circle",
                tint: .secondary
            )
        }
    }

    private var contextCard: some View {
        BusinessCard(
            title: "Operación activa",
            subtitle: "Sucursal, actividad y revisiones que usa esta sesión."
        ) {
            VStack(spacing: 10) {
                BusinessMetaRow(title: "Sucursal", value: selectedBranchName)
                BusinessMetaRow(title: "Actividad", value: selectedActivityName)
                BusinessMetaRow(title: "Catálogo", value: revisions.catalogRevision, isMonospaced: true)
                BusinessMetaRow(title: "Impuestos", value: revisions.taxConfigurationRevision, isMonospaced: true)

                Button {
                    onChangeOperation()
                } label: {
                    BusinessActionLabel(
                        title: "Cambiar operación",
                        subtitle: "Sucursal o actividad activa",
                        systemImage: "slider.horizontal.3",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var businessCard: some View {
        BusinessCard(
            title: "Negocio",
            subtitle: "Información visible del negocio seleccionado."
        ) {
            VStack(spacing: 10) {
                BusinessMetaRow(title: "Nombre", value: context.organization.commercialName)
                BusinessMetaRow(title: "RUC", value: context.organization.taxId, isMonospaced: true)
                BusinessMetaRow(title: "País", value: context.organization.countryCode)
            }
        }
    }

    private var accountCard: some View {
        BusinessCard(
            title: "Cuenta y soporte",
            subtitle: "Sesión, negocio activo, seguridad y diagnóstico."
        ) {
            VStack(spacing: 10) {
                supportNotificationsCard

                Button {
                    onRefresh()
                } label: {
                    BusinessActionLabel(
                        title: "Actualizar datos",
                        subtitle: "Permisos, módulos y revisiones",
                        systemImage: "arrow.clockwise",
                        tint: .accentColor
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    BusinessTechnicalStatusView(
                        context: context,
                        operationalSelection: operationalSelection,
                        container: container,
                        onRefresh: onRefresh
                    )
                } label: {
                    BusinessActionLabel(
                        title: "Estado técnico",
                        subtitle: "Permisos, módulos, verticales y readiness",
                        systemImage: "stethoscope",
                        tint: .purple
                    )
                }
                .buttonStyle(.plain)

                Button {
                    onChangeOrganization()
                } label: {
                    BusinessActionLabel(
                        title: "Cambiar negocio",
                        subtitle: "Seleccionar otra organización",
                        systemImage: "building.2",
                        tint: .blue
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    AuthSessionsView(
                        viewModel: AuthSessionsViewModel(
                            authRepository: container.authRepository
                        ),
                        onAllSessionsRevoked: onLogout
                    )
                } label: {
                    BusinessActionLabel(
                        title: "Mis sesiones",
                        subtitle: "Dispositivos activos",
                        systemImage: "iphone.and.arrow.forward",
                        tint: .orange
                    )
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    isLogoutConfirmationPresented = true
                } label: {
                    BusinessActionLabel(
                        title: "Cerrar sesión",
                        subtitle: "Salir de este dispositivo",
                        systemImage: "rectangle.portrait.and.arrow.right",
                        tint: .red
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func makeSaleCartView() -> SaleCartView {
        SaleCartView(
            viewModel: SaleCartViewModel(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                revisions: revisions,
                effectivePermissions: permissions,
                verticalContext: context.verticals,
                catalogRepository: container.catalogRepository,
                salesRepository: container.salesRepository,
                customersRepository: container.customersRepository,
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
    }

    private func makeRestaurantTablesView() -> RestaurantTablesView {
        RestaurantTablesView(
            viewModel: RestaurantTablesViewModel(
                organizationId: organizationId,
                branchId: branchId,
                effectivePermissions: permissions,
                repository: container.restaurantTablesRepository
            )
        )
    }

    private func makeDailyClosureView() -> DailyClosureView {
        DailyClosureView(
            viewModel: DailyClosureViewModel(
                organizationId: organizationId,
                branchId: branchId,
                revisions: revisions,
                effectivePermissions: permissions,
                capabilities: context.capabilities,
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
    }

    private func makeCashDashboardView(refreshOnAppear: Bool = false) -> CashDashboardView {
        CashDashboardView(
            viewModel: CashDashboardViewModel(
                organizationId: organizationId,
                branchId: branchId,
                permissions: permissions,
                cashCapabilities: context.capabilities.cash,
                cashRepository: container.cashRepository
            ),
            refreshOnAppear: refreshOnAppear
        )
    }

    private func makeInventoryDashboardView() -> InventoryDashboardView {
        InventoryDashboardView(
            viewModel: InventoryDashboardViewModel(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                catalogRevision: revisions.catalogRevision,
                effectivePermissions: permissions,
                inventoryRepository: container.inventoryRepository
            )
        )
    }

    private func makeBusinessExportsView() -> BusinessExportsView {
        BusinessExportsView(
            viewModel: BusinessExportsViewModel(
                organizationId: organizationId,
                branchId: branchId,
                effectivePermissions: permissions,
                exportsRepository: container.exportsRepository
            )
        )
    }


    private func makeBusinessProformasView() -> BusinessProformasView {
        BusinessProformasView(
            viewModel: BusinessProformasViewModel(
                organizationId: organizationId,
                branchId: branchId,
                activityId: activityId,
                revisions: revisions,
                effectivePermissions: permissions,
                repository: container.proformasRepository
            ),
            proformasRepository: container.proformasRepository,
            productsRepository: container.productsRepository,
            customersRepository: container.customersRepository,
            salesRepository: container.salesRepository,
            salesHistoryRepository: container.salesHistoryRepository,
            cashRepository: container.cashRepository,
            paymentsRepository: container.paymentsRepository,
            receivablesRepository: container.receivablesRepository,
            documentsRepository: container.documentsRepository
        )
    }

    private func capabilityDiagnosticRow(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.footnote)

            Spacer(minLength: 12)

            Label(enabled ? "Activo" : "No disponible", systemImage: enabled ? "checkmark.circle.fill" : "minus.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(enabled ? Color.green : Color.secondary)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func verticalReadinessRow(_ check: BusinessVerticalReadiness) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verticalReadinessSystemImage(check.normalizedStatus))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(verticalReadinessTint(check.normalizedStatus))
                .frame(width: 28, height: 28)
                .background(verticalReadinessTint(check.normalizedStatus).opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(check.code)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(check.normalizedStatus)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(verticalReadinessTint(check.normalizedStatus))
                }

                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func humanizedRestaurantCapability(_ capability: String) -> String {
        switch capability {
        case "restaurant.menu_attributes":
            return "Atributos menú"
        case "restaurant.service_type":
            return "Tipo servicio"
        case "restaurant.event_service":
            return "Eventos"
        case "restaurant.tables_optional":
            return "Mesas"
        case "restaurant.kitchen_basic_optional":
            return "Cocina"
        default:
            return capability
                .replacingOccurrences(of: "restaurant.", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private func verticalReadinessTint(_ status: String) -> Color {
        switch status {
        case "PASS":
            return .green
        case "WARN":
            return .orange
        case "FAIL":
            return .red
        default:
            return .secondary
        }
    }

    private func verticalReadinessSystemImage(_ status: String) -> String {
        switch status {
        case "PASS":
            return "checkmark.seal.fill"
        case "WARN":
            return "exclamationmark.triangle.fill"
        case "FAIL":
            return "xmark.octagon.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    @ToolbarContentBuilder
    private var commonToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                onRefresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Actualizar datos")
        }
    }

    private var toolColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private var restaurantEnabledCapabilities: [String] {
        let packageCapabilities = context.verticals.restaurant?.capabilities ?? []
        return Array(Set(context.verticals.capabilities + packageCapabilities))
            .filter { $0.hasPrefix("restaurant.") }
            .sorted()
    }

    private var hasRestaurantTablesCapability: Bool {
        context.verticals.hasCapability("restaurant.tables_optional")
    }

    private var canAccessRestaurantTables: Bool {
        hasRestaurantTablesCapability && (
            permissionGate.allows("tables.view") ||
            permissionGate.allows("tables.manage")
        )
    }

    private var readinessTint: Color {
        switch context.readiness.status.lowercased() {
        case "ready", "ok", "active", "enabled":
            return .green
        case "warning", "partial", "pending":
            return .orange
        case "blocked", "error", "failed":
            return .red
        default:
            return .secondary
        }
    }

    private var capabilityGate: BusinessCapabilityGate {
        BusinessCapabilityGate(capabilities: context.capabilities)
    }

    private var moduleGate: ModuleGate {
        ModuleGate(activeModules: context.activeModules)
    }

    private var permissionGate: PermissionGate {
        PermissionGate(effectivePermissions: context.effectivePermissions)
    }

    private var canAccessTeamManagement: Bool {
        permissionGate.allows("credentials.users.view") ||
        permissionGate.allows("credentials.roles.view") ||
        permissionGate.allows("credentials.users.create") ||
        permissionGate.allows("credentials.roles.manage")
    }

    private var canAccessElectronicDocumentVault: Bool {
        permissionGate.allows("documents.electronic_invoice.list") ||
        permissionGate.allows("documents.electronic_invoice.view") ||
        permissionGate.allows("documents.electronic_invoice.download_ride") ||
        permissionGate.allows("documents.electronic_invoice.download_xml") ||
        permissionGate.allows("documents.electronic_invoice.email") ||
        permissionGate.allows("documents.view") ||
        permissionGate.allows("business.documents.view")
    }


    private var canAccessOperationalExports: Bool {
        guard capabilityGate.canAccessToday || context.effectivePermissions.contains("*") else {
            return false
        }

        return permissionGate.allowsAny(Self.operationalExportPermissions) || context.effectivePermissions.contains("*")
    }

    private static let operationalExportPermissions = [
        "business.exports.view",
        "business.exports.generate",
        "business.exports.download",
        "exports.view",
        "exports.generate",
        "exports.download",
        "reports.export",
        "reports.dashboard.view",
        "reports.sales.view",
        "reports.cash.view",
        "reports.documents.view"
    ]

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

    private var selectedBranchName: String {
        context.branches.first(where: { $0.id == operationalSelection.branchId })?.name
        ?? operationalSelection.branchId
    }

    private var selectedActivityName: String {
        context.activities.first(where: { $0.id == operationalSelection.activityId })?.name
        ?? operationalSelection.activityId
    }
}

private struct BusinessTechnicalStatusView: View {
    let context: BusinessContextResponse
    let operationalSelection: BusinessOperationalSelection
    let container: BusinessAppContainer
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                summaryCard
                operationStatusCard
                capabilitiesCard
                restaurantTechnicalCard
                verticalsCard
                modulesCard
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Estado técnico")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Actualizar estado técnico")
            }
        }
    }

    private var summaryCard: some View {
        BusinessCard(
            title: "Resumen técnico",
            subtitle: "Permisos, módulos, verticales y readiness de la operación activa."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    BusinessIconBadge(systemImage: "stethoscope", tint: readinessTint)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.readiness.status)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(readinessTint)

                        Text("Diagnóstico únicamente. La operación diaria vive en Venta rápida, Caja, Historial y Mesas.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                BusinessMetaRow(title: "Negocio", value: context.organization.commercialName)
                BusinessMetaRow(title: "RUC", value: context.organization.taxId, isMonospaced: true)
                BusinessMetaRow(title: "País", value: context.organization.countryCode)
            }
        }
    }

    private var operationStatusCard: some View {
        BusinessCard(
            title: "Operación activa",
            subtitle: "Sucursal, actividad y revisiones usadas por esta sesión."
        ) {
            VStack(spacing: 10) {
                BusinessMetaRow(title: "Sucursal", value: selectedBranchName)
                BusinessMetaRow(title: "Actividad", value: selectedActivityName)
                BusinessMetaRow(title: "Catálogo", value: context.revisions.catalogRevision, isMonospaced: true)
                BusinessMetaRow(title: "Impuestos", value: context.revisions.taxConfigurationRevision, isMonospaced: true)
            }
        }
    }

    private var capabilitiesCard: some View {
        BusinessCard(
            title: "Capacidades de negocio",
            subtitle: "Qué pantallas y flujos puede usar este usuario en este negocio."
        ) {
            LazyVGrid(columns: toolColumns, spacing: 8) {
                technicalCapabilityRow("Ventas", enabled: capabilityGate.canAccessSales)
                technicalCapabilityRow("Hoy", enabled: capabilityGate.canAccessToday)
                technicalCapabilityRow("Caja", enabled: capabilityGate.canAccessCash)
                technicalCapabilityRow("Historial", enabled: capabilityGate.canAccessHistory)
                technicalCapabilityRow("Ventas pendientes", enabled: capabilityGate.canAccessHistory)
                technicalCapabilityRow("Clientes", enabled: capabilityGate.canAccessCustomers)
                technicalCapabilityRow("Cuentas por cobrar", enabled: capabilityGate.canAccessReceivables)
                technicalCapabilityRow("Inventario", enabled: capabilityGate.canAccessInventory)
                technicalCapabilityRow("Comprobantes", enabled: canAccessElectronicDocumentVault)
                technicalCapabilityRow("Exportaciones", enabled: canAccessOperationalExports)
                technicalCapabilityRow("Equipo", enabled: canAccessTeamManagement)
            }
        }
    }

    @ViewBuilder
    private var restaurantTechnicalCard: some View {
        if context.verticals.restaurant != nil {
            BusinessCard(
                title: "Restaurante v1 técnico",
                subtitle: "Readiness, capabilities y checks de soporte. No ejecuta acciones operativas."
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    BusinessRestaurantReadinessFinalSection(
                        viewModel: BusinessRestaurantReadinessFinalViewModel(
                            organizationId: organizationId,
                            branchId: branchId,
                            repository: container.restaurantTablesRepository
                        )
                    )

                    if !restaurantEnabledCapabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capacidades técnicas")
                                .font(.subheadline.weight(.semibold))

                            LazyVGrid(columns: toolColumns, spacing: 8) {
                                ForEach(restaurantEnabledCapabilities, id: \.self) { capability in
                                    BusinessVerticalCompactPill(
                                        title: humanizedRestaurantCapability(capability),
                                        code: capability,
                                        systemImage: "checkmark.circle.fill",
                                        tint: .green
                                    )
                                }
                            }
                        }
                    }

                    if !context.verticals.readiness.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Readiness técnico")
                                .font(.subheadline.weight(.semibold))

                            ForEach(context.verticals.readiness) { check in
                                verticalReadinessRow(check)
                            }
                        }
                    }

                    if !context.verticals.foreignVerticalCodes.isEmpty {
                        BusinessInlineMessage(
                            message: "WARN técnico: aparecen verticales ajenos para esta organización: \(context.verticals.foreignVerticalCodes.joined(separator: ", ")).",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }
            }
        } else {
            BusinessCard(
                title: "Restaurante v1 técnico",
                subtitle: "No hay vertical Restaurante activo para esta operación."
            ) {
                BusinessInlineMessage(
                    message: "Sin diagnóstico de Restaurante v1 en esta sesión.",
                    systemImage: "fork.knife",
                    tint: .secondary
                )
            }
        }
    }

    private var verticalsCard: some View {
        BusinessCard(
            title: "Verticales activos",
            subtitle: "Paquetes verticales habilitados para esta organización."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if context.verticals.activeVerticals.isEmpty {
                    BusinessInlineMessage(
                        message: "Sin verticales activos.",
                        systemImage: "square.stack.3d.up",
                        tint: .secondary
                    )
                } else {
                    ForEach(context.verticals.activeVerticals) { vertical in
                        technicalCodeRow(
                            title: vertical.code,
                            value: "\(vertical.status) · v\(vertical.packageVersion)",
                            systemImage: "square.stack.3d.up",
                            tint: vertical.status.lowercased() == "active" ? .green : .orange
                        )
                    }
                }
            }
        }
    }

    private var modulesCard: some View {
        BusinessCard(
            title: "Módulos activos",
            subtitle: "Módulos técnicos recibidos desde el contexto del negocio."
        ) {
            if context.activeModules.isEmpty {
                BusinessInlineMessage(
                    message: "Sin módulos activos reportados.",
                    systemImage: "square.grid.2x2",
                    tint: .secondary
                )
            } else {
                LazyVGrid(columns: toolColumns, spacing: 8) {
                    ForEach(context.activeModules.map(\.rawValue).sorted(), id: \.self) { module in
                        technicalModulePill(module)
                    }
                }
            }
        }
    }

    private func technicalCapabilityRow(_ title: String, enabled: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "minus.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(enabled ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(enabled ? "Activo" : "No disponible")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(enabled ? Color.green : Color.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(10)
        .background((enabled ? Color.green : Color.secondary).opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder((enabled ? Color.green : Color.secondary).opacity(0.10))
        )
    }

    private func technicalCodeRow(
        title: String,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(.primary)

                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func technicalModulePill(_ module: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "square.grid.2x2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(module)
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.10))
        )
    }

    private func verticalReadinessRow(_ check: BusinessVerticalReadiness) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: verticalReadinessSystemImage(check.normalizedStatus))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(verticalReadinessTint(check.normalizedStatus))
                .frame(width: 28, height: 28)
                .background(verticalReadinessTint(check.normalizedStatus).opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(check.code)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.primary)

                    Spacer(minLength: 8)

                    Text(check.normalizedStatus)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(verticalReadinessTint(check.normalizedStatus))
                }

                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func humanizedRestaurantCapability(_ capability: String) -> String {
        switch capability {
        case "restaurant.menu_attributes":
            return "Atributos menú"
        case "restaurant.service_type":
            return "Tipo servicio"
        case "restaurant.event_service":
            return "Eventos"
        case "restaurant.tables_optional":
            return "Mesas"
        case "restaurant.kitchen_basic_optional":
            return "Cocina"
        default:
            return capability
                .replacingOccurrences(of: "restaurant.", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }

    private func verticalReadinessTint(_ status: String) -> Color {
        switch status {
        case "PASS":
            return .green
        case "WARN":
            return .orange
        case "FAIL":
            return .red
        default:
            return .secondary
        }
    }

    private func verticalReadinessSystemImage(_ status: String) -> String {
        switch status {
        case "PASS":
            return "checkmark.seal.fill"
        case "WARN":
            return "exclamationmark.triangle.fill"
        case "FAIL":
            return "xmark.octagon.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    private var toolColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ]
    }

    private var readinessTint: Color {
        switch context.readiness.status.lowercased() {
        case "ready", "ok", "active", "enabled":
            return .green
        case "warning", "partial", "pending", "warn":
            return .orange
        case "blocked", "error", "failed", "fail":
            return .red
        default:
            return .secondary
        }
    }

    private var capabilityGate: BusinessCapabilityGate {
        BusinessCapabilityGate(capabilities: context.capabilities)
    }

    private var permissionGate: PermissionGate {
        PermissionGate(effectivePermissions: context.effectivePermissions)
    }

    private var canAccessTeamManagement: Bool {
        permissionGate.allows("credentials.users.view") ||
        permissionGate.allows("credentials.roles.view") ||
        permissionGate.allows("credentials.users.create") ||
        permissionGate.allows("credentials.roles.manage")
    }

    private var canAccessElectronicDocumentVault: Bool {
        permissionGate.allows("documents.electronic_invoice.list") ||
        permissionGate.allows("documents.electronic_invoice.view") ||
        permissionGate.allows("documents.electronic_invoice.download_ride") ||
        permissionGate.allows("documents.electronic_invoice.download_xml") ||
        permissionGate.allows("documents.electronic_invoice.email") ||
        permissionGate.allows("documents.view") ||
        permissionGate.allows("business.documents.view")
    }

    private var canAccessOperationalExports: Bool {
        guard capabilityGate.canAccessToday || context.effectivePermissions.contains("*") else {
            return false
        }

        return permissionGate.allowsAny(Self.operationalExportPermissions) || context.effectivePermissions.contains("*")
    }

    private static let operationalExportPermissions = [
        "business.exports.view",
        "business.exports.generate",
        "business.exports.download",
        "exports.view",
        "exports.generate",
        "exports.download",
        "reports.export",
        "reports.dashboard.view",
        "reports.sales.view",
        "reports.cash.view",
        "reports.documents.view"
    ]

    private var organizationId: String {
        context.organization.id
    }

    private var branchId: String {
        operationalSelection.branchId
    }

    private var restaurantEnabledCapabilities: [String] {
        let packageCapabilities = context.verticals.restaurant?.capabilities ?? []
        return Array(Set(context.verticals.capabilities + packageCapabilities))
            .filter { $0.hasPrefix("restaurant.") }
            .sorted()
    }

    private var selectedBranchName: String {
        context.branches.first(where: { $0.id == operationalSelection.branchId })?.name
        ?? operationalSelection.branchId
    }

    private var selectedActivityName: String {
        context.activities.first(where: { $0.id == operationalSelection.activityId })?.name
        ?? operationalSelection.activityId
    }
}

private struct UnpaidSalesListView: View {
    @Bindable private var viewModel: UnpaidSalesListViewModel
    private let salesRepository: SalesRepository
    private let customersRepository: CustomersRepository
    private let catalogRepository: CatalogRepository?
    private let contextRepository: BusinessContextRepository?
    private let verticalContext: BusinessVerticalContext
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: UnpaidSalesListViewModel,
        salesRepository: SalesRepository,
        customersRepository: CustomersRepository = UnavailableCustomersRepository(),
        catalogRepository: CatalogRepository? = nil,
        contextRepository: BusinessContextRepository? = nil,
        verticalContext: BusinessVerticalContext = .empty,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.salesRepository = salesRepository
        self.customersRepository = customersRepository
        self.catalogRepository = catalogRepository
        self.contextRepository = contextRepository
        self.verticalContext = verticalContext
        self.salesHistoryRepository = salesHistoryRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
    }

    var body: some View {
        Form {
            Section("Qué aparece aquí") {
                Label("Ventas guardadas o parcialmente cobradas que todavía no son deuda formal.", systemImage: "bookmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Label("Las cuentas por cobrar reales están separadas en Por cobrar.", systemImage: "person.crop.circle.badge.clock")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Ventas pendientes") {
                if viewModel.isLoading && viewModel.sales.isEmpty {
                    ProgressView("Cargando ventas pendientes…")
                } else if viewModel.sales.isEmpty {
                    ContentUnavailableView(
                        "Sin ventas pendientes",
                        systemImage: "bookmark",
                        description: Text("Las ventas pausadas, guardadas o parcialmente cobradas sin cuenta por cobrar aparecerán aquí.")
                    )
                } else {
                    ForEach(viewModel.sales) { sale in
                        NavigationLink {
                            SaleDetailView(
                                viewModel: viewModel.makeSaleDetailViewModel(
                                    for: sale,
                                    salesRepository: salesRepository
                                ),
                                customersRepository: customersRepository,
                                catalogRepository: catalogRepository,
                                contextRepository: contextRepository,
                                verticalContext: verticalContext,
                                salesHistoryRepository: salesHistoryRepository,
                                cashRepository: cashRepository,
                                paymentsRepository: paymentsRepository,
                                receivablesRepository: receivablesRepository,
                                documentsRepository: documentsRepository
                            )
                        } label: {
                            UnpaidSaleRow(sale: sale)
                        }
                    }
                }
            }

            if let message = viewModel.errorMessage {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            if let message = viewModel.infoMessage {
                Section {
                    Label(message, systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ventas pendientes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task { await viewModel.loadIfNeeded() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct UnpaidSaleRow: View {
    let sale: BusinessSale

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Text(sale.displayCustomerName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(sale.totals.grandTotal.displayText)
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                BusinessPill(
                    title: sale.collectionState.shortName,
                    systemImage: sale.collectionState.systemImage,
                    tint: sale.collectionState == .partialWithoutReceivable ? .orange : .blue
                )

                if BusinessElectronicInvoiceCustomerPolicy.isFinalConsumer(sale: sale) {
                    BusinessPill(
                        title: "No es deuda",
                        systemImage: "checkmark.shield",
                        tint: .secondary
                    )
                }
            }

            if let createdAt = sale.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct BusinessVerticalCompactPill: View {
    let title: String
    let code: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)

            Text(code)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.10))
        )
    }
}

private struct BusinessHeroCard: View {
    let organizationName: String
    let subtitle: String
    let readiness: String
    let taxId: String
    let countryCode: String
    let readinessTint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                BusinessIconBadge(systemImage: "building.2.crop.circle.fill", tint: .accentColor)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Nexo Business")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(organizationName)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                BusinessPill(title: readiness, systemImage: "checkmark.seal", tint: readinessTint)
                BusinessPill(title: countryCode, systemImage: "globe.americas", tint: .accentColor)
            }

            HStack(spacing: 10) {
                Image(systemName: "number")
                    .foregroundStyle(Color.accentColor)

                Text("RUC")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                Text(taxId)
                    .font(.caption.monospaced().weight(.semibold))
                    .textSelection(.enabled)
            }
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct BusinessCard<Content: View>: View {
    private let title: String
    private let subtitle: String?
    private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

struct BusinessToolTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    var isDisabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            BusinessIconBadge(systemImage: systemImage, tint: isDisabled ? .secondary : tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isDisabled ? .secondary : .primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .padding(14)
        .background((isDisabled ? Color.secondary : tint).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder((isDisabled ? Color.secondary : tint).opacity(0.10))
        )
    }
}

private struct BusinessActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            BusinessIconBadge(systemImage: systemImage, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(tint.opacity(0.10))
        )
    }
}

private struct BusinessMetaRow: View {
    let title: String
    let value: String
    var isMonospaced: Bool = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .footnote.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessInlineMessage: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }
}


private struct BusinessRestaurantOperationalStatusCard: View {
    let workMode: String
    let hasTables: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                BusinessIconBadge(systemImage: "fork.knife", tint: .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Listo para operar")
                        .font(.subheadline.weight(.semibold))
                    Text("Vende y cobra desde Venta rápida. El restaurante usa el mismo flujo de caja, historial y documentos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Label("Venta rápida: crea productos, cobra y permite facturar.", systemImage: "cart.badge.plus")
                    .foregroundStyle(.primary)

                if hasTables {
                    Label("Mesas: control de ocupación; no crea venta ni orden por sí sola.", systemImage: "tablecells")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption.weight(.semibold))

            Text("Modo operativo: \(workMode)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessPill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

private struct BusinessIconBadge: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 42, height: 42)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

@MainActor
@Observable
final class BusinessRestaurantReadinessFinalViewModel {
    private(set) var readiness: BusinessRestaurantReadinessResponse?
    private(set) var isLoading = false
    var errorMessage: String?

    private let organizationId: String
    private let branchId: String
    private let repository: BusinessRestaurantTablesRepository
    private var hasLoaded = false

    init(
        organizationId: String,
        branchId: String,
        repository: BusinessRestaurantTablesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.repository = repository
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            readiness = try await repository.restaurantReadiness(
                organizationId: organizationId,
                branchId: branchId
            )
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BusinessRestaurantReadinessFinalSection: View {
    @State private var viewModel: BusinessRestaurantReadinessFinalViewModel

    init(viewModel: BusinessRestaurantReadinessFinalViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Label("Readiness final 22G", systemImage: "stethoscope")
                    .font(.subheadline.weight(.semibold))

                Spacer(minLength: 8)

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isLoading)
                .accessibilityLabel("Actualizar readiness restaurante")
            }

            if viewModel.isLoading && viewModel.readiness == nil {
                BusinessInlineMessage(
                    message: "Leyendo readiness consolidado de Restaurante v1…",
                    systemImage: "clock.arrow.circlepath",
                    tint: .secondary
                )
            } else if let readiness = viewModel.readiness {
                BusinessRestaurantReadinessSummaryView(readiness: readiness)

                if let tables = readiness.tables {
                    BusinessRestaurantReadinessTablesSummaryView(summary: tables)
                }

                if !readiness.blockers.isEmpty {
                    BusinessRestaurantReadinessMessageList(
                        title: "Blockers",
                        systemImage: "xmark.octagon.fill",
                        messages: readiness.blockers,
                        tint: .red
                    )
                }

                if !readiness.warnings.isEmpty {
                    BusinessRestaurantReadinessMessageList(
                        title: "Warnings",
                        systemImage: "exclamationmark.triangle.fill",
                        messages: readiness.warnings,
                        tint: .orange
                    )
                }

                if !readiness.checks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Checks")
                            .font(.subheadline.weight(.semibold))

                        ForEach(readiness.checks) { check in
                            BusinessRestaurantReadinessCheckRow(check: check)
                        }
                    }
                }

                if !readiness.components.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Componentes")
                            .font(.subheadline.weight(.semibold))

                        ForEach(readiness.components) { component in
                            BusinessRestaurantReadinessComponentRow(component: component)
                        }
                    }
                }
            } else if let errorMessage = viewModel.errorMessage {
                BusinessInlineMessage(
                    message: "No se pudo cargar readiness Restaurante v1: \(errorMessage)",
                    systemImage: "wifi.exclamationmark",
                    tint: .orange
                )
            } else {
                BusinessInlineMessage(
                    message: "Readiness Restaurante v1 pendiente de cargar.",
                    systemImage: "hourglass",
                    tint: .secondary
                )
            }
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

private struct BusinessRestaurantReadinessSummaryView: View {
    let readiness: BusinessRestaurantReadinessResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: readiness.overallStatus.readinessSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(readiness.overallStatus.readinessTint)
                    .frame(width: 34, height: 34)
                    .background(readiness.overallStatus.readinessTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Restaurante v1 \(readiness.overallStatus.readinessTitle.lowercased())")
                        .font(.subheadline.weight(.semibold))
                    Text(readiness.ready ? "Puede avanzar si no hay blockers. Warnings como mesas abiertas son operativos." : "No avanzar a smoke hasta resolver blockers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(readiness.overallStatus.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(readiness.overallStatus.readinessTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(readiness.overallStatus.readinessTint.opacity(0.12), in: Capsule())
            }

            Label("Diagnóstico únicamente: vender, cobrar, facturar y operar mesas viven en sus pantallas normales.", systemImage: "eye")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if !readiness.capabilities.isEmpty {
                Text("Capabilities: \(readiness.capabilities.joined(separator: ", "))")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BusinessRestaurantReadinessTablesSummaryView: View {
    let summary: RestaurantTableReadinessSummary

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            BusinessRestaurantReadinessMetric(title: "Total", value: summary.total, systemImage: "square.grid.2x2", tint: .secondary)
            BusinessRestaurantReadinessMetric(title: "Libres", value: summary.available, systemImage: "checkmark.circle.fill", tint: .green)
            BusinessRestaurantReadinessMetric(title: "Ocupadas", value: summary.occupied, systemImage: "person.2.fill", tint: .orange)
            BusinessRestaurantReadinessMetric(title: "Abiertas", value: summary.openSessions, systemImage: "clock.fill", tint: .blue)
        }
    }
}

private struct BusinessRestaurantReadinessMetric: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessRestaurantReadinessCheckRow: View {
    let check: BusinessRestaurantReadinessCheck

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: check.status.readinessSystemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(check.status.readinessTint)
                .frame(width: 28, height: 28)
                .background(check.status.readinessTint.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(check.code.restaurantReadableCode)
                        .font(.caption.monospaced().weight(.semibold))
                    Spacer(minLength: 8)
                    if check.blocking {
                        Text("Bloqueante")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                }

                Text(check.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !check.details.isEmpty {
                    Text(check.details.map { "\($0.key): \($0.value)" }.sorted().joined(separator: " • "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessRestaurantReadinessComponentRow: View {
    let component: BusinessRestaurantReadinessComponent

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(component.code.restaurantReadableCode)
                    .font(.caption.monospaced().weight(.semibold))
                Spacer(minLength: 8)
                Text(component.status.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(component.status.readinessTint)
            }

            if let path = component.path, !path.isEmpty {
                Text(path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if component.supportOnly {
                Label("Solo soporte", systemImage: "eye")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct BusinessRestaurantReadinessMessageList: View {
    let title: String
    let systemImage: String
    let messages: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            ForEach(messages, id: \.self) { message in
                Text("• \(message.restaurantReadableCode)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension String {
    var normalizedRestaurantReadinessStatus: String {
        trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var readinessTitle: String {
        switch normalizedRestaurantReadinessStatus {
        case "PASS", "READY": return "Listo"
        case "WARN", "WARNING": return "Con advertencias"
        case "FAIL", "BLOCKED": return "Bloqueado"
        default: return "Desconocido"
        }
    }

    var readinessTint: Color {
        switch normalizedRestaurantReadinessStatus {
        case "PASS", "READY": return .green
        case "WARN", "WARNING": return .orange
        case "FAIL", "BLOCKED": return .red
        default: return .secondary
        }
    }

    var readinessSystemImage: String {
        switch normalizedRestaurantReadinessStatus {
        case "PASS", "READY": return "checkmark.seal.fill"
        case "WARN", "WARNING": return "exclamationmark.triangle.fill"
        case "FAIL", "BLOCKED": return "xmark.octagon.fill"
        default: return "questionmark.circle.fill"
        }
    }

    var restaurantReadableCode: String {
        replacingOccurrences(of: "restaurant_", with: "")
            .replacingOccurrences(of: "restaurant.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}

@MainActor
@Observable
final class RestaurantTablesViewModel {
    private(set) var tables: [RestaurantTableReadiness] = []
    private(set) var summary = RestaurantTableReadinessSummary(
        total: 0,
        available: 0,
        occupied: 0,
        disabled: 0,
        openSessions: 0
    )
    private(set) var isLoading = false
    private(set) var isMutating = false
    var errorMessage: String?
    var infoMessage: String?

    private let organizationId: String
    private let branchId: String
    private let effectivePermissions: Set<String>
    private let repository: BusinessRestaurantTablesRepository
    private var hasLoaded = false

    init(
        organizationId: String,
        branchId: String,
        effectivePermissions: Set<String>,
        repository: BusinessRestaurantTablesRepository
    ) {
        self.organizationId = organizationId
        self.branchId = branchId
        self.effectivePermissions = effectivePermissions
        self.repository = repository
    }

    var canViewTables: Bool {
        permissionGate.allows("tables.view") || permissionGate.allows("tables.manage")
    }

    var canManageTables: Bool {
        permissionGate.allows("tables.manage")
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    func refresh() async {
        guard canViewTables else {
            tables = []
            summary = .empty
            errorMessage = "No tienes permiso para consultar mesas."
            hasLoaded = true
            return
        }

        isLoading = true
        errorMessage = nil
        defer {
            isLoading = false
            hasLoaded = true
        }

        do {
            let response = try await repository.readiness(
                organizationId: organizationId,
                branchId: branchId
            )
            apply(response)
            if response.tables.isEmpty && infoMessage == nil {
                infoMessage = "No hay mesas configuradas para esta sucursal."
            }
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func open(_ table: RestaurantTableReadiness) async {
        guard canManageTables else {
            errorMessage = "No tienes permiso para marcar mesas ocupadas."
            return
        }
        guard table.canOpen else {
            errorMessage = table.reasonIfBlocked ?? "Esta mesa no puede marcarse ocupada ahora."
            return
        }

        await mutate(successMessage: "Mesa \(table.displayCode) marcada como ocupada.") {
            _ = try await repository.openSession(
                organizationId: organizationId,
                branchId: branchId,
                idempotencyKey: .generate(prefix: "business-table-open"),
                request: OpenRestaurantTableSessionRequest(
                    tableId: table.tableId,
                    saleId: nil,
                    notes: "Marcada ocupada desde Business iOS"
                )
            )
        }
    }

    func close(_ table: RestaurantTableReadiness) async {
        guard canManageTables else {
            errorMessage = "No tienes permiso para liberar mesas."
            return
        }
        guard table.canClose, let sessionId = table.activeSessionId else {
            errorMessage = table.reasonIfBlocked ?? "Esta mesa no tiene ocupación activa para liberar."
            return
        }

        await mutate(successMessage: "Mesa \(table.displayCode) liberada.") {
            _ = try await repository.closeSession(
                organizationId: organizationId,
                branchId: branchId,
                sessionId: sessionId,
                idempotencyKey: .generate(prefix: "business-table-close")
            )
        }
    }

    func cancel(_ table: RestaurantTableReadiness, reason: String) async {
        guard canManageTables else {
            errorMessage = "No tienes permiso para cancelar ocupaciones de mesa."
            return
        }
        guard table.canCancel, let sessionId = table.activeSessionId else {
            errorMessage = table.reasonIfBlocked ?? "Esta mesa no tiene ocupación activa para cancelar."
            return
        }

        let cleanReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanReason.isEmpty else {
            errorMessage = "Ingresa un motivo para cancelar la ocupación."
            return
        }

        await mutate(successMessage: "Ocupación de \(table.displayCode) cancelada.") {
            _ = try await repository.cancelSession(
                organizationId: organizationId,
                branchId: branchId,
                sessionId: sessionId,
                idempotencyKey: .generate(prefix: "business-table-cancel"),
                request: CancelRestaurantTableSessionRequest(reason: cleanReason)
            )
        }
    }

    private func mutate(
        successMessage: String,
        operation: () async throws -> Void
    ) async {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        infoMessage = nil
        defer { isMutating = false }

        do {
            try await operation()
            await refresh()
            infoMessage = successMessage
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ response: RestaurantTableReadinessEnvelopeResponse) {
        tables = response.tables.sorted { lhs, rhs in
            if lhs.statusSortOrder != rhs.statusSortOrder {
                return lhs.statusSortOrder < rhs.statusSortOrder
            }
            return lhs.displayCode.localizedStandardCompare(rhs.displayCode) == .orderedAscending
        }
        summary = response.summary
    }

    private var permissionGate: PermissionGate {
        PermissionGate(effectivePermissions: effectivePermissions)
    }
}

struct RestaurantTablesView: View {
    @State private var viewModel: RestaurantTablesViewModel
    @State private var closeCandidate: RestaurantTableReadiness?
    @State private var cancelCandidate: RestaurantTableReadiness?

    init(viewModel: RestaurantTablesViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                headerCard
                messageSection
                summarySection
                contentSection
            }
            .padding(.horizontal, 11)
            .padding(.top, 11)
            .padding(.bottom, 34)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mesas")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(viewModel.isLoading || viewModel.isMutating)
                .accessibilityLabel("Actualizar mesas")
            }
        }
        .refreshable { await viewModel.refresh() }
        .task { await viewModel.loadIfNeeded() }
        .alert(
            alertTitle,
            isPresented: alertBinding
        ) {
            Button("OK") {
                viewModel.errorMessage = nil
                viewModel.infoMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? viewModel.infoMessage ?? "")
        }
        .confirmationDialog("Liberar mesa", isPresented: closeBinding, titleVisibility: .visible) {
            if let closeCandidate {
                Button("Liberar \(closeCandidate.displayName)") {
                    Task { await viewModel.close(closeCandidate) }
                }
                .disabled(viewModel.isMutating)
            }
            Button("Cancelar", role: .cancel) { closeCandidate = nil }
        } message: {
            Text("La mesa volverá a disponible. Esto no cobra, factura ni modifica ventas.")
        }
        .confirmationDialog("Cancelar ocupación", isPresented: cancelBinding, titleVisibility: .visible) {
            if let cancelCandidate {
                Button("Cancelar ocupación de \(cancelCandidate.displayName)", role: .destructive) {
                    Task {
                        await viewModel.cancel(
                            cancelCandidate,
                            reason: "Ocupación cancelada desde Business iOS"
                        )
                    }
                }
                .disabled(viewModel.isMutating)
            }
            Button("Volver", role: .cancel) { cancelCandidate = nil }
        } message: {
            Text("Usa esta acción solo si la mesa se marcó ocupada por error. No toca caja, factura ni historial.")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "tablecells")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 46, height: 46)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Mesas opcionales")
                        .font(.title3.weight(.bold))
                    Text("Controla si una mesa está libre u ocupada. No crea venta, pedido, cobro ni factura por sí sola.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label("Para cobrar o facturar, entra por Venta rápida o Historial.", systemImage: "checkmark.seal.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }

    @ViewBuilder
    private var messageSection: some View {
        if viewModel.isMutating {
            RestaurantTablesInlineMessage(
                message: "Actualizando ocupación de mesa…",
                systemImage: "clock.arrow.circlepath",
                tint: .secondary
            )
        }

        if let infoMessage = viewModel.infoMessage {
            RestaurantTablesInlineMessage(
                message: infoMessage,
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
        }

        if !viewModel.canManageTables {
            RestaurantTablesInlineMessage(
                message: "Puedes consultar mesas, pero tu usuario no puede cambiar ocupación.",
                systemImage: "lock",
                tint: .orange
            )
        }
    }

    private var summarySection: some View {
        LazyVGrid(columns: summaryColumns, spacing: 10) {
            RestaurantTableSummaryTile(title: "Total", value: viewModel.summary.total, systemImage: "square.grid.2x2", tint: .secondary)
            RestaurantTableSummaryTile(title: "Disponibles", value: viewModel.summary.available, systemImage: "checkmark.circle.fill", tint: .green)
            RestaurantTableSummaryTile(title: "Ocupadas", value: viewModel.summary.occupied, systemImage: "person.2.fill", tint: .orange)
            RestaurantTableSummaryTile(title: "Abiertas", value: viewModel.summary.openSessions, systemImage: "clock.fill", tint: .blue)
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        if viewModel.isLoading && viewModel.tables.isEmpty {
            RestaurantTablesLoadingCard()
        } else if viewModel.tables.isEmpty {
            RestaurantTablesEmptyCard()
        } else {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.tables) { table in
                    RestaurantTableReadinessCard(
                        table: table,
                        canManage: viewModel.canManageTables,
                        isMutating: viewModel.isMutating,
                        onOpen: {
                            Task { await viewModel.open(table) }
                        },
                        onClose: {
                            closeCandidate = table
                        },
                        onCancel: {
                            cancelCandidate = table
                        }
                    )
                }
            }
        }
    }

    private var alertTitle: String {
        "No se pudo completar"
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var closeBinding: Binding<Bool> {
        Binding(
            get: { closeCandidate != nil },
            set: { if !$0 { closeCandidate = nil } }
        )
    }

    private var cancelBinding: Binding<Bool> {
        Binding(
            get: { cancelCandidate != nil },
            set: { if !$0 { cancelCandidate = nil } }
        )
    }

    private var summaryColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ]
    }
}

private struct RestaurantTableReadinessCard: View {
    let table: RestaurantTableReadiness
    let canManage: Bool
    let isMutating: Bool
    let onOpen: () -> Void
    let onClose: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: table.statusSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(table.statusTint)
                    .frame(width: 44, height: 44)
                    .background(table.statusTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(table.displayName)
                            .font(.headline)
                            .lineLimit(1)

                        Text(table.displayCode)
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(.secondary)
                    }

                    Text(table.displaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(table.displayStatus)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(table.statusTint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(table.statusTint.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 8) {
                if let sessionId = table.activeSessionId, !sessionId.isEmpty {
                    Label("Ocupación: \(sessionId)", systemImage: "clock")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let saleId = table.linkedSaleId, !saleId.isEmpty {
                    Label("Venta vinculada: \(saleId)", systemImage: "cart")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let reason = table.reasonIfBlocked, !reason.isEmpty {
                    Label(reason, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            actionRow
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(table.statusTint.opacity(0.12))
        )
    }

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 10) {
            if table.canOpen {
                Button {
                    onOpen()
                } label: {
                    Label("Marcar ocupada", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canManage || isMutating)
            }

            if table.canClose {
                Button {
                    onClose()
                } label: {
                    Label("Liberar", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || isMutating)
            }

            if table.canCancel {
                Button(role: .destructive) {
                    onCancel()
                } label: {
                    Label("Cancelar ocupación", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(!canManage || isMutating)
            }

            if !table.canOpen && !table.canClose && !table.canCancel {
                Label("Sin acciones", systemImage: "minus.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .controlSize(.regular)
    }
}

private struct RestaurantTableSummaryTile: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct RestaurantTablesInlineMessage: View {
    let message: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RestaurantTablesLoadingCard: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Cargando mesas…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RestaurantTablesEmptyCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells.badge.ellipsis")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No hay mesas configuradas")
                .font(.headline)
            Text("Crea mesas desde backend/Admin readiness antes de usar esta pantalla en operación real.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private extension RestaurantTableReadinessSummary {
    static let empty = RestaurantTableReadinessSummary(
        total: 0,
        available: 0,
        occupied: 0,
        disabled: 0,
        openSessions: 0
    )
}

private extension RestaurantTableReadiness {
    var normalizedStatusForUI: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var statusSortOrder: Int {
        switch normalizedStatusForUI {
        case "occupied":
            return 0
        case "available":
            return 1
        case "disabled":
            return 2
        default:
            return 3
        }
    }

    var displayCode: String {
        let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanCode.isEmpty ? tableId : cleanCode
    }

    var displayName: String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleanName.isEmpty ? displayCode : cleanName
    }

    var displaySubtitle: String {
        var parts: [String] = []
        if let area = area?.trimmingCharacters(in: .whitespacesAndNewlines), !area.isEmpty {
            parts.append(area)
        }
        if let capacity, capacity > 0 {
            parts.append("\(capacity) personas")
        }
        if parts.isEmpty {
            return "Mesa operativa"
        }
        return parts.joined(separator: " · ")
    }

    var displayStatus: String {
        switch normalizedStatusForUI {
        case "available":
            return "Disponible"
        case "occupied":
            return "Ocupada"
        case "disabled":
            return "Deshabilitada"
        default:
            return status.capitalized
        }
    }

    var statusSystemImage: String {
        switch normalizedStatusForUI {
        case "available":
            return "checkmark.circle.fill"
        case "occupied":
            return "person.2.fill"
        case "disabled":
            return "nosign"
        default:
            return "questionmark.circle.fill"
        }
    }

    var statusTint: Color {
        switch normalizedStatusForUI {
        case "available":
            return .green
        case "occupied":
            return .orange
        case "disabled":
            return .secondary
        default:
            return .blue
        }
    }
}

