//
//  BusinessHomeViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class BusinessHomeViewModel {
    private(set) var state: AsyncViewState<BusinessContextResponse> = .idle

    private let organizationId: String
    private let repository: BusinessContextRepository

    init(
        organizationId: String,
        contextRepository: BusinessContextRepository
    ) {
        self.organizationId = organizationId
        self.repository = contextRepository
    }

    func load() async {
        state = .loading

        do {
            let context = try await repository.getContext(
                organizationId: organizationId
            )
            state = .loaded(context)
        } catch let error as APIError {
            state = .failed(error.userMessage)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
