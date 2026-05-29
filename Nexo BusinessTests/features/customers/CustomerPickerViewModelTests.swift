//
//  CustomerPickerViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class CustomerPickerViewModelTests: XCTestCase {
    func testSearchRequiresPermission() async {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: [],
            customersRepository: repository
        )

        await viewModel.search()

        XCTAssertEqual(viewModel.errorMessage, "No tienes permiso para consultar clientes.")
        XCTAssertEqual(repository.searchCalls, 0)
    }

    func testSearchLoadsCustomers() async {
        let repository = CustomersRepositorySpy(
            searchResponse: CustomersSearchResponse(
                customers: [
                    BusinessCustomer(
                        id: "cus_1",
                        displayName: "Cliente Uno",
                        identificationType: .cedula,
                        identificationNumber: "1712345678"
                    )
                ]
            )
        )
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: ["customers.view"],
            customersRepository: repository
        )
        viewModel.query = "cliente"

        await viewModel.search()

        XCTAssertEqual(repository.lastSearchQuery, "cliente")
        XCTAssertEqual(viewModel.customers.count, 1)
        XCTAssertEqual(viewModel.customers[0].id, "cus_1")
    }

    func testAddOrReplaceKeepsCustomerUnique() {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerPickerViewModel(
            organizationId: "org_1",
            effectivePermissions: ["customers.view"],
            customersRepository: repository
        )

        viewModel.addOrReplace(
            BusinessCustomer(
                id: "cus_1",
                displayName: "Cliente Uno",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )
        viewModel.addOrReplace(
            BusinessCustomer(
                id: "cus_1",
                displayName: "Cliente Actualizado",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )

        XCTAssertEqual(viewModel.customers.count, 1)
        XCTAssertEqual(viewModel.customers[0].displayName, "Cliente Actualizado")
    }
}

final class CustomersRepositorySpy: CustomersRepository, @unchecked Sendable {
    var searchCalls = 0
    var lastSearchQuery: String?
    var lastCreateRequest: CreateCustomerRequest?
    var lastCreateIdempotencyKey: IdempotencyKey?
    let searchResponse: CustomersSearchResponse
    let createResponse: CustomerResponse

    init(
        searchResponse: CustomersSearchResponse = CustomersSearchResponse(customers: []),
        createResponse: CustomerResponse = CustomerResponse(
            customer: BusinessCustomer(
                id: "cus_created",
                displayName: "Creado",
                identificationType: .cedula,
                identificationNumber: "1712345678"
            )
        )
    ) {
        self.searchResponse = searchResponse
        self.createResponse = createResponse
    }

    func search(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CustomersSearchResponse {
        searchCalls += 1
        lastSearchQuery = query
        return searchResponse
    }

    func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateCustomerRequest
    ) async throws -> CustomerResponse {
        lastCreateIdempotencyKey = idempotencyKey
        lastCreateRequest = request
        return createResponse
    }
}
