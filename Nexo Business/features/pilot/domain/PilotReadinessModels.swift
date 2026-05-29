//
//  PilotReadinessModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum PilotReadinessSeverity: String, Codable, CaseIterable, Sendable {
    case blocker
    case warning
    case info

    public var displayName: String {
        switch self {
        case .blocker:
            return "Bloqueante"
        case .warning:
            return "Advertencia"
        case .info:
            return "Informativo"
        }
    }
}

public enum PilotChecklistCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case access
    case operation
    case cash
    case sales
    case payments
    case documents
    case customers
    case inventory
    case closing
    case support

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .access:
            return "Acceso"
        case .operation:
            return "Operación"
        case .cash:
            return "Caja"
        case .sales:
            return "Ventas"
        case .payments:
            return "Cobros"
        case .documents:
            return "Comprobantes"
        case .customers:
            return "Clientes"
        case .inventory:
            return "Inventario"
        case .closing:
            return "Cierre diario"
        case .support:
            return "Soporte"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .access:
            return 0
        case .operation:
            return 1
        case .cash:
            return 2
        case .sales:
            return 3
        case .payments:
            return 4
        case .documents:
            return 5
        case .customers:
            return 6
        case .inventory:
            return 7
        case .closing:
            return 8
        case .support:
            return 9
        }
    }
}

public struct PilotChecklistItem: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let category: PilotChecklistCategory
    public let title: String
    public let detail: String
    public let severity: PilotReadinessSeverity
    public let isRequired: Bool
    public var isDone: Bool
    public var updatedAt: Date?

    public init(
        id: String,
        category: PilotChecklistCategory,
        title: String,
        detail: String,
        severity: PilotReadinessSeverity,
        isRequired: Bool,
        isDone: Bool = false,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.detail = detail
        self.severity = severity
        self.isRequired = isRequired
        self.isDone = isDone
        self.updatedAt = updatedAt
    }
}

public struct PilotReadinessIssue: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let severity: PilotReadinessSeverity

    public init(
        id: String,
        title: String,
        detail: String,
        severity: PilotReadinessSeverity
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
    }
}

public struct PilotReadinessSnapshot: Equatable, Sendable {
    public let score: Int
    public let completedRequired: Int
    public let totalRequired: Int
    public let completedOptional: Int
    public let totalOptional: Int
    public let blockers: [PilotReadinessIssue]
    public let warnings: [PilotReadinessIssue]

    public init(
        score: Int,
        completedRequired: Int,
        totalRequired: Int,
        completedOptional: Int,
        totalOptional: Int,
        blockers: [PilotReadinessIssue],
        warnings: [PilotReadinessIssue]
    ) {
        self.score = score
        self.completedRequired = completedRequired
        self.totalRequired = totalRequired
        self.completedOptional = completedOptional
        self.totalOptional = totalOptional
        self.blockers = blockers
        self.warnings = warnings
    }

    public var isReadyForPilot: Bool {
        blockers.isEmpty && score >= 90
    }

    public var statusTitle: String {
        if isReadyForPilot {
            return "Listo para piloto"
        }

        if !blockers.isEmpty {
            return "Faltan bloqueantes"
        }

        return "Casi listo"
    }
}

public enum PilotChecklistFactory {
    public static func defaultItems() -> [PilotChecklistItem] {
        [
            PilotChecklistItem(
                id: "session_restore_verified",
                category: .access,
                title: "Sesión restaura correctamente",
                detail: "Cerrar y abrir la app mantiene sesión válida o vuelve a login si el token expiró.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "organization_selection_verified",
                category: .access,
                title: "Negocio, sucursal y actividad seleccionados",
                detail: "La operación usa selección real, no org_altos ni branches.first/activities.first.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "permissions_modules_verified",
                category: .operation,
                title: "Módulos y permisos aplicados",
                detail: "La app oculta acciones no permitidas y muestra mensajes humanos cuando falta permiso.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "cash_open_close_smoke",
                category: .cash,
                title: "Caja abre, mueve y cierra",
                detail: "Abrir caja, registrar ingreso/egreso/ajuste y cerrar sin duplicados.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "catalog_cart_preview_smoke",
                category: .sales,
                title: "Catálogo, carrito y preview validan",
                detail: "Buscar producto, agregar al carrito, previsualizar y manejar 409/428 actualizando contexto.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "quick_sale_confirm_smoke",
                category: .sales,
                title: "Venta rápida se crea y confirma",
                detail: "Crear venta con Idempotency-Key, abrir detalle y confirmar sin doble tap.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "payment_cash_transfer_card_smoke",
                category: .payments,
                title: "Cobros básicos verificados",
                detail: "Cobrar en efectivo con caja abierta, transferencia/tarjeta con referencia y evitar doble cobro.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "receivables_smoke",
                category: .payments,
                title: "Cuenta por cobrar y abono verificados",
                detail: "Crear crédito con cliente identificado y registrar abono con idempotencia.",
                severity: .warning,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "documents_smoke",
                category: .documents,
                title: "Comprobantes permitidos verificados",
                detail: "Generar ticket interno y registrar nota de venta física. No activar factura electrónica fuerte desde app.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "customers_smoke",
                category: .customers,
                title: "Clientes operativos verificados",
                detail: "Buscar/crear cliente, usar consumidor final y seleccionar cliente para venta/crédito.",
                severity: .warning,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "inventory_smoke",
                category: .inventory,
                title: "Inventario básico verificado",
                detail: "Consultar stock, filtrar bajo/sin stock y ajustar con motivo obligatorio.",
                severity: .warning,
                isRequired: false
            ),
            PilotChecklistItem(
                id: "pending_daily_closing_smoke",
                category: .closing,
                title: "Pendientes y cierre diario verificados",
                detail: "Revisar ventas pendientes, cuentas por cobrar, comprobantes pendientes y reporte diario.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "history_search_smoke",
                category: .closing,
                title: "Historial y búsqueda verificados",
                detail: "Buscar ventas por texto, fecha y estado, y abrir detalle operativo.",
                severity: .warning,
                isRequired: false
            ),
            PilotChecklistItem(
                id: "hardening_smoke",
                category: .support,
                title: "Hardening operativo verificado",
                detail: "Retry controlado, diagnóstico operativo, logs sanitizados y errores humanos.",
                severity: .blocker,
                isRequired: true
            ),
            PilotChecklistItem(
                id: "testflight_device_smoke",
                category: .support,
                title: "TestFlight en iPhone físico verificado",
                detail: "Instalar build, iniciar sesión, operar flujo mínimo y confirmar que staging responde.",
                severity: .blocker,
                isRequired: true
            )
        ]
    }
}
