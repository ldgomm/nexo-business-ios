//
//  SalesHistoryModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class SalesHistoryModelsDecodingTests: XCTestCase {
    func testDecodesSalesHistoryResponseFromSalesKey() throws {
        let json = #"""
        {
          "sales": [
            {
              "id": "sale_1",
              "organizationId": "org_1",
              "branchId": "br_1",
              "activityId": "act_1",
              "status": "closed",
              "paymentStatus": "paid",
              "documentStatus": "generated",
              "totals": {
                "subtotalWithoutTaxes": { "amount": "10.00", "currency": "USD" },
                "discountTotal": { "amount": "0.00", "currency": "USD" },
                "taxTotal": { "amount": "1.50", "currency": "USD" },
                "grandTotal": { "amount": "11.50", "currency": "USD" }
              },
              "items": [],
              "createdAt": "2026-05-29T12:00:00Z"
            }
          ],
          "total": 1,
          "hasMore": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessSalesHistoryResponse.self,
            from: json
        )

        XCTAssertEqual(response.sales.count, 1)
        XCTAssertEqual(response.sales[0].id, "sale_1")
        XCTAssertEqual(response.sales[0].status, "closed")
        XCTAssertEqual(response.total, 1)
        XCTAssertEqual(response.hasMore, false)
    }

    func testDecodesSalesHistoryResponseFromItemsKey() throws {
        let json = #"""
        {
          "items": [
            {
              "_id": "sale_2",
              "status": "confirmed",
              "paymentStatus": "unpaid",
              "documentStatus": "not_required",
              "totals": {
                "subtotalWithoutTaxes": { "amount": "20.00", "currency": "USD" },
                "discountTotal": { "amount": "0.00", "currency": "USD" },
                "taxTotal": { "amount": "3.00", "currency": "USD" },
                "grandTotal": { "amount": "23.00", "currency": "USD" }
              }
            }
          ]
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessSalesHistoryResponse.self,
            from: json
        )

        XCTAssertEqual(response.sales.count, 1)
        XCTAssertEqual(response.sales[0].id, "sale_2")
        XCTAssertEqual(response.sales[0].status, "confirmed")
    }
}
