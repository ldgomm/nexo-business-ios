import XCTest
@testable import Nexo_Business

final class GatesTests: XCTestCase {
    func testModuleGateAllowsOnlyActiveModules() {
        let gate = ModuleGate(activeModules: [.coreSales])

        XCTAssertTrue(gate.allows(.coreSales))
        XCTAssertFalse(gate.allows(.coreCash))
    }

    func testPermissionGateAllowsOnlyEffectivePermissions() {
        let gate = PermissionGate(
            effectivePermissions: ["business.sales.create"]
        )

        XCTAssertTrue(gate.allows("business.sales.create"))
        XCTAssertFalse(gate.allows("cash.close"))
    }

    func testPermissionGateAllowsWildcard() {
        let gate = PermissionGate(effectivePermissions: ["*"])

        XCTAssertTrue(gate.allows("cash.session.open"))
        XCTAssertTrue(gate.allows("payments.collect"))
    }

    func testCapabilityGateUsesBusinessCapabilities() {
        let gate = BusinessCapabilityGate(
            capabilities: BusinessCapabilities(
                sales: SalesCapabilities(canView: true, canCreate: true),
                cash: CashCapabilities(canOpen: true),
                payments: PaymentCapabilities(),
                receivables: ReceivableCapabilities(),
                documents: DocumentCapabilities(),
                reports: ReportCapabilities(),
                catalog: CatalogCapabilities(),
                customers: CustomerCapabilities(),
                inventory: InventoryCapabilities()
            )
        )

        XCTAssertTrue(gate.canAccessSales)
        XCTAssertTrue(gate.canAccessCash)
        XCTAssertFalse(gate.canAccessInventory)
    }
}
