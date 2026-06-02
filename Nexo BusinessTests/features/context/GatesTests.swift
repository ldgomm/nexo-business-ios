//
//  GatesTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

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
}
