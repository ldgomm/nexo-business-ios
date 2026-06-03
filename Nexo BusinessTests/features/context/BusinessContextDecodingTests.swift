import XCTest
@testable import Nexo_Business

final class BusinessContext16CDecodingTests: XCTestCase {
    func testDecodesBackendRealContextShapeAndComputesCompatibilityFields() throws {
        let json = #"""
        {
          "user": { "id": "usr_1", "displayName": "Operador", "email": "op@nexo.test" },
          "organization": {
            "id": "org_1",
            "commercialName": "Altos del Murco",
            "legalName": "Altos del Murco",
            "taxId": "1790000000001",
            "countryCode": "EC"
          },
          "branches": [
            { "id": "br_1", "name": "Matriz", "code": "001", "status": "active" }
          ],
          "activeBranchId": "br_1",
          "activities": [
            {
              "id": "act_1",
              "activityType": "restaurant",
              "workflowMode": "quick_sale",
              "status": "active",
              "requiresScheduling": false
            }
          ],
          "activeModules": ["core.sales", "core.cash"],
          "effectivePermissions": ["sales.create", "cash.open"],
          "catalogRevision": "catrev_1",
          "taxConfigurationRevision": "taxrev_1",
          "moduleReadiness": {
            "core.sales": { "status": "ready", "blockers": [], "warnings": [] }
          },
          "environment": "staging",
          "serverTime": "2026-05-29T00:00:00Z"
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(BusinessContextResponse.self, from: json)

        XCTAssertEqual(context.activeBranchId, "br_1")
        XCTAssertEqual(context.revisions.catalogRevision, "catrev_1")
        XCTAssertEqual(context.revisions.taxConfigurationRevision, "taxrev_1")
        XCTAssertEqual(context.readiness.status, "ready")
        XCTAssertEqual(context.activities.first?.code, "restaurant")
        XCTAssertEqual(context.activities.first?.name, "Restaurant")
        XCTAssertTrue(context.capabilities.sales.canCreate)
        XCTAssertTrue(context.capabilities.sales.canPreview)
        XCTAssertTrue(context.capabilities.cash.canOpen)
        XCTAssertFalse(context.capabilities.cash.canClose)
    }

    func testDecodesBackend17GBusinessCapabilities() throws {
        let json = #"""
        {
          "user": { "id": "usr_1", "displayName": "Cajero", "email": "cashier@nexo.test" },
          "organization": {
            "id": "org_1",
            "commercialName": "Altos del Murco",
            "legalName": "Altos del Murco",
            "taxId": "1790000000001",
            "countryCode": "EC"
          },
          "branches": [
            { "id": "br_1", "name": "Matriz", "code": "001", "status": "active" }
          ],
          "activities": [
            {
              "id": "act_1",
              "activityType": "restaurant",
              "workflowMode": "quick_sale",
              "status": "active"
            }
          ],
          "activeModules": ["core.sales", "core.cash", "core.reports", "core.customers"],
          "effectivePermissions": ["sales.create", "cash.session.open", "reports.dashboard.view", "customers.view"],
          "capabilities": {
            "sales": {
              "canView": true,
              "canCreate": true,
              "canPreview": true,
              "canConfirm": true,
              "canCancel": false
            },
            "cash": {
              "canViewCurrent": true,
              "canViewHistory": false,
              "canOpen": true,
              "canClose": true,
              "canRegisterInflow": true,
              "canRegisterOutflow": false,
              "canAdjust": false
            },
            "payments": {
              "canView": true,
              "canCollect": true,
              "canRegister": true,
              "canMarkAsCredit": true,
              "canRefund": false,
              "canReverse": false
            },
            "receivables": {
              "canView": true,
              "canCreate": false,
              "canRegisterPayment": false,
              "canCollect": false
            },
            "documents": {
              "canView": true,
              "canGenerateInternalTicket": true,
              "canRegisterPhysicalSaleNote": true,
              "canIssueElectronicInvoice": false,
              "canDownloadPdf": false,
              "canDownloadXml": false
            },
            "reports": {
              "canViewDashboard": true,
              "canViewToday": true,
              "canViewSales": true,
              "canViewCash": true,
              "canViewTax": false,
              "canViewDocuments": true
            },
            "catalog": {
              "canView": true,
              "canManageLocal": false,
              "canChangePrice": false,
              "canChangeTaxProfile": false
            },
            "customers": {
              "canView": true,
              "canCreate": false,
              "canUpdate": false
            },
            "inventory": {
              "canView": false,
              "canViewMovements": false,
              "canAdjust": false
            }
          },
          "revisions": {
            "catalogRevision": "catrev_altos_staging_1",
            "taxConfigurationRevision": "taxrev_altos_staging_3"
          },
          "readiness": {
            "status": "ready",
            "score": 100,
            "blockers": [],
            "warnings": []
          }
        }
        """#.data(using: .utf8)!

        let context = try JSONDecoder.nexoDefault.decode(BusinessContextResponse.self, from: json)
        let gate = BusinessCapabilityGate(capabilities: context.capabilities)

        XCTAssertEqual(context.revisions.catalogRevision, "catrev_altos_staging_1")
        XCTAssertEqual(context.revisions.taxConfigurationRevision, "taxrev_altos_staging_3")
        XCTAssertTrue(context.capabilities.sales.canCreate)
        XCTAssertTrue(context.capabilities.cash.canOpen)
        XCTAssertTrue(context.capabilities.cash.canClose)
        XCTAssertTrue(context.capabilities.documents.canGenerateInternalTicket)
        XCTAssertTrue(context.capabilities.reports.canViewToday)
        XCTAssertTrue(context.capabilities.customers.canView)
        XCTAssertFalse(context.capabilities.inventory.canView)
        XCTAssertTrue(gate.canAccessSales)
        XCTAssertTrue(gate.canAccessCash)
        XCTAssertTrue(gate.canAccessToday)
        XCTAssertTrue(gate.canAccessHistory)
        XCTAssertTrue(gate.canAccessCustomers)
        XCTAssertFalse(gate.canAccessInventory)
    }
}
