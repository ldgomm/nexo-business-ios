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

    func testEncodesPreviewRequestUsingBackendQuantityContract() throws {
        let request = SalesPreviewRequest(
            branchId: "br_1",
            activityId: "act_1",
            catalogRevision: "cat_rev_1",
            taxConfigurationRevision: "tax_rev_1",
            items: [
                BusinessSaleItemRequest(
                    catalogItemId: "item_1",
                    quantity: BusinessSaleQuantityRequest(
                        value: "3",
                        unitCode: "unit",
                        allowsDecimal: false
                    )
                )
            ]
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let items = object?["items"] as? [[String: Any]]
        let quantity = items?.first?["quantity"] as? [String: Any]

        XCTAssertEqual(object?["branchId"] as? String, "br_1")
        XCTAssertEqual(object?["activityId"] as? String, "act_1")
        XCTAssertEqual(object?["catalogRevision"] as? String, "cat_rev_1")
        XCTAssertEqual(object?["taxConfigurationRevision"] as? String, "tax_rev_1")
        XCTAssertEqual(items?.first?["catalogItemId"] as? String, "item_1")
        XCTAssertEqual(quantity?["value"] as? String, "3")
        XCTAssertEqual(quantity?["unitCode"] as? String, "unit")
        XCTAssertEqual(quantity?["allowsDecimal"] as? Bool, false)
        XCTAssertEqual(items?.first?["priceTaxMode"] as? String, BusinessSalePriceTaxMode.taxExclusive.rawValue)
    }

}
