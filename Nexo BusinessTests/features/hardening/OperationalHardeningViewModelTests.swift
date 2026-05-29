//
//  OperationalHardeningViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class OperationalHardeningViewModelTests: XCTestCase {
    func testReadyContextProducesNoBlockers() async throws {
        let viewModel = OperationalHardeningViewModel(
            context: makeContext(readinessStatus: "ready"),
            operationalSelection: makeSelection(),
            tokenStore: InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token")),
            networkStatusProvider: StaticNetworkStatusProvider(status: .satisfied)
        )

        await viewModel.run()

        guard case let .loaded(report) = viewModel.state else {
            return XCTFail("Expected loaded report")
        }

        XCTAssertTrue(report.isReadyForPilot)
        XCTAssertTrue(report.blockers.isEmpty)
    }

    func testMissingTokenIsBlocking() async throws {
        let viewModel = OperationalHardeningViewModel(
            context: makeContext(readinessStatus: "ready"),
            operationalSelection: makeSelection(),
            tokenStore: InMemoryAuthTokenStore(tokens: nil),
            networkStatusProvider: StaticNetworkStatusProvider(status: .satisfied)
        )

        await viewModel.run()

        guard case let .loaded(report) = viewModel.state else {
            return XCTFail("Expected loaded report")
        }

        XCTAssertFalse(report.isReadyForPilot)
        XCTAssertTrue(report.blockers.contains { $0.id == "session-token" })
    }

    func testInvalidOperationalSelectionIsBlocking() async throws {
        let viewModel = OperationalHardeningViewModel(
            context: makeContext(readinessStatus: "ready"),
            operationalSelection: BusinessOperationalSelection(
                organizationId: "org_1",
                branchId: "missing_branch",
                activityId: "act_1"
            ),
            tokenStore: InMemoryAuthTokenStore(tokens: AuthTokens(accessToken: "token")),
            networkStatusProvider: StaticNetworkStatusProvider(status: .satisfied)
        )

        await viewModel.run()

        guard case let .loaded(report) = viewModel.state else {
            return XCTFail("Expected loaded report")
        }

        XCTAssertFalse(report.isReadyForPilot)
        XCTAssertTrue(report.blockers.contains { $0.id == "operational-selection" })
    }

    private func makeSelection() -> BusinessOperationalSelection {
        BusinessOperationalSelection(
            organizationId: "org_1",
            branchId: "br_1",
            activityId: "act_1"
        )
    }

    private func makeContext(readinessStatus: String) -> BusinessContextResponse {
        BusinessContextResponse(
            user: BusinessUser(
                id: "usr_1",
                displayName: "Operador",
                email: "op@nexo.test"
            ),
            organization: BusinessOrganization(
                id: "org_1",
                commercialName: "Altos del Murco",
                legalName: "Altos del Murco",
                taxId: "9999999999999",
                countryCode: "EC"
            ),
            branches: [
                BusinessBranch(
                    id: "br_1",
                    name: "Matriz",
                    code: "001",
                    status: "active"
                )
            ],
            activities: [
                BusinessActivity(
                    id: "act_1",
                    code: "restaurant",
                    name: "Restaurante",
                    activityType: "restaurant",
                    workflowMode: "quick_sale",
                    status: "active"
                )
            ],
            activeModules: [.coreSales, .coreCash, .coreDocuments],
            effectivePermissions: [
                "business.sales.create",
                "business.cash.view_current",
                "business.payments.collect",
                "business.documents.view"
            ],
            revisions: BusinessRevisions(
                catalogRevision: "cat_rev_1",
                taxConfigurationRevision: "tax_rev_1"
            ),
            readiness: BusinessReadiness(
                status: readinessStatus,
                score: readinessStatus == "ready" ? 100 : 60,
                blockers: readinessStatus == "ready" ? [] : ["readiness_not_ready"],
                warnings: []
            )
        )
    }
}
