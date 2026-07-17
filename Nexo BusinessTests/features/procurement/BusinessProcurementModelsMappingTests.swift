//
//  BusinessProcurementModelsMappingTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

final class BusinessProcurementModelsMappingTests: XCTestCase {
    func testSupplierDecodesRedactedSensitiveFieldsWithoutInventingValues() throws {
        let response = try decode(
            BusinessProcurementSupplierEnvelopeResponse.self,
            json: #"""
            {
              "data": {
                "id": "sup_1",
                "legalName": "Proveedor Uno S.A.",
                "tradeName": "Proveedor Uno",
                "identificationType": "RUC",
                "identificationNumber": null,
                "email": null,
                "phone": null,
                "address": null,
                "categories": ["hardware"],
                "contacts": null,
                "paymentTerms": {"mode":"NET_DAYS","netDays":30,"label":"30 días","notes":null},
                "defaultCurrency": "USD",
                "status": "ACTIVE",
                "notes": null,
                "createdAt": "2026-07-01T12:00:00Z",
                "createdBy": "usr_1",
                "updatedAt": "2026-07-02T12:00:00Z",
                "updatedBy": "usr_2",
                "version": 4
              },
              "meta": {"requestId":"req_1","idempotencyReplayed":false}
            }
            """#
        )

        XCTAssertEqual(response.data.id, "sup_1")
        XCTAssertEqual(response.data.status, .active)
        XCTAssertNil(response.data.identificationNumber)
        XCTAssertNil(response.data.contacts)
        XCTAssertEqual(response.data.paymentTerms.netDays, 30)
        XCTAssertEqual(response.data.version, 4)
        XCTAssertEqual(response.meta.requestId, "req_1")
    }

    func testPurchaseOrderKeepsBackendQuantitiesAndAllowsRedactedCosts() throws {
        let response = try decode(
            BusinessProcurementPurchaseOrderEnvelopeResponse.self,
            json: #"""
            {
              "data": {
                "id": "po_1",
                "branchId": "br_1",
                "supplierId": "sup_1",
                "orderNumber": "OC-0001",
                "status": "PARTIALLY_RECEIVED",
                "currency": "USD",
                "lines": [{
                  "id": "pol_1",
                  "kind": "CATALOG_ITEM",
                  "catalogItemId": "item_1",
                  "catalogItemSnapshot": {"catalogItemId":"item_1","localName":"Router","sku":"RTR-1","unitCode":"UNIT","taxProfileId":"tax_1","taxProfileVersion":3},
                  "descriptionSnapshot": "Router",
                  "orderedQuantity": {"value":"5.000","unitCode":"UNIT","allowsDecimal":false},
                  "receivedQuantity": "2.000",
                  "unitCost": null,
                  "discountAmount": null,
                  "priceTaxMode": "TAX_EXCLUSIVE",
                  "taxProfileId": "tax_1",
                  "taxProfileVersion": 3,
                  "taxes": null,
                  "grossAmount": null,
                  "netAmount": null,
                  "taxAmount": null,
                  "lineTotal": null,
                  "targetWarehouseId": "wh_1",
                  "notes": null
                }],
                "subtotal": null,
                "discountTotal": null,
                "taxTotal": null,
                "total": null,
                "expectedDate": "2026-07-20",
                "supplierSnapshot": {"supplierId":"sup_1","legalName":"Proveedor Uno S.A.","tradeName":null,"identificationType":"RUC","identificationNumber":null,"paymentTerms":{"mode":"IMMEDIATE","netDays":0,"label":null,"notes":null},"defaultCurrency":"USD"},
                "paymentTermsSnapshot": {"mode":"IMMEDIATE","netDays":0,"label":null,"notes":null},
                "notes": null,
                "attachmentIds": [],
                "createdAt": "2026-07-01T12:00:00Z",
                "createdBy": "usr_1",
                "updatedAt": "2026-07-02T12:00:00Z",
                "updatedBy": "usr_1",
                "sentAt": "2026-07-01T13:00:00Z",
                "sentBy": "usr_1",
                "closedAt": null,
                "closedBy": null,
                "closeReason": null,
                "cancelledAt": null,
                "cancelledBy": null,
                "cancellationReason": null,
                "version": 6
              },
              "meta": {"requestId":"req_po","idempotencyReplayed":null}
            }
            """#
        )

        XCTAssertEqual(response.data.status, .partiallyReceived)
        XCTAssertEqual(response.data.lines[0].orderedQuantity.value, "5.000")
        XCTAssertEqual(response.data.lines[0].receivedQuantity, "2.000")
        XCTAssertNil(response.data.lines[0].unitCost)
        XCTAssertNil(response.data.total)
        XCTAssertEqual(response.data.version, 6)
    }

    func testReceiptKeepsReceivedAcceptedRejectedAndInventoryEvidenceSeparate() throws {
        let response = try decode(
            BusinessProcurementPurchaseReceiptEnvelopeResponse.self,
            json: #"""
            {
              "data": {
                "id":"prcpt_1","branchId":"br_1","supplierId":"sup_1","purchaseOrderId":"po_1",
                "receiptNumber":"RC-0001","status":"CONFIRMED","warehouseId":"wh_1","receivedAt":"2026-07-03T15:00:00Z",
                "lines":[{"id":"prl_1","purchaseOrderLineId":"pol_1","kind":"CATALOG_ITEM","catalogItemId":"item_1","itemSnapshot":null,"receivedQuantity":{"value":"3","unitCode":"UNIT","allowsDecimal":false},"acceptedQuantity":"2","rejectedQuantity":"1","unitCode":"UNIT","unitCost":null,"warehouseId":"wh_1","trackedUnits":[],"inventoryMovementId":"imov_1","notes":"Una unidad dañada"}],
                "inventoryMovementIds":["imov_1"],"attachmentIds":[],"notes":null,
                "createdAt":"2026-07-03T14:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-03T15:01:00Z","updatedBy":"usr_1",
                "confirmedAt":"2026-07-03T15:01:00Z","confirmedBy":"usr_1","cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":2
              },
              "meta":{"requestId":"req_rcpt","idempotencyReplayed":false}
            }
            """#
        )

        let line = try XCTUnwrap(response.data.lines.first)
        XCTAssertEqual(response.data.status, .confirmed)
        XCTAssertEqual(line.receivedQuantity.value, "3")
        XCTAssertEqual(line.acceptedQuantity, "2")
        XCTAssertEqual(line.rejectedQuantity, "1")
        XCTAssertEqual(line.inventoryMovementId, "imov_1")
        XCTAssertEqual(response.data.inventoryMovementIds, ["imov_1"])
    }

    func testSupplierDocumentEnvelopePreservesDocumentDuePaymentAndPayableFacts() throws {
        let response = try decode(
            BusinessProcurementSupplierDocumentEnvelopeResponse.self,
            json: #"""
            {
              "data": {
                "id":"sdoc_1","branchId":"br_1","supplierId":"sup_1","documentType":"INVOICE","status":"CONFIRMED",
                "documentNumber":"001-001-123","documentNumberNormalized":"001001123","accessKey":null,"authorizationNumber":null,
                "documentDate":"2026-07-04","dueDate":"2026-08-03","currency":"USD","purchaseOrderIds":["po_1"],"purchaseReceiptIds":["prcpt_1"],"lines":[],
                "subtotal":{"amount":"100.00","currency":"USD"},"discountTotal":{"amount":"0.00","currency":"USD"},"taxTotal":{"amount":"15.00","currency":"USD"},"total":{"amount":"115.00","currency":"USD"},
                "sourceTotals":{"total":{"amount":"115.00","currency":"USD"},"taxTotal":{"amount":"15.00","currency":"USD"}},
                "sourcePayment":{"amount":{"amount":"15.00","currency":"USD"},"method":"CASH","paymentDate":"2026-07-04","reference":"REC-1"},
                "payableAmount":{"amount":"100.00","currency":"USD"},"payableId":"pay_1","attachmentIds":["patt_1"],"accountingStatus":"OPERATIONAL_ONLY","notes":null,
                "createdAt":"2026-07-04T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-04T12:01:00Z","updatedBy":"usr_1",
                "confirmedAt":"2026-07-04T12:01:00Z","confirmedBy":"usr_1","cancelledAt":null,"cancelledBy":null,"cancellationReason":null,"version":2
              },
              "payable": {
                "id":"pay_1","branchId":"br_1","supplierId":"sup_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","currency":"USD",
                "originalAmount":{"amount":"100.00","currency":"USD"},"paidAmount":{"amount":"0.00","currency":"USD"},"balance":{"amount":"100.00","currency":"USD"},
                "dueDate":"2026-08-03","settlementStatus":"OPEN","effectiveStatus":"OPEN","allocationIds":[],
                "createdAt":"2026-07-04T12:01:00Z","createdBy":"usr_1","updatedAt":"2026-07-04T12:01:00Z","updatedBy":"usr_1","version":1
              },
              "meta":{"requestId":"req_doc","idempotencyReplayed":false}
            }
            """#
        )

        XCTAssertEqual(response.data.documentDate, "2026-07-04")
        XCTAssertEqual(response.data.dueDate, "2026-08-03")
        XCTAssertEqual(response.data.sourcePayment?.paymentDate, "2026-07-04")
        XCTAssertEqual(response.data.payableAmount.amount, "100.00")
        XCTAssertEqual(response.payable?.balance.amount, "100.00")
        XCTAssertEqual(response.payable?.effectiveStatus, .open)
    }

    func testSupplierPaymentKeepsAllocationBeforeAfterEvidenceAndOptionalSensitiveFields() throws {
        let response = try decode(
            BusinessProcurementSupplierPaymentEnvelopeResponse.self,
            json: #"""
            {
              "data": {
                "id":"spay_1","branchId":"br_1","supplierId":"sup_1","paymentNumber":"PP-0001","paymentDate":"2026-07-05","currency":"USD",
                "amount":{"amount":"40.00","currency":"USD"},"method":null,"reference":null,"status":"RECORDED",
                "allocations":[{"id":"alloc_1","payableId":"pay_1","amount":{"amount":"40.00","currency":"USD"},"payableBalanceBefore":{"amount":"100.00","currency":"USD"},"payableBalanceAfter":{"amount":"60.00","currency":"USD"},"status":"APPLIED","createdAt":"2026-07-05T12:00:00Z","createdBy":"usr_1","reversedAt":null,"reversedBy":null,"reversalReason":null}],
                "attachmentIds":null,"cashMovementId":null,"notes":null,"createdAt":"2026-07-05T12:00:00Z","createdBy":"usr_1","updatedAt":"2026-07-05T12:00:00Z","updatedBy":"usr_1",
                "recordedAt":"2026-07-05T12:00:00Z","recordedBy":"usr_1","voidedAt":null,"voidedBy":null,"voidReason":null,"version":1
              },
              "meta":{"requestId":"req_payment","idempotencyReplayed":false}
            }
            """#
        )

        XCTAssertEqual(response.data.status, .recorded)
        XCTAssertNil(response.data.method)
        XCTAssertNil(response.data.attachmentIds)
        XCTAssertEqual(response.data.allocations[0].payableBalanceBefore.amount, "100.00")
        XCTAssertEqual(response.data.allocations[0].payableBalanceAfter.amount, "60.00")
    }

    func testStatementAndAttachmentDecodeCanonicalAuditAndEvidenceFields() throws {
        let statement = try decode(
            BusinessProcurementSupplierStatementResponse.self,
            json: #"""
            {
              "supplierId":"sup_1","branchId":"br_1","currency":"USD","from":"2026-07-01","to":"2026-07-31","asOf":"2026-07-31",
              "openingBalance":{"amount":"0.00","currency":"USD"},
              "lines":[{"id":"stmt_1","occurredAt":"2026-07-04T12:01:00Z","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","description":"Factura 001-001-123","charge":{"amount":"100.00","currency":"USD"},"credit":{"amount":"0.00","currency":"USD"},"runningBalance":{"amount":"100.00","currency":"USD"},"currency":"USD","auditResourceType":"supplier_document","auditResourceId":"sdoc_1"}],
              "closingBalance":{"amount":"100.00","currency":"USD"},"nextCursor":null,"hasMore":false
            }
            """#
        )
        let attachment = try decode(
            BusinessProcurementAttachmentEnvelopeResponse.self,
            json: #"""
            {"data":{"id":"patt_1","sourceType":"SUPPLIER_DOCUMENT","sourceId":"sdoc_1","fileName":"factura.pdf","mediaType":"application/pdf","sizeBytes":1024,"checksumSha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","uploadedAt":"2026-07-04T12:00:00Z","uploadedBy":"usr_1","version":1},"meta":{"requestId":"req_att","idempotencyReplayed":false}}
            """#
        )

        XCTAssertEqual(statement.lines[0].runningBalance.amount, "100.00")
        XCTAssertEqual(statement.lines[0].auditResourceType, "supplier_document")
        XCTAssertEqual(attachment.data.sourceType, .supplierDocument)
        XCTAssertEqual(attachment.data.sizeBytes, 1024)
    }

    func testWriteRequestEncodesDecimalStringsAndNumericVersionExactly() throws {
        let request = BusinessProcurementPurchaseOrderWriteRequest(
            branchId: "br_1",
            supplierId: "sup_1",
            currency: "USD",
            lines: [
                BusinessProcurementPurchaseOrderLineRequest(
                    id: "pol_1",
                    kind: "CATALOG_ITEM",
                    catalogItemId: "item_1",
                    description: nil,
                    orderedQuantity: "2.500",
                    unitCode: "KG",
                    allowsDecimal: true,
                    unitCost: "10.1250",
                    discountAmount: "0.25",
                    priceTaxMode: "TAX_EXCLUSIVE",
                    taxProfileId: "tax_1",
                    targetWarehouseId: "wh_1",
                    notes: nil
                )
            ],
            expectedDate: "2026-07-20",
            notes: nil,
            attachmentIds: [],
            expectedVersion: 7
        )

        let encoded = try JSONEncoder.nexoDefault.encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let lines = try XCTUnwrap(object["lines"] as? [[String: Any]])

        XCTAssertEqual(lines[0]["orderedQuantity"] as? String, "2.500")
        XCTAssertEqual(lines[0]["unitCost"] as? String, "10.1250")
        XCTAssertEqual(lines[0]["discountAmount"] as? String, "0.25")
        XCTAssertEqual(object["expectedVersion"] as? Int, 7)
        XCTAssertFalse(object["expectedVersion"] is String)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, json: String) throws -> Value {
        try JSONDecoder.nexoDefault.decode(type, from: Data(json.utf8))
    }
}
