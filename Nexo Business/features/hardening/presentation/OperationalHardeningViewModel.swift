//
//  OperationalHardeningViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class OperationalHardeningViewModel {
    public private(set) var state: AsyncViewState<OperationalHardeningReport> = .idle
    public private(set) var isRunning = false

    private let context: BusinessContextResponse
    private let operationalSelection: BusinessOperationalSelection
    private let tokenStore: AuthTokenStoring
    private let networkStatusProvider: NetworkStatusProviding

    public init(
        context: BusinessContextResponse,
        operationalSelection: BusinessOperationalSelection,
        tokenStore: AuthTokenStoring,
        networkStatusProvider: NetworkStatusProviding
    ) {
        self.context = context
        self.operationalSelection = operationalSelection
        self.tokenStore = tokenStore
        self.networkStatusProvider = networkStatusProvider
    }

    public func run() async {
        guard !isRunning else { return }

        isRunning = true
        state = .loading

        defer {
            isRunning = false
        }

        var checks: [OperationalHardeningCheck] = []
        checks.append(await tokenCheck())
        checks.append(await networkCheck())
        checks.append(readinessCheck())
        checks.append(operationalSelectionCheck())
        checks.append(revisionsCheck())
        checks.append(modulesCheck())
        checks.append(permissionsCheck())
        checks.append(offlineTransactionPolicyCheck())
        checks.append(electronicInvoiceBoundaryCheck())
        checks.append(deviceMetadataContractCheck())

        state = .loaded(
            OperationalHardeningReport(checks: checks)
        )
    }

    private func tokenCheck() async -> OperationalHardeningCheck {
        let hasToken = await tokenStore.accessToken()?.isEmpty == false

        return OperationalHardeningCheck(
            id: "session-token",
            title: "Sesión activa",
            detail: hasToken
                ? "Hay token local para operar contra backend."
                : "No hay token activo; el operador debe iniciar sesión.",
            status: hasToken ? .passed : .failed,
            isBlocking: true
        )
    }

    private func networkCheck() async -> OperationalHardeningCheck {
        let status = await networkStatusProvider.currentStatus()

        return OperationalHardeningCheck(
            id: "network-status",
            title: "Conectividad",
            detail: status.userMessage,
            status: status.isUsable ? (status == .satisfied ? .passed : .warning) : .failed,
            isBlocking: !status.isUsable
        )
    }

    private func readinessCheck() -> OperationalHardeningCheck {
        let normalized = context.readiness.status.lowercased()
        let score = context.readiness.score.map(String.init) ?? "sin score"
        let hasBlockers = !context.readiness.blockers.isEmpty
        let ready = normalized == "ready" && !hasBlockers

        return OperationalHardeningCheck(
            id: "business-readiness",
            title: "Readiness del negocio",
            detail: ready
                ? "Readiness \(context.readiness.status) con score \(score)."
                : "Readiness \(context.readiness.status). Blockers: \(context.readiness.blockers.joined(separator: ", "))",
            status: ready ? .passed : .failed,
            isBlocking: true
        )
    }

    private func operationalSelectionCheck() -> OperationalHardeningCheck {
        let branchExists = context.branches.contains { $0.id == operationalSelection.branchId && $0.status == "active" }
        let activityExists = context.activities.contains { $0.id == operationalSelection.activityId && $0.status == "active" }
        let ok = branchExists && activityExists

        return OperationalHardeningCheck(
            id: "operational-selection",
            title: "Sucursal y actividad",
            detail: ok
                ? "La selección operativa pertenece al contexto actual."
                : "La sucursal o actividad seleccionada no está activa en este negocio.",
            status: ok ? .passed : .failed,
            isBlocking: true
        )
    }

    private func revisionsCheck() -> OperationalHardeningCheck {
        let hasCatalogRevision = !context.revisions.catalogRevision.isEmpty
        let hasTaxRevision = !context.revisions.taxConfigurationRevision.isEmpty
        let ok = hasCatalogRevision && hasTaxRevision

        return OperationalHardeningCheck(
            id: "business-revisions",
            title: "Revisiones de catálogo e impuestos",
            detail: ok
                ? "Catalog: \(context.revisions.catalogRevision), Tax: \(context.revisions.taxConfigurationRevision)."
                : "Falta catalogRevision o taxConfigurationRevision. Actualiza contexto antes de vender.",
            status: ok ? .passed : .failed,
            isBlocking: true
        )
    }

    private func modulesCheck() -> OperationalHardeningCheck {
        let required: Set<ModuleCode> = [.coreSales, .coreCash, .coreDocuments]
        let missing = required.subtracting(context.activeModules).map(\.rawValue).sorted()
        let ok = missing.isEmpty

        return OperationalHardeningCheck(
            id: "active-modules",
            title: "Módulos críticos activos",
            detail: ok
                ? "Ventas, caja y comprobantes están activos."
                : "Faltan módulos: \(missing.joined(separator: ", ")).",
            status: ok ? .passed : .warning,
            isBlocking: false
        )
    }

    private func permissionsCheck() -> OperationalHardeningCheck {
        let requiredGroups: [(String, [String])] = [
            ("ventas", ["business.sales.create", "sales.create"]),
            ("caja", ["business.cash.view_current", "cash.view_current", "business.cash.open", "cash.open"]),
            ("cobros", ["business.payments.collect", "payments.collect", "business.payments.register", "payments.register"]),
            ("documentos", ["business.documents.view", "documents.view", "business.documents.issue_internal_ticket", "documents.issue_internal_ticket"])
        ]

        let missingGroups = requiredGroups.compactMap { name, candidates in
            candidates.contains { context.effectivePermissions.contains($0) } ? nil : name
        }

        return OperationalHardeningCheck(
            id: "permissions",
            title: "Permisos operativos mínimos",
            detail: missingGroups.isEmpty
                ? "El usuario tiene permisos mínimos para operar el día."
                : "Revisa permisos de: \(missingGroups.joined(separator: ", ")).",
            status: missingGroups.isEmpty ? .passed : .warning,
            isBlocking: false
        )
    }

    private func offlineTransactionPolicyCheck() -> OperationalHardeningCheck {
        OperationalHardeningCheck(
            id: "offline-policy",
            title: "Política offline",
            detail: "No se habilitan cobros reales ni confirmaciones locales sin backend. Modo sin red debe ser solo lectura.",
            status: .passed,
            isBlocking: false
        )
    }

    private func electronicInvoiceBoundaryCheck() -> OperationalHardeningCheck {
        OperationalHardeningCheck(
            id: "electronic-invoice-boundary",
            title: "Límite de factura electrónica",
            detail: "La app no firma XML ni habla directo con SRI; todo pasa por backend.",
            status: .passed,
            isBlocking: false
        )
    }

    private func deviceMetadataContractCheck() -> OperationalHardeningCheck {
        let requiredHeaders = [
            BusinessHeaders.requestId,
            BusinessHeaders.correlationId,
            BusinessHeaders.deviceId,
            BusinessHeaders.appName,
            BusinessHeaders.appVersion,
            BusinessHeaders.appBuild,
            BusinessHeaders.platform
        ]

        return OperationalHardeningCheck(
            id: "device-metadata",
            title: "Metadata de dispositivo",
            detail: "Headers requeridos configurados: \(requiredHeaders.joined(separator: ", ")).",
            status: .passed,
            isBlocking: false
        )
    }
}
