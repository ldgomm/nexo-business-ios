import SwiftUI

// NEXO_23F_BUSINESS_ENTRYPOINTS
// NEXO 23F — BUSINESS ENTRYPOINTS
// Business-side Support entrypoint definitions.
// Scope: safe, local, presentation-only entrypoints for future ticket creation.
// Non-goals: no networking, no routes, no realtime, no push notifications, no documentos fiscales, no billing, no critical actions.

enum BusinessSupportEntryPointKind: String, CaseIterable, Identifiable, Equatable {
    case operation
    case sale
    case cash
    case document
    case product
    case customer
    case permission
    case restaurant
    case export
    case readiness

    var id: String { rawValue }

    var title: String {
        switch self {
        case .operation: return "Ayuda operativa"
        case .sale: return "Ayuda con venta"
        case .cash: return "Ayuda con caja"
        case .document: return "Ayuda con documento"
        case .product: return "Ayuda con producto"
        case .customer: return "Ayuda con cliente"
        case .permission: return "Ayuda con permisos"
        case .restaurant: return "Ayuda restaurante"
        case .export: return "Ayuda con exportaciones"
        case .readiness: return "Diagnóstico y readiness"
        }
    }

    var subtitle: String {
        switch self {
        case .operation:
            return "Pedir soporte sin tocar ventas, caja ni documentos."
        case .sale:
            return "Adjunta solo referencia sanitizada de venta cuando el backend lo permita."
        case .cash:
            return "Describe descuadres o dudas de caja sin registrar cobros."
        case .document:
            return "Reporta estados o errores sin ejecutar operación fiscal ni alterar documentos."
        case .product:
            return "Consulta catálogo o producto sin modificar inventario."
        case .customer:
            return "Reporta dudas del cliente con datos mínimos y seguros."
        case .permission:
            return "Pide revisión de acceso sin cambiar roles desde Business."
        case .restaurant:
            return "Reporta operación de mesas/restaurante solo como diagnóstico operativo."
        case .export:
            return "Pide ayuda con reportes/exportaciones sin recalcular datos."
        case .readiness:
            return "Comparte diagnóstico visible, sanitizado y auditado."
        }
    }

    var systemImage: String {
        switch self {
        case .operation: return "questionmark.circle"
        case .sale: return "cart"
        case .cash: return "banknote"
        case .document: return "doc.text"
        case .product: return "shippingbox"
        case .customer: return "person.text.rectangle"
        case .permission: return "lock.shield"
        case .restaurant: return "fork.knife"
        case .export: return "square.and.arrow.up"
        case .readiness: return "checkmark.seal"
        }
    }

    var contextType: String {
        switch self {
        case .operation: return "OPERATION"
        case .sale: return "SALE"
        case .cash: return "CASH_SESSION"
        case .document: return "ELECTRONIC_DOCUMENT"
        case .product: return "PRODUCT"
        case .customer: return "CUSTOMER"
        case .permission: return "PERMISSION"
        case .restaurant: return "RESTAURANT_TABLE"
        case .export: return "EXPORT"
        case .readiness: return "READINESS_CHECK"
        }
    }

    var safeReasonTemplate: String {
        "Solicitud de soporte Business desde \(title). Contexto mínimo: \(contextType)."
    }
}

struct BusinessSupportEntryPoint: Identifiable, Equatable {
    let id: String
    let kind: BusinessSupportEntryPointKind
    let screenName: String
    let entityRefId: String?
    let statusLabel: String?

    init(
        kind: BusinessSupportEntryPointKind,
        screenName: String,
        entityRefId: String? = nil,
        statusLabel: String? = nil
    ) {
        self.kind = kind
        self.screenName = screenName
        self.entityRefId = entityRefId
        self.statusLabel = statusLabel
        self.id = [kind.rawValue, screenName, entityRefId, statusLabel]
            .compactMap { $0 }
            .joined(separator: "|")
    }
}

struct BusinessSupportEntryPointsView: View {
    let title: String
    let entryPoints: [BusinessSupportEntryPoint]
    let onSelect: (BusinessSupportEntryPoint) -> Void

    init(
        title: String = "Soporte Nexo",
        entryPoints: [BusinessSupportEntryPoint] = BusinessSupportEntryPointsCatalog.defaultEntryPoints,
        onSelect: @escaping (BusinessSupportEntryPoint) -> Void = { _ in }
    ) {
        self.title = title
        self.entryPoints = entryPoints
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text("Pide ayuda con contexto mínimo y sanitizado. no cobra, no factura, no agenda, no cambia permisos y no ejecuta acciones críticas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(entryPoints) { entryPoint in
                BusinessSupportEntryPointCard(entryPoint: entryPoint) {
                    onSelect(entryPoint)
                }
            }
        }
        .accessibilityIdentifier("business_support_entrypoints")
    }
}

private struct BusinessSupportEntryPointCard: View {
    let entryPoint: BusinessSupportEntryPoint
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entryPoint.kind.systemImage)
                    .font(.title3)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entryPoint.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Text(entryPoint.kind.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let statusLabel = entryPoint.statusLabel, !statusLabel.isEmpty {
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("business_support_entrypoint_\(entryPoint.kind.rawValue)")
    }
}

enum BusinessSupportEntryPointsCatalog {
    static let defaultEntryPoints: [BusinessSupportEntryPoint] = [
        BusinessSupportEntryPoint(kind: .operation, screenName: "business_home"),
        BusinessSupportEntryPoint(kind: .sale, screenName: "business_sales"),
        BusinessSupportEntryPoint(kind: .cash, screenName: "business_cash"),
        BusinessSupportEntryPoint(kind: .document, screenName: "business_documents"),
        BusinessSupportEntryPoint(kind: .product, screenName: "business_products"),
        BusinessSupportEntryPoint(kind: .customer, screenName: "business_customers"),
        BusinessSupportEntryPoint(kind: .permission, screenName: "business_permissions"),
        BusinessSupportEntryPoint(kind: .restaurant, screenName: "business_restaurant"),
        BusinessSupportEntryPoint(kind: .export, screenName: "business_exports"),
        BusinessSupportEntryPoint(kind: .readiness, screenName: "business_readiness"),
    ]
}

#Preview("Business support entrypoints") {
    BusinessSupportEntryPointsView()
        .padding()
}
