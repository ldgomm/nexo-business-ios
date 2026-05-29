//
//  CustomerCreateViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class CustomerCreateViewModelTests: XCTestCase {
    func testSaveRequiresNameAndIdentification() async {
        let repository = CustomersRepositorySpy()
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )

        let customer = await viewModel.save()

        XCTAssertNil(customer)
        XCTAssertEqual(viewModel.errorMessage, "Ingresa el nombre del cliente.")
        XCTAssertNil(repository.lastCreateRequest)
    }

    func testSaveCreatesCustomerWithIdempotencyKey() async {
        let expected = BusinessCustomer(
            id: "cus_1",
            displayName: "Cliente Uno",
            identificationType: .cedula,
            identificationNumber: "1712345678",
            email: "cliente@nexo.test"
        )
        let repository = CustomersRepositorySpy(
            createResponse: CustomerResponse(
                customer: expected,
                idempotencyReplayed: false
            )
        )
        let viewModel = CustomerCreateViewModel(
            organizationId: "org_1",
            customersRepository: repository
        )
        viewModel.displayName = " Cliente Uno "
        viewModel.identificationType = .cedula
        viewModel.identificationNumber = " 1712345678 "
        viewModel.email = " cliente@nexo.test "

        let customer = await viewModel.save()

        XCTAssertEqual(customer, expected)
        XCTAssertEqual(repository.lastCreateRequest?.displayName, "Cliente Uno")
        XCTAssertEqual(repository.lastCreateRequest?.identificationNumber, "1712345678")
        XCTAssertEqual(repository.lastCreateRequest?.email, "cliente@nexo.test")
        XCTAssertTrue(repository.lastCreateIdempotencyKey?.rawValue.hasPrefix("customer-create-") == true)
        XCTAssertEqual(viewModel.infoMessage, "Cliente creado correctamente.")
    }
}
