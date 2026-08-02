//
//  BusinessFinanceAmountFormatterTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import XCTest
@testable import Nexo_Business

class BusinessFinanceAmountFormatterTests: XCTestCase {
    private let formatter = BusinessFinanceAmountFormatter()

    func testFormatsExactDecimalWithExplicitLocaleAndCurrency() throws {
        let value = try XCTUnwrap(
            formatter.string(
                from: BusinessFinanceAmount(
                    decimalValue: "1250.50",
                    currencyCode: "EUR"
                ),
                localeIdentifier: "fr_FR"
            )
        )

        XCTAssertTrue(value.contains("1"))
        XCTAssertTrue(value.contains("250"))
    }

    func testInvalidDecimalFailsClosed() {
        XCTAssertNil(
            formatter.string(
                from: BusinessFinanceAmount(
                    decimalValue: "not-a-number",
                    currencyCode: "EUR"
                ),
                localeIdentifier: "fr_FR"
            )
        )
    }

    func testMissingLocaleOrCurrencyFailsClosed() {
        XCTAssertNil(
            formatter.string(
                from: BusinessFinanceAmount(
                    decimalValue: "1.00",
                    currencyCode: ""
                ),
                localeIdentifier: "fr_FR"
            )
        )
        XCTAssertNil(
            formatter.string(
                from: BusinessFinanceAmount(
                    decimalValue: "1.00",
                    currencyCode: "EUR"
                ),
                localeIdentifier: ""
            )
        )
    }
}

