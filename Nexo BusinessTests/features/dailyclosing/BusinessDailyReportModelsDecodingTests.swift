//
//  BusinessDailyReportModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessDailyReportModelsDecodingTests: XCTestCase {
    func testDecodesDailyReportEnvelope() throws {
        let json = #"""
        {
          "report": {
            "businessDate": "2026-05-29",
            "branchId": "br_1",
            "salesCount": 7,
            "salesTotal": { "amount": "125.50", "currency": "USD" },
            "paymentsCount": 6,
            "paymentsTotal": { "amount": "108.00", "currency": "USD" },
            "cashExpectedAmount": { "amount": "78.00", "currency": "USD" },
            "receivablesPendingCount": 1,
            "receivablesPendingTotal": { "amount": "17.50", "currency": "USD" },
            "pendingSalesCount": 2,
            "pendingDocumentsCount": 1,
            "cashStatus": "open"
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessDailyReportResponse.self,
            from: json
        )

        XCTAssertEqual(response.report.businessDate, "2026-05-29")
        XCTAssertEqual(response.report.salesCount, 7)
        XCTAssertEqual(response.report.salesTotal?.amount, "125.50")
        XCTAssertEqual(response.report.cashStatus, "open")
    }

    func testDecodesDailyReportWithoutEnvelope() throws {
        let json = #"""
        {
          "businessDate": "2026-05-29",
          "branchId": "br_1",
          "salesCount": 0,
          "paymentsCount": 0,
          "cashStatus": "closed"
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessDailyReportResponse.self,
            from: json
        )

        XCTAssertEqual(response.report.businessDate, "2026-05-29")
        XCTAssertEqual(response.report.cashStatus, "closed")
    }
}
