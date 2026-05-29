//
//  PilotReadinessViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class PilotReadinessViewModel {
    public private(set) var items: [PilotChecklistItem] = []
    public private(set) var isLoading = false
    public private(set) var isSaving = false
    public var errorMessage: String?
    public var infoMessage: String?

    public let context: BusinessContextResponse
    public let selectedBranchId: String
    public let selectedActivityId: String

    private let store: PilotChecklistStoring

    public init(
        context: BusinessContextResponse,
        selectedBranchId: String,
        selectedActivityId: String,
        store: PilotChecklistStoring
    ) {
        self.context = context
        self.selectedBranchId = selectedBranchId
        self.selectedActivityId = selectedActivityId
        self.store = store
    }

    public var snapshot: PilotReadinessSnapshot {
        makeSnapshot(items: items)
    }

    public var groupedItems: [(category: PilotChecklistCategory, items: [PilotChecklistItem])] {
        let groups = Dictionary(grouping: items) { $0.category }
        return PilotChecklistCategory.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { category in
                guard let categoryItems = groups[category], !categoryItems.isEmpty else {
                    return nil
                }
                return (
                    category: category,
                    items: categoryItems.sorted { $0.id < $1.id }
                )
            }
    }

    public var readyStatusMessage: String {
        if snapshot.isReadyForPilot {
            return "Puedes iniciar piloto controlado con el negocio seleccionado. Mantén monitoreo y soporte cerca."
        }

        if !snapshot.blockers.isEmpty {
            return "Aún hay bloqueantes. No inicies piloto real hasta resolverlos."
        }

        return "Estás cerca. Completa las advertencias críticas antes de entregar a operación."
    }

    public func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer { isLoading = false }

        let saved = await store.load(organizationId: context.organization.id)
        items = merge(savedItems: saved, defaultItems: PilotChecklistFactory.defaultItems())
    }

    public func toggle(itemId: String) async {
        guard let index = items.firstIndex(where: { $0.id == itemId }) else { return }

        items[index].isDone.toggle()
        items[index].updatedAt = Date()
        await saveCurrentItems(successMessage: nil)
    }

    public func markAllRequiredDone() async {
        for index in items.indices where items[index].isRequired {
            items[index].isDone = true
            items[index].updatedAt = Date()
        }

        await saveCurrentItems(successMessage: "Checks requeridos marcados como completados para revisión manual.")
    }

    public func reset() async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil

        defer { isSaving = false }

        do {
            try await store.reset(organizationId: context.organization.id)
            items = PilotChecklistFactory.defaultItems()
            infoMessage = "Checklist reiniciado."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func makeExportText() -> String {
        let snapshot = snapshot
        let requiredSummary = "\(snapshot.completedRequired)/\(snapshot.totalRequired) requeridos"
        let optionalSummary = "\(snapshot.completedOptional)/\(snapshot.totalOptional) opcionales"
        let header = """
        Nexo Business — Cierre Fase 15 / Piloto
        Negocio: \(context.organization.commercialName)
        Organización: \(context.organization.id)
        Sucursal: \(selectedBranchId.isEmpty ? "sin selección" : selectedBranchId)
        Actividad: \(selectedActivityId.isEmpty ? "sin selección" : selectedActivityId)
        Readiness backend: \(context.readiness.status)
        Score piloto: \(snapshot.score)%
        Avance: \(requiredSummary), \(optionalSummary)
        Estado: \(snapshot.statusTitle)
        """

        let checklist = items
            .sorted { lhs, rhs in
                if lhs.category.sortOrder != rhs.category.sortOrder {
                    return lhs.category.sortOrder < rhs.category.sortOrder
                }
                return lhs.id < rhs.id
            }
            .map { item in
                "\(item.isDone ? "[x]" : "[ ]") \(item.category.displayName) — \(item.title)"
            }
            .joined(separator: "\n")

        let blockers = snapshot.blockers.isEmpty
            ? "Sin bloqueantes."
            : snapshot.blockers.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")

        let warnings = snapshot.warnings.isEmpty
            ? "Sin advertencias."
            : snapshot.warnings.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")

        return """
        \(header)

        Checklist
        \(checklist)

        Bloqueantes
        \(blockers)

        Advertencias
        \(warnings)
        """
    }

    private func saveCurrentItems(successMessage: String?) async {
        isSaving = true
        errorMessage = nil
        infoMessage = nil

        defer { isSaving = false }

        do {
            try await store.save(items, organizationId: context.organization.id)
            self.infoMessage = successMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func merge(
        savedItems: [PilotChecklistItem]?,
        defaultItems: [PilotChecklistItem]
    ) -> [PilotChecklistItem] {
        guard let savedItems else { return defaultItems }
        let savedById = Dictionary(uniqueKeysWithValues: savedItems.map { ($0.id, $0) })

        return defaultItems.map { defaultItem in
            guard let saved = savedById[defaultItem.id] else {
                return defaultItem
            }

            var merged = defaultItem
            merged.isDone = saved.isDone
            merged.updatedAt = saved.updatedAt
            return merged
        }
    }

    private func makeSnapshot(items: [PilotChecklistItem]) -> PilotReadinessSnapshot {
        let required = items.filter(\.isRequired)
        let optional = items.filter { !$0.isRequired }
        let completedRequired = required.filter(\.isDone).count
        let completedOptional = optional.filter(\.isDone).count
        let totalRequired = required.count
        let totalOptional = optional.count
        let score = totalRequired == 0 ? 0 : Int((Double(completedRequired) / Double(totalRequired) * 100).rounded())

        var blockers: [PilotReadinessIssue] = []
        var warnings: [PilotReadinessIssue] = []

        if context.readiness.status.lowercased() != "ready" {
            blockers.append(
                PilotReadinessIssue(
                    id: "backend_readiness_not_ready",
                    title: "Readiness backend no está listo",
                    detail: "Estado actual: \(context.readiness.status). Revisa bloqueantes fiscales, módulos o configuración.",
                    severity: .blocker
                )
            )
        }

        if selectedBranchId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append(
                PilotReadinessIssue(
                    id: "missing_branch_selection",
                    title: "Falta sucursal operativa",
                    detail: "Selecciona una sucursal real antes de iniciar piloto.",
                    severity: .blocker
                )
            )
        }

        if selectedActivityId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blockers.append(
                PilotReadinessIssue(
                    id: "missing_activity_selection",
                    title: "Falta actividad operativa",
                    detail: "Selecciona una actividad real antes de iniciar piloto.",
                    severity: .blocker
                )
            )
        }

        if !context.activeModules.contains(.coreSales) {
            blockers.append(
                PilotReadinessIssue(
                    id: "missing_core_sales",
                    title: "Módulo de ventas no activo",
                    detail: "core.sales debe estar activo para operar el día completo.",
                    severity: .blocker
                )
            )
        }

        if !context.activeModules.contains(.coreCash) {
            warnings.append(
                PilotReadinessIssue(
                    id: "missing_core_cash",
                    title: "Módulo de caja no activo",
                    detail: "El piloto puede operar sin caja solo si no habrá efectivo. Para restaurante, debe estar activo.",
                    severity: .warning
                )
            )
        }

        if context.revisions.catalogRevision.isEmpty || context.revisions.taxConfigurationRevision.isEmpty {
            blockers.append(
                PilotReadinessIssue(
                    id: "missing_revisions",
                    title: "Faltan revisiones operativas",
                    detail: "catalogRevision y taxConfigurationRevision son obligatorias para ventas seguras.",
                    severity: .blocker
                )
            )
        }

        for item in required where !item.isDone {
            let issue = PilotReadinessIssue(
                id: item.id,
                title: item.title,
                detail: item.detail,
                severity: item.severity
            )

            switch item.severity {
            case .blocker:
                blockers.append(issue)
            case .warning, .info:
                warnings.append(issue)
            }
        }

        return PilotReadinessSnapshot(
            score: score,
            completedRequired: completedRequired,
            totalRequired: totalRequired,
            completedOptional: completedOptional,
            totalOptional: totalOptional,
            blockers: blockers,
            warnings: warnings
        )
    }
}
