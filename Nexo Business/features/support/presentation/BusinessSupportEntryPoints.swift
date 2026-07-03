import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#endif
import Observation

enum BusinessSupportEntryPointKind: String, CaseIterable, Identifiable, Equatable {
    case operation
    case sale
    case cash
    case document
    case product
    case customer
    case permission
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
        case .export: return "Ayuda con exportaciones"
        case .readiness: return "Diagnóstico y readiness"
        }
    }

    var shortTitle: String {
        switch self {
        case .operation: return "Operación"
        case .sale: return "Venta"
        case .cash: return "Caja"
        case .document: return "Documento"
        case .product: return "Producto"
        case .customer: return "Cliente"
        case .permission: return "Permisos"
        case .export: return "Exportaciones"
        case .readiness: return "Readiness"
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
        case .export: return "square.and.arrow.up"
        case .readiness: return "checkmark.seal"
        }
    }

    var tint: Color {
        switch self {
        case .operation: return .blue
        case .sale: return .accentColor
        case .cash: return .green
        case .document: return .cyan
        case .product: return .orange
        case .customer: return .purple
        case .permission: return .pink
        case .export: return .teal
        case .readiness: return .indigo
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

struct BusinessSupportHomeRow: View {
    let unreadCount: Int
    let latestTitle: String?
    let latestSummary: String?

    private var hasUnread: Bool { unreadCount > 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: hasUnread ? "bell.badge.fill" : "lifepreserver")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(hasUnread ? Color.orange : Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background((hasUnread ? Color.orange : Color.accentColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                if hasUnread {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .offset(x: 8, y: -7)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(hasUnread ? "Soporte Nexo · novedades" : "Soporte Nexo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .background((hasUnread ? Color.orange : Color.accentColor).opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder((hasUnread ? Color.orange : Color.accentColor).opacity(0.10))
        )
        .accessibilityIdentifier("business_support_home_row")
    }

    private var summaryText: String {
        if let title = latestTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let summary = latestSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                return "\(title) · \(summary)"
            }
            return title
        }
        return "Ayuda y diagnóstico seguro. No vende, no cobra, no factura y no cambia permisos."
    }
}

struct BusinessSupportEntryPointsView: View {
    let title: String
    let entryPoints: [BusinessSupportEntryPoint]
    let notificationUnreadCount: Int
    let latestNotificationTitle: String?
    let latestNotificationSummary: String?
    let onRefreshNotifications: () -> Void
    let entryPointsAreSelectable: Bool
    let onSelect: (BusinessSupportEntryPoint) -> Void
    @State private var selectedEntryPoint: BusinessSupportEntryPoint?

    init(
        title: String = "Soporte Nexo",
        entryPoints: [BusinessSupportEntryPoint] = BusinessSupportEntryPointsCatalog.defaultEntryPoints,
        notificationUnreadCount: Int = 0,
        latestNotificationTitle: String? = nil,
        latestNotificationSummary: String? = nil,
        onRefreshNotifications: @escaping () -> Void = {},
        entryPointsAreSelectable: Bool = true,
        onSelect: @escaping (BusinessSupportEntryPoint) -> Void = { _ in }
    ) {
        self.title = title
        self.entryPoints = entryPoints
        self.notificationUnreadCount = max(0, notificationUnreadCount)
        self.latestNotificationTitle = latestNotificationTitle
        self.latestNotificationSummary = latestNotificationSummary
        self.onRefreshNotifications = onRefreshNotifications
        self.entryPointsAreSelectable = entryPointsAreSelectable
        self.onSelect = onSelect
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                BusinessSupportHeaderCard(title: title)

                BusinessSupportNotificationMiniSurface(
                    unreadCount: notificationUnreadCount,
                    latestTitle: latestNotificationTitle,
                    latestSummary: latestNotificationSummary,
                    onRefresh: onRefreshNotifications
                )

                BusinessSupportGuardrailCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Temas de ayuda")
                        .font(.headline)

                    Text("Son entradas de soporte contextual. No reemplazan la navegación operativa de Venta rápida, Caja, Productos, Clientes o Historial.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(entryPoints) { entryPoint in
                        BusinessSupportEntryPointRow(
                            entryPoint: entryPoint,
                            isSelectable: entryPointsAreSelectable
                        ) {
                            selectedEntryPoint = entryPoint
                            onSelect(entryPoint)
                        }
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06))
                )
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 11)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedEntryPoint) { entryPoint in
            BusinessSupportEntryPointDetailSheet(entryPoint: entryPoint)
        }
        .accessibilityIdentifier("business_support_entrypoints")
    }
}

private struct BusinessSupportHeaderCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                BusinessSupportIconBadge(systemImage: "lifepreserver", tint: .accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))

                    Text("Centro de ayuda interna para reportar dudas con contexto mínimo, sanitizado y auditable.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Label("Soporte observa y orienta. Las acciones críticas siguen viviendo en sus pantallas normales.", systemImage: "checkmark.shield.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.green)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06))
        )
    }
}

private struct BusinessSupportGuardrailCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Límites seguros", systemImage: "lock.shield")
                .font(.subheadline.weight(.semibold))

            Text("No cobra, no factura, no agenda, no cambia permisos, no modifica inventario y no ejecuta acciones fiscales. Si algo requiere operación real, debe hacerse desde el flujo correspondiente.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.12))
        )
    }
}

private struct BusinessSupportEntryPointRow: View {
    let entryPoint: BusinessSupportEntryPoint
    let isSelectable: Bool
    let onSelect: () -> Void

    var body: some View {
        Group {
            if isSelectable {
                Button(action: onSelect) {
                    rowContent(showsChevron: true)
                }
                .buttonStyle(.plain)
            } else {
                rowContent(showsChevron: false)
            }
        }
        .accessibilityIdentifier("business_support_entrypoint_\(entryPoint.kind.rawValue)")
    }

    private func rowContent(showsChevron: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BusinessSupportIconBadge(systemImage: entryPoint.kind.systemImage, tint: entryPoint.kind.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(entryPoint.kind.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(entryPoint.kind.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(entryPoint.kind.contextType)
                        .font(.caption2.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)

                    if let statusLabel = entryPoint.statusLabel, !statusLabel.isEmpty {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(statusLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 8)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 3)
            } else {
                Text("Contexto")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
            }
        }
        .padding(12)
        .background(entryPoint.kind.tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(entryPoint.kind.tint.opacity(0.10))
        )
        .contentShape(Rectangle())
    }
}

private struct BusinessSupportNotificationMiniSurface: View {
    let unreadCount: Int
    let latestTitle: String?
    let latestSummary: String?
    let onRefresh: () -> Void

    private var hasUnread: Bool { unreadCount > 0 }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                BusinessSupportIconBadge(systemImage: hasUnread ? "bell.badge.fill" : "bell", tint: hasUnread ? .orange : .secondary)

                if hasUnread {
                    Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .offset(x: 8, y: -7)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(hasUnread ? "Novedades pendientes" : "Soporte al día")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(latestSummaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Actualizar novedades de soporte")
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(hasUnread ? Color.orange.opacity(0.25) : Color.primary.opacity(0.06))
        )
        .accessibilityLabel(hasUnread ? "Novedades de soporte pendientes" : "Soporte al día")
        .accessibilityHint("Actualiza el estado de soporte. No usa notificaciones push.")
    }

    private var latestSummaryText: String {
        if let title = latestTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            if let summary = latestSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
                return "\(title) · \(summary)"
            }
            return title
        }
        return "Actualización manual y estado básico; sin push, sin tiempo real y sin acciones críticas."
    }
}

private struct BusinessSupportIconBadge: View {
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

enum BusinessSupportEntryPointsCatalog {
    static let defaultEntryPoints: [BusinessSupportEntryPoint] = [
        BusinessSupportEntryPoint(kind: .operation, screenName: "business_home"),
        BusinessSupportEntryPoint(kind: .sale, screenName: "business_sales"),
        BusinessSupportEntryPoint(kind: .cash, screenName: "business_cash"),
        BusinessSupportEntryPoint(kind: .document, screenName: "business_documents"),
        BusinessSupportEntryPoint(kind: .product, screenName: "business_products"),
        BusinessSupportEntryPoint(kind: .customer, screenName: "business_customers"),
        BusinessSupportEntryPoint(kind: .permission, screenName: "business_permissions"),
        BusinessSupportEntryPoint(kind: .export, screenName: "business_exports"),
        BusinessSupportEntryPoint(kind: .readiness, screenName: "business_readiness"),
    ]
}

@Observable
final class BusinessSupportNotificationsViewModel {
    private let repository: BusinessSupportNotificationsRepository
    private let organizationId: String
    private let branchId: String

    private(set) var unreadCount: Int = 0
    private(set) var latestTitle: String?
    private(set) var latestSummary: String?
    private(set) var isLoading: Bool = false
    private(set) var hasLoaded: Bool = false
    private(set) var lastErrorMessage: String?

    init(
        repository: BusinessSupportNotificationsRepository,
        organizationId: String,
        branchId: String
    ) {
        self.repository = repository
        self.organizationId = organizationId
        self.branchId = branchId
    }

    @MainActor
    func refreshIfNeeded() async {
        guard !hasLoaded else { return }
        await refresh()
    }

    @MainActor
    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await repository.listNotifications(
                organizationId: organizationId,
                branchId: branchId,
                limit: 20,
                unreadOnly: nil
            )

            unreadCount = max(0, response.unreadCount)
            let latest = response.items.first
            latestTitle = latest?.title
            latestSummary = latest?.summary
            lastErrorMessage = nil
            hasLoaded = true
        } catch {
            unreadCount = 0
            latestTitle = "Soporte no actualizado"
            latestSummary = "No se pudo consultar novedades ahora. Puedes intentar otra vez."
            lastErrorMessage = error.localizedDescription
            hasLoaded = true
        }
    }
}

private struct BusinessSupportEntryPointDetailSheet: View {
    let entryPoint: BusinessSupportEntryPoint
    @Environment(\.dismiss) private var dismiss

    private var safeContextText: String {
        var parts: [String] = []
        parts.append("Nexo Business soporte")
        parts.append("Tema: \(entryPoint.kind.title)")
        parts.append("Tipo de contexto: \(entryPoint.kind.contextType)")
        parts.append("Pantalla: \(entryPoint.screenName)")
        if let entityRefId = entryPoint.entityRefId?.trimmingCharacters(in: .whitespacesAndNewlines), !entityRefId.isEmpty {
            parts.append("Referencia sanitizada: \(entityRefId)")
        }
        if let statusLabel = entryPoint.statusLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !statusLabel.isEmpty {
            parts.append("Estado visible: \(statusLabel)")
        }
        parts.append("Límites: no cobrar, no facturar, no agendar, no cambiar permisos, no modificar inventario y no ejecutar acciones fiscales desde soporte.")
        return parts.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entryPoint.kind.systemImage)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 42, height: 42)
                            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(entryPoint.kind.title)
                                .font(.title3.weight(.bold))
                            Text(entryPoint.kind.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 10) {
                        Label("Contexto seguro", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                        BusinessSupportDetailRow(label: "Tipo", value: entryPoint.kind.contextType)
                        BusinessSupportDetailRow(label: "Pantalla", value: entryPoint.screenName)
                        BusinessSupportDetailRow(label: "Referencia", value: safeEntityReference)
                        BusinessSupportDetailRow(label: "Estado", value: safeStatusLabel)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button(action: copySafeContext) {
                        Label("Copiar contexto seguro", systemImage: "doc.on.doc")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("business_support_copy_safe_context")

                    Text("Este panel solo prepara contexto sanitizado. No crea ventas, no registra cobros, no emite documentos y no cambia permisos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Soporte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() } 
                }
            }
        }
        .accessibilityIdentifier("business_support_entrypoint_detail_sheet")
    }

    private var safeEntityReference: String {
        guard let value = entryPoint.entityRefId?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "Sin referencia"
        }
        return value
    }

    private var safeStatusLabel: String {
        guard let value = entryPoint.statusLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return "Sin estado"
        }
        return value
    }

    private func copySafeContext() {
        #if canImport(UIKit)
        UIPasteboard.general.string = safeContextText
        #endif
    }
}

private struct BusinessSupportDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 86, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
