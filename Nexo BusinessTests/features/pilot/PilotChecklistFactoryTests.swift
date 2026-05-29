//
//  PilotChecklistFactoryTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class PilotChecklistFactoryTests: XCTestCase {
    func testDefaultItemsContainRequiredOperationalSmokeChecks() {
        let items = PilotChecklistFactory.defaultItems()
        let ids = Set(items.map(\.id))

        XCTAssertTrue(ids.contains("session_restore_verified"))
        XCTAssertTrue(ids.contains("cash_open_close_smoke"))
        XCTAssertTrue(ids.contains("quick_sale_confirm_smoke"))
        XCTAssertTrue(ids.contains("payment_cash_transfer_card_smoke"))
        XCTAssertTrue(ids.contains("documents_smoke"))
        XCTAssertTrue(ids.contains("pending_daily_closing_smoke"))
        XCTAssertTrue(ids.contains("hardening_smoke"))
    }

    func testRequiredItemsAreMoreThanOptionalItems() {
        let items = PilotChecklistFactory.defaultItems()
        let requiredCount = items.filter(\.isRequired).count
        let optionalCount = items.filter { !$0.isRequired }.count

        XCTAssertGreaterThan(requiredCount, optionalCount)
    }
}
