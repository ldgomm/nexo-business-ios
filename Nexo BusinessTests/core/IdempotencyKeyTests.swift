//
//  IdempotencyKeyTests.swift
//  Nexo Admin
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class IdempotencyKeyTests: XCTestCase {
    func testGeneratesPrefixedUniqueKeys() {
        let first = IdempotencyKey.generate(prefix: "quick-sale")
        let second = IdempotencyKey.generate(prefix: "quick-sale")

        XCTAssertTrue(first.rawValue.hasPrefix("quick-sale-"))
        XCTAssertNotEqual(first, second)
    }
}
