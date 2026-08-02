//
//  BusinessFinanceControlSourceContractTests.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation
import XCTest
@testable import Nexo_Business

class BusinessFinanceControlSourceContractTests: XCTestCase {
    func testAllSafeFinanceSurfacesRemainDeclared() {
        XCTAssertEqual(
            Set(BusinessFinanceControlSurface.allCases),
            Set([
                .configuration,
                .movements,
                .receivablesAndPayables,
                .cashAndBank,
                .historicalImport,
                .reconciliation,
                .coverageAndCutover,
                .unresolvedItems
            ])
        )
    }

    func testFinanceControlSourceHasNoCountryDefaultsOrLocalTotals() throws {
        let repositoryRoot = try locateRepositoryRoot()
        let featureRoot = repositoryRoot
            .appendingPathComponent("Nexo Business")
            .appendingPathComponent("features")
            .appendingPathComponent("financecontrol")

        let source = try swiftSource(in: featureRoot)
        let forbidden = [
            "America/Guayaquil",
            "\"USD\"",
            "\"$\"",
            "country == ",
            ".reduce(",
            "authoritativeAccounting: true"
        ]

        for token in forbidden {
            XCTAssertFalse(
                source.contains(token),
                "Forbidden finance UX token: \(token)"
            )
        }

        XCTAssertTrue(source.contains("OPERATIONAL_NOT_POSTED"))
        XCTAssertTrue(source.contains("runtimeEndpointUnavailable"))
        XCTAssertTrue(source.contains("/api/v1/business/finance/control/snapshot"))
        XCTAssertTrue(source.contains("maskedExternalReference"))
    }

    func testBusinessHomeUsesPermissionAwareFinanceNavigation() throws {
        let repositoryRoot = try locateRepositoryRoot()
        let businessView = repositoryRoot
            .appendingPathComponent("Nexo Business")
            .appendingPathComponent("features/business/presentation/BusinessView.swift")
        let source = try String(contentsOf: businessView, encoding: .utf8)

        XCTAssertTrue(source.contains("financeControlAccessPolicy.canViewSurface"))
        XCTAssertTrue(source.contains("container.financeControlRepository"))
        XCTAssertFalse(source.contains("BusinessFinanceControlDeferredRepository()"))
        XCTAssertTrue(source.contains("Operativo · no contabilizado"))
    }

    private func locateRepositoryRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()

        for _ in 0..<8 {
            let businessDirectory = candidate.appendingPathComponent("Nexo Business")
            if FileManager.default.fileExists(atPath: businessDirectory.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }

        throw NSError(
            domain: "BusinessFinanceControlSourceContractTests",
            code: 1
        )
    }

    private func swiftSource(in root: URL) throws -> String {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: nil
        ) else {
            throw NSError(
                domain: "BusinessFinanceControlSourceContractTests",
                code: 2
            )
        }

        var source = ""
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            source += try String(contentsOf: fileURL, encoding: .utf8)
            source.append("\n")
        }
        return source
    }
}

