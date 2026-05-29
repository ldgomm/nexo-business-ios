//
//  BusinessSessionViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class BusinessSessionViewModel {
    public private(set) var state: BusinessSessionState = .bootstrapping
    public private(set) var context: BusinessContextResponse?
    public private(set) var operationalSelection: BusinessOperationalSelection?

    private let tokenStore: AuthTokenStoring
    private let selectionStore: BusinessSelectionStoring
    private let organizationAccessRepository: BusinessOrganizationAccessRepository
    private let contextRepository: BusinessContextRepository
    private var didBootstrap = false

    public init(
        tokenStore: AuthTokenStoring,
        selectionStore: BusinessSelectionStoring,
        organizationAccessRepository: BusinessOrganizationAccessRepository,
        contextRepository: BusinessContextRepository
    ) {
        self.tokenStore = tokenStore
        self.selectionStore = selectionStore
        self.organizationAccessRepository = organizationAccessRepository
        self.contextRepository = contextRepository
    }

    public func bootstrapIfNeeded() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        await bootstrap()
    }

    public func retryBootstrapOrRefresh() async {
        if await tokenStore.tokens() == nil {
            context = nil
            operationalSelection = nil
            state = .signedOut()
            return
        }

        let snapshot = await selectionStore.snapshot()
        if let organizationId = snapshot.organizationId, !organizationId.isEmpty {
            await loadContext(organizationId: organizationId)
        } else {
            await loadOrganizations()
        }
    }

    public func loadOrganizationsAfterLogin() async {
        await loadOrganizations()
    }

    public func selectOrganization(_ organization: BusinessOrganizationAccess) async {
        do {
            try await selectionStore.saveOrganizationId(organization.id)
            context = nil
            operationalSelection = nil
            await loadContext(organizationId: organization.id)
        } catch {
            state = .failed("No se pudo guardar el negocio seleccionado.")
        }
    }

    public func selectOperationalContext(branchId: String, activityId: String) async {
        guard let context else {
            state = .failed("No se encontró el contexto del negocio. Actualiza e inténtalo otra vez.")
            return
        }

        guard context.branches.contains(where: { $0.id == branchId }) else {
            state = .needsOperationalSelection(
                context: context,
                reason: "La sucursal seleccionada ya no está disponible."
            )
            return
        }

        guard context.activities.contains(where: { $0.id == activityId }) else {
            state = .needsOperationalSelection(
                context: context,
                reason: "La actividad seleccionada ya no está disponible."
            )
            return
        }

        do {
            try await selectionStore.saveOperationalContext(
                branchId: branchId,
                activityId: activityId
            )

            let selection = BusinessOperationalSelection(
                organizationId: context.organization.id,
                branchId: branchId,
                activityId: activityId
            )
            operationalSelection = selection
            state = .signedIn(context, selection)
        } catch {
            state = .failed("No se pudo guardar el contexto operativo.")
        }
    }

    public func refreshContext() async {
        if let organizationId = operationalSelection?.organizationId ?? context?.organization.id {
            await loadContext(organizationId: organizationId)
            return
        }

        let snapshot = await selectionStore.snapshot()
        if let organizationId = snapshot.organizationId, !organizationId.isEmpty {
            await loadContext(organizationId: organizationId)
        } else {
            await loadOrganizations()
        }
    }

    public func changeOrganization() async {
        do {
            try await selectionStore.clearAll()
        } catch {
            state = .failed("No se pudo limpiar la selección actual.")
            return
        }

        context = nil
        operationalSelection = nil
        await loadOrganizations()
    }

    public func changeOperationalContext() async {
        guard let context else {
            await refreshContext()
            return
        }

        do {
            try await selectionStore.clearOperationalContext()
        } catch {
            state = .failed("No se pudo limpiar el contexto operativo actual.")
            return
        }

        operationalSelection = nil
        state = .needsOperationalSelection(
            context: context,
            reason: "Selecciona la sucursal y actividad con la que vas a operar."
        )
    }

    public func logout() async {
        try? await tokenStore.clear()
        try? await selectionStore.clearAll()
        context = nil
        operationalSelection = nil
        state = .signedOut()
    }

    private func bootstrap() async {
        guard await tokenStore.tokens() != nil else {
            context = nil
            operationalSelection = nil
            state = .signedOut()
            return
        }

        let snapshot = await selectionStore.snapshot()
        if let organizationId = snapshot.organizationId, !organizationId.isEmpty {
            await loadContext(organizationId: organizationId)
        } else {
            await loadOrganizations()
        }
    }

    private func loadOrganizations() async {
        state = .loadingOrganizations

        do {
            let response = try await organizationAccessRepository.listOrganizations()
            let organizations = response.organizations.filter { organization in
                organization.status?.lowercased() != "inactive" &&
                organization.status?.lowercased() != "blocked" &&
                organization.status?.lowercased() != "archived"
            }

            if organizations.isEmpty {
                context = nil
                operationalSelection = nil
                state = .failed("No tienes negocios activos asignados para operar.")
                return
            }

            if organizations.count == 1, let organization = organizations.first {
                await selectOrganization(organization)
                return
            }

            context = nil
            operationalSelection = nil
            state = .needsOrganizationSelection(organizations)
        } catch let error as APIError {
            await handle(apiError: error)
        } catch {
            context = nil
            operationalSelection = nil
            state = .failed(error.localizedDescription)
        }
    }

    private func loadContext(organizationId: String) async {
        state = .loadingContext

        do {
            let loadedContext = try await contextRepository.getContext(
                organizationId: organizationId
            )
            context = loadedContext
            await resolveOperationalSelection(for: loadedContext)
        } catch let error as APIError {
            await handle(apiError: error)
        } catch {
            context = nil
            operationalSelection = nil
            state = .failed(error.localizedDescription)
        }
    }

    private func resolveOperationalSelection(for context: BusinessContextResponse) async {
        let branches = selectableBranches(from: context)
        let activities = selectableActivities(from: context)

        guard !branches.isEmpty else {
            operationalSelection = nil
            state = .needsOperationalSelection(
                context: context,
                reason: "Este negocio no tiene sucursales activas para operar."
            )
            return
        }

        guard !activities.isEmpty else {
            operationalSelection = nil
            state = .needsOperationalSelection(
                context: context,
                reason: "Este negocio no tiene actividades activas para operar."
            )
            return
        }

        let snapshot = await selectionStore.snapshot()
        if let branchId = snapshot.branchId,
           let activityId = snapshot.activityId,
           branches.contains(where: { $0.id == branchId }),
           activities.contains(where: { $0.id == activityId }) {
            let selection = BusinessOperationalSelection(
                organizationId: context.organization.id,
                branchId: branchId,
                activityId: activityId
            )
            operationalSelection = selection
            state = .signedIn(context, selection)
            return
        }

        if branches.count == 1, activities.count == 1,
           let branch = branches.first,
           let activity = activities.first {
            await selectOperationalContext(branchId: branch.id, activityId: activity.id)
            return
        }

        operationalSelection = nil
        state = .needsOperationalSelection(
            context: context,
            reason: "Selecciona la sucursal y actividad antes de vender, cobrar o cerrar caja."
        )
    }

    private func selectableBranches(from context: BusinessContextResponse) -> [BusinessBranch] {
        let active = context.branches.filter { $0.status.lowercased() == "active" }
        return active.isEmpty ? context.branches : active
    }

    private func selectableActivities(from context: BusinessContextResponse) -> [BusinessActivity] {
        let active = context.activities.filter { $0.status.lowercased() == "active" }
        return active.isEmpty ? context.activities : active
    }

    private func handle(apiError: APIError) async {
        if apiError.isUnauthorized {
            try? await tokenStore.clear()
            try? await selectionStore.clearAll()
            context = nil
            operationalSelection = nil
            state = .signedOut(message: apiError.userMessage)
            return
        }

        context = nil
        operationalSelection = nil
        state = .failed(apiError.userMessage)
    }
}
