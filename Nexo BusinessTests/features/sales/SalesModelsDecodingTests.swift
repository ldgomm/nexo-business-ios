//
//  SalesModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class SalesModelsDecodingTests: XCTestCase {
    func testDecodesSaleDetailEnvelope() throws {
        let json = #"""
        {
          "sale": {
            "id": "sale_1",
            "organizationId": "org_1",
            "branchId": "br_1",
            "activityId": "act_1",
            "status": "pending",
            "paymentStatus": "unpaid",
            "documentStatus": "not_required",
            "totals": {
              "subtotalWithoutTaxes": { "amount": "10.00", "currency": "USD" },
              "discountTotal": { "amount": "0.00", "currency": "USD" },
              "taxTotal": { "amount": "1.50", "currency": "USD" },
              "grandTotal": { "amount": "11.50", "currency": "USD" }
            },
            "items": []
          }
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessSaleDetailResponse.self,
            from: json
        )

        XCTAssertEqual(response.sale.id, "sale_1")
        XCTAssertEqual(response.sale.status, "pending")
        XCTAssertEqual(response.sale.totals.grandTotal.amount, "11.50")
    }

    func testDecodesSaleDetailFromRootObject() throws {
        let json = #"""
        {
          "id": "sale_2",
          "organizationId": "org_1",
          "branchId": "br_1",
          "activityId": "act_1",
          "status": "confirmed",
          "paymentStatus": "unpaid",
          "documentStatus": "not_required",
          "totals": {
            "subtotalWithoutTaxes": { "amount": "10.00", "currency": "USD" },
            "discountTotal": { "amount": "0.00", "currency": "USD" },
            "taxTotal": { "amount": "1.50", "currency": "USD" },
            "grandTotal": { "amount": "11.50", "currency": "USD" }
          },
          "items": []
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(
            BusinessSaleDetailResponse.self,
            from: json
        )

        XCTAssertEqual(response.sale.id, "sale_2")
        XCTAssertEqual(response.sale.status, "confirmed")
    }
}
