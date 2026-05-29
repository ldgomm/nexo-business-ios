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

    private let organizationId: String
    private let tokenStore: AuthTokenStoring
    private let contextRepository: BusinessContextRepository
    private var didBootstrap = false

    public init(
        organizationId: String,
        tokenStore: AuthTokenStoring,
        contextRepository: BusinessContextRepository
    ) {
        self.organizationId = organizationId
        self.tokenStore = tokenStore
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
            state = .signedOut()
            return
        }

        await loadContext()
    }

    public func loadContextAfterLogin() async {
        await loadContext()
    }

    public func refreshContext() async {
        await loadContext()
    }

    public func logout() async {
        try? await tokenStore.clear()
        context = nil
        state = .signedOut()
    }

    private func bootstrap() async {
        guard await tokenStore.tokens() != nil else {
            context = nil
            state = .signedOut()
            return
        }

        await loadContext()
    }

    private func loadContext() async {
        state = .loadingContext

        do {
            let loadedContext = try await contextRepository.getContext(
                organizationId: organizationId
            )
            context = loadedContext
            state = .signedIn(loadedContext)
        } catch let error as APIError {
            await handle(apiError: error)
        } catch {
            context = nil
            state = .failed(error.localizedDescription)
        }
    }

    private func handle(apiError: APIError) async {
        if apiError.isUnauthorized {
            try? await tokenStore.clear()
            context = nil
            state = .signedOut(message: apiError.userMessage)
            return
        }

        context = nil
        state = .failed(apiError.userMessage)
    }
}
