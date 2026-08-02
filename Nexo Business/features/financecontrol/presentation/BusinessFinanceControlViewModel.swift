//
//  BusinessFinanceControlViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation
import Observation

@MainActor
@Observable
class BusinessFinanceControlViewModel {
    private(set) var snapshot: BusinessFinanceControlSnapshot?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let scope: BusinessFinanceControlScope

    private let repository: any BusinessFinanceControlRepository
    private let accessPolicy: BusinessFinanceControlAccessPolicy
    private let validator: BusinessFinanceControlSnapshotValidator
    private let amountFormatter: BusinessFinanceAmountFormatter
    private var hasLoaded = false

    init(
        scope: BusinessFinanceControlScope,
        effectivePermissions: Set<String>,
        repository: any BusinessFinanceControlRepository,
        validator: BusinessFinanceControlSnapshotValidator = .init(),
        amountFormatter: BusinessFinanceAmountFormatter = .init()
    ) {
        self.scope = scope
        self.repository = repository
        self.accessPolicy = BusinessFinanceControlAccessPolicy(
            effectivePermissions: effectivePermissions
        )
        self.validator = validator
        self.amountFormatter = amountFormatter
    }

    var canViewSurface: Bool {
        accessPolicy.canViewSurface
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func load() async {
        guard accessPolicy.canViewSurface else {
            snapshot = nil
            errorMessage = "No tienes permiso para consultar esta información."
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
            let loadedSnapshot = try await repository.loadSnapshot(scope: scope)
            try validator.validate(loadedSnapshot, requestedScope: scope)
            snapshot = loadedSnapshot
        } catch BusinessFinanceControlRepositoryError.runtimeEndpointUnavailable {
            snapshot = nil
            errorMessage = "La vista segura está instalada. La conexión con datos reales se habilita en el cierre runtime de 28R."
        } catch {
            snapshot = nil
            errorMessage = "No fue posible cargar la información financiera de forma segura."
        }
    }

    func canView(_ surface: BusinessFinanceControlSurface) -> Bool {
        accessPolicy.canView(surface)
    }

    func allows(_ action: BusinessFinanceControlAction) -> Bool {
        guard let snapshot else { return false }
        return accessPolicy.allows(action, capabilities: snapshot.capabilities)
    }

    func formatted(_ amount: BusinessFinanceAmount) -> String {
        guard let snapshot else {
            return "\(amount.currencyCode) \(amount.decimalValue)"
        }
        return amountFormatter.string(
            from: amount,
            localeIdentifier: snapshot.scope.localeIdentifier
        ) ?? "\(amount.currencyCode) \(amount.decimalValue)"
    }
}
