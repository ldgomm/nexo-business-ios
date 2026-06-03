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

    func testPermissionGateSupportsWildcard() {
        let gate = PermissionGate(effectivePermissions: ["*"])

        XCTAssertTrue(gate.allows("sales.create"))
        XCTAssertTrue(gate.allows("cash.session.view_current"))
        XCTAssertFalse(gate.allows(""))
    }

    func testPermissionGateAllowsAnyCandidate() {
        let gate = PermissionGate(effectivePermissions: ["cash.session.open"])

        XCTAssertTrue(gate.allowsAny(["business.cash.open", "cash.session.open"]))
        XCTAssertFalse(gate.allowsAny(["sales.create", "sales.preview"]))
    }

    func testBusinessCapabilityGateUsesDecodedCapabilities() {
        let gate = BusinessCapabilityGate(
            capabilities: BusinessCapabilities(
                sales: SalesCapabilities(canView: true, canCreate: true),
                cash: CashCapabilities(canViewCurrent: true),
                reports: ReportCapabilities(canViewToday: true),
                customers: CustomerCapabilities(canView: true)
            )
        )

        XCTAssertTrue(gate.canAccessSales)
        XCTAssertTrue(gate.canAccessCash)
        XCTAssertTrue(gate.canAccessToday)
        XCTAssertTrue(gate.canAccessHistory)
        XCTAssertTrue(gate.canAccessCustomers)
        XCTAssertFalse(gate.canAccessInventory)
    }

    func testFallbackCapabilitiesPreserveLegacyBusinessPermissions() {
        let capabilities = BusinessCapabilities.fallback(
            activeModules: [.coreSales, .coreCash],
            effectivePermissions: [
                "business.sales.preview",
                "business.cash.view_current",
                "business.cash.open",
                "business.reports.today",
                "business.customers.create"
            ]
        )
        let gate = BusinessCapabilityGate(capabilities: capabilities)

        XCTAssertTrue(capabilities.sales.canPreview)
        XCTAssertTrue(capabilities.cash.canViewCurrent)
        XCTAssertTrue(capabilities.cash.canOpen)
        XCTAssertTrue(capabilities.reports.canViewToday)
        XCTAssertTrue(capabilities.customers.canCreate)
        XCTAssertTrue(gate.canAccessSales)
        XCTAssertTrue(gate.canAccessCash)
        XCTAssertTrue(gate.canAccessToday)
        XCTAssertTrue(gate.canAccessCustomers)
    }
}
