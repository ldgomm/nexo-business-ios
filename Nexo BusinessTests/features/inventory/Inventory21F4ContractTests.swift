//
//  Inventory21F4ContractTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

class Inventory21F4ContractTests: XCTestCase {
    func testBusinessInventoryRoutesExposeInventorySettingsContract() {
        XCTAssertEqual(
            BusinessInventoryRoutes.inventorySettings(productId: "prod_1"),
            "/api/v1/business/products/prod_1/inventory-settings"
        )
    }
}
