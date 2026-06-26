//
//  BusinessView.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI
import Foundation

struct BusinessView: View {
    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let container: BusinessAppContainer
    private let onRefresh: () -> Void
    private let onChangeOrganization: () -> Void
    private let onChangeOperation: () -> Void
    private let onLogout: () -> Void

    @State private var isLogoutConfirmationPresented = false

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
                    diagnosticsCard
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
                subtitle: "22C consume el contexto vertical sin cambiar venta, caja, documentos ni catálogo."
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

                    BusinessInlineMessage(
                        message: "Venta rápida sigue siendo el flujo principal. Tipo de servicio entra en 22E; mesas y cocina quedan para 22F/22G.",
                        systemImage: "info.circle",
                        tint: .secondary
                    )

                    if !restaurantEnabledCapabilities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Capabilities activas")
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
                            Text("Readiness vertical")
                                .font(.subheadline.weight(.semibold))

                            ForEach(context.verticals.readiness) { check in
                                verticalReadinessRow(check)
                            }
                        }
                    }

                    if !context.verticals.foreignVerticalCodes.isEmpty {
                        BusinessInlineMessage(
                            message: "WARN: aparecen verticales ajenos para esta organización: \(context.verticals.foreignVerticalCodes.joined(separator: ", ")).",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        )
                    }
                }
            }
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
                            tint: .indigo
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

    private var diagnosticsCard: some View {
        BusinessCard(
            title: "Estado técnico",
            subtitle: "Permisos, módulos y capacidades activas."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup {
                    VStack(spacing: 8) {
                        capabilityDiagnosticRow("Ventas", enabled: capabilityGate.canAccessSales)
                        capabilityDiagnosticRow("Hoy", enabled: capabilityGate.canAccessToday)
                        capabilityDiagnosticRow("Caja", enabled: capabilityGate.canAccessCash)
                        capabilityDiagnosticRow("Historial", enabled: capabilityGate.canAccessHistory)
                        capabilityDiagnosticRow("Ventas pendientes", enabled: capabilityGate.canAccessHistory)
                        capabilityDiagnosticRow("Clientes", enabled: capabilityGate.canAccessCustomers)
                        capabilityDiagnosticRow("Cuentas por cobrar", enabled: capabilityGate.canAccessReceivables)
                        capabilityDiagnosticRow("Inventario", enabled: capabilityGate.canAccessInventory)
                        capabilityDiagnosticRow("Comprobantes", enabled: canAccessElectronicDocumentVault)
                        capabilityDiagnosticRow("Exportaciones", enabled: canAccessOperationalExports)
                        capabilityDiagnosticRow("Equipo", enabled: canAccessTeamManagement)
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Capacidades de negocio", systemImage: "switch.2")
                        .font(.subheadline.weight(.semibold))
                }

                Divider()

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        if context.verticals.activeVerticals.isEmpty {
                            Text("Sin verticales activos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(context.verticals.activeVerticals) { vertical in
                                Text("\(vertical.code) · \(vertical.status) · v\(vertical.packageVersion)")
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Verticales activos", systemImage: "square.stack.3d.up")
                        .font(.subheadline.weight(.semibold))
                }

                Divider()

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(context.activeModules.map(\.rawValue).sorted(), id: \.self) { module in
                            Text(module)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("Módulos activos", systemImage: "square.grid.2x2")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var accountCard: some View {
        BusinessCard(
            title: "Cuenta",
            subtitle: "Sesión, negocio activo y seguridad."
        ) {
            VStack(spacing: 10) {
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
            Menu {
                Button {
                    onRefresh()
                } label: {
                    Label("Actualizar datos", systemImage: "arrow.clockwise")
                }

                Button {
                    onChangeOperation()
                } label: {
                    Label("Cambiar operación", systemImage: "slider.horizontal.3")
                }

                Button {
                    onChangeOrganization()
                } label: {
                    Label("Cambiar negocio", systemImage: "building.2")
                }

                Button(role: .destructive) {
                    isLogoutConfirmationPresented = true
                } label: {
                    Label("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
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

private struct UnpaidSalesListView: View {
    @Bindable private var viewModel: UnpaidSalesListViewModel
    private let salesRepository: SalesRepository
    private let salesHistoryRepository: SalesHistoryRepository
    private let cashRepository: CashRepository
    private let paymentsRepository: PaymentsRepository
    private let receivablesRepository: ReceivablesRepository
    private let documentsRepository: BusinessDocumentsRepository

    init(
        viewModel: UnpaidSalesListViewModel,
        salesRepository: SalesRepository,
        salesHistoryRepository: SalesHistoryRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository
    ) {
        self.viewModel = viewModel
        self.salesRepository = salesRepository
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
                    Color.accentColor.opacity(0.16),
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
