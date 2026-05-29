//
//  CustomerDirectoryViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class CustomerDirectoryViewModel {
    public private(set) var customers: [BusinessCustomer] = []
    public private(set) var isLoading = false
    public var query = ""
    public var errorMessage: String?
    public var infoMessage: String?

    public let organizationId: String
    public let effectivePermissions: Set<String>
    public let customersRepository: CustomersRepository

    public init(
        organizationId: String,
        effectivePermissions: Set<String>,
        customersRepository: CustomersRepository
    ) {
        self.organizationId = organizationId
        self.effectivePermissions = effectivePermissions
        self.customersRepository = customersRepository
    }

    public var canView: Bool {
        hasPermission([
            "business.customers.view",
            "customers.view",
            "business.customers.create",
            "customers.create"
        ])
    }

    public var canCreate: Bool {
        hasPermission([
            "business.customers.create",
            "customers.create"
        ])
    }

    public func load() async {
        await search()
    }

    public func search() async {
        guard canView else {
            errorMessage = "No tienes permiso para consultar clientes."
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await customersRepository.search(
                organizationId: organizationId,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 50
            )

            customers = response.customers
            infoMessage = response.customers.isEmpty ? "No encontramos clientes." : nil
        } catch let error as APIError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func addOrReplace(_ customer: BusinessCustomer) {
        if let index = customers.firstIndex(where: { $0.id == customer.id }) {
            customers[index] = customer
        } else {
            customers.insert(customer, at: 0)
        }
    }

    private func hasPermission(_ candidates: [String]) -> Bool {
        candidates.contains { effectivePermissions.contains($0) }
    }
}
