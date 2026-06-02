//
//  CustomerPickerViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class CustomerPickerViewModel {
    private(set) var customers: [BusinessCustomer] = []
    private(set) var isSearching = false
    var query = ""
    var errorMessage: String?
    var infoMessage: String?

    let organizationId: String
    let effectivePermissions: Set<String>
    let customersRepository: CustomersRepository

    init(
        organizationId: String,
        effectivePermissions: Set<String>,
        customersRepository: CustomersRepository
    ) {
        self.organizationId = organizationId
        self.effectivePermissions = effectivePermissions
        self.customersRepository = customersRepository
    }

    var canSearch: Bool {
        hasPermission([
            "business.customers.view",
            "customers.view",
            "business.customers.create",
            "customers.create",
            "business.receivables.create",
            "receivables.create"
        ])
    }

    var canCreate: Bool {
        hasPermission([
            "business.customers.create",
            "customers.create"
        ])
    }

    func loadInitial() async {
        if customers.isEmpty {
            await search()
        }
    }

    func search() async {
        guard canSearch else {
            errorMessage = "No tienes permiso para consultar clientes."
            return
        }

        guard !isSearching else { return }

        isSearching = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isSearching = false
        }

        do {
            let response = try await customersRepository.search(
                organizationId: organizationId,
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                limit: 25
            )

            customers = response.customers
            infoMessage = response.customers.isEmpty ? "No encontramos clientes." : nil
        } catch let error as APIError {
            print("❌ Preview APIError:", error)
            errorMessage = error.userMessage
        } catch {
            print("❌ Preview Error:", error)
            errorMessage = error.localizedDescription
        }
    }

    func addOrReplace(_ customer: BusinessCustomer) {
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
