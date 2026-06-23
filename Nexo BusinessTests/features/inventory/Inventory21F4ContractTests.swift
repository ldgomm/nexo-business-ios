//
//  Inventory21F4ContractTests.swift
//  Nexo BusinessTests
//

import XCTest
@testable import Nexo_Business

final class Inventory21F4ContractTests: XCTestCase {
    func testBusinessInventoryRoutesExposeInventorySettingsContract() {
        XCTAssertEqual(
            BusinessInventoryRoutes.inventorySettings(productId: "prod_1"),
            "/api/v1/business/products/prod_1/inventory-settings"
        )
    }
}
