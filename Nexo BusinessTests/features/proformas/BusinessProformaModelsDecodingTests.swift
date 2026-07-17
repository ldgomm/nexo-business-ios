//
//  BusinessProformaModelsDecodingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

final class BusinessProformaModelsDecodingTests: XCTestCase {
    func testDecodesProformaResponseContract() throws {
        let json = #"""
        {
          "id": "proforma_1",
          "organizationId": "org_1",
          "branchId": "br_1",
          "activityId": "act_1",
          "proformaNumber": "PFM-202606-000001",
          "status": "ACCEPTED",
          "issueDate": "2026-06-25",
          "validUntil": "2026-06-30",
          "currency": "USD",
          "customerId": "cus_1",
          "customerSnapshot": {
            "customerId": "cus_1",
            "displayName": "Cliente prueba",
            "identification": "1717171717",
            "email": "cliente@nexo.test",
            "phone": "0999999999",
            "address": "Quito"
          },
          "lines": [
            {
              "lineId": "line_1",
              "productId": "item_staging_cuy_entero",
              "sku": "CUY",
              "displayName": "Cuy entero",
              "quantity": "1.00",
              "unitPrice": "24.00",
              "rawSubtotal": "24.00",
              "discountAmount": "0.00",
              "netSubtotal": "24.00",
              "taxAmount": "3.60",
              "grandTotal": "27.60",
              "notes": ""
            }
          ],
          "totals": {
            "subtotal": "24.00",
            "discountTotal": "0.00",
            "taxTotal": "3.60",
            "grandTotal": "27.60"
          },
          "notes": "Smoke",
          "terms": "No es factura",
          "sourceContext": "business-ios",
          "convertedSaleId": null,
          "nonFiscalLegend": "PROFORMA - NO ES FACTURA",
          "isFiscalDocument": false,
          "hasSriAuthorization": false,
          "sriAuthorizationNumber": null,
          "accessKey": null,
          "rideUrl": null,
          "xmlUrl": null,
          "createdAt": "2026-06-25T12:00:00Z",
          "updatedAt": "2026-06-25T12:00:00Z"
        }
        """#.data(using: .utf8)!

        let proforma = try JSONDecoder.nexoDefault.decode(BusinessProforma.self, from: json)

        XCTAssertEqual(proforma.id, "proforma_1")
        XCTAssertEqual(proforma.proformaNumber, "PFM-202606-000001")
        XCTAssertEqual(proforma.status, .accepted)
        XCTAssertEqual(proforma.customerDisplayName, "Cliente prueba")
        XCTAssertEqual(proforma.lines.first?.productId, "item_staging_cuy_entero")
        XCTAssertEqual(proforma.totals.grandTotal, "27.60")
        XCTAssertTrue(proforma.canConvertToSale)
        XCTAssertFalse(proforma.isFiscalDocument)
        XCTAssertFalse(proforma.hasSriAuthorization)
        XCTAssertNil(proforma.rideUrl)
        XCTAssertNil(proforma.xmlUrl)
    }

    func testDecodesConvertToSaleResponseWithoutForbiddenSideEffects() throws {
        let json = #"""
        {
          "saleId": "sale_1",
          "wasAlreadyConverted": false,
          "createdPaymentId": null,
          "createdInvoiceId": null,
          "createdCashSessionId": null,
          "createdXmlUrl": null,
          "createdRideUrl": null,
          "calledSri": false
        }
        """#.data(using: .utf8)!

        let response = try JSONDecoder.nexoDefault.decode(BusinessProformaConvertToSaleResponse.self, from: json)

        XCTAssertEqual(response.saleId, "sale_1")
        XCTAssertFalse(response.wasAlreadyConverted)
        XCTAssertFalse(response.hasForbiddenSideEffects)
    }

    func testEncodesCreateRequestUsingBackendContract() throws {
        let request = CreateBusinessProformaRequest(
            branchId: "br_1",
            activityId: "act_1",
            customerId: "cus_1",
            customerSnapshot: BusinessProformaCustomerSnapshot(
                customerId: "cus_1",
                displayName: "Cliente prueba",
                identification: "1717171717",
                email: "cliente@nexo.test"
            ),
            issueDate: "2026-06-25",
            validUntil: "2026-06-30",
            currency: "USD",
            lines: [
                BusinessProformaLineInput(
                    productId: "item_1",
                    displayName: "Producto",
                    quantity: "1",
                    unitPrice: "10.00",
                    discountAmount: "0.00",
                    taxAmount: "0.00"
                )
            ],
            notes: "Notas",
            terms: "No es factura",
            sourceContext: "business-ios"
        )

        let data = try JSONEncoder.nexoDefault.encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let lines = object?["lines"] as? [[String: Any]]

        XCTAssertEqual(object?["branchId"] as? String, "br_1")
        XCTAssertEqual(object?["activityId"] as? String, "act_1")
        XCTAssertEqual(object?["customerId"] as? String, "cus_1")
        XCTAssertEqual(object?["issueDate"] as? String, "2026-06-25")
        XCTAssertEqual(lines?.first?["productId"] as? String, "item_1")
        XCTAssertEqual(lines?.first?["unitPrice"] as? String, "10.00")
    }
}
