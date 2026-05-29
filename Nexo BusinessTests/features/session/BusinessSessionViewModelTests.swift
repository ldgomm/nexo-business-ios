//
//  BusinessSessionViewModelTests.swift
//  Nexo BusinessTests
//
//  Created by José Ruiz on 29/5/26.
//

import XCTest
@testable import Nexo_Business

@MainActor
final class BusinessSessionViewModelTests: XCTestCase {
    func testBootstrapWithoutStoredTokensShowsLogin() async {
        let tokenStore = InMemoryAuthTokenStore()
        let repository = TestBusinessContextRepository(
            result: .success(SessionTestFixtures.context)
        )
        let viewModel = BusinessSessionViewModel(
            organizationId: SessionTestFixtures.context.organization.id,
            tokenStore: tokenStore,
            contextRepository: repository
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(viewModel.state, .signedOut())
        XCTAssertNil(viewModel.context)
    }

    func testBootstrapWithStoredTokensLoadsBusinessContext() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let repository = TestBusinessContextRepository(
            result: .success(SessionTestFixtures.context)
        )
        let viewModel = BusinessSessionViewModel(
            organizationId: SessionTestFixtures.context.organization.id,
            tokenStore: tokenStore,
            contextRepository: repository
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(viewModel.state, .signedIn(SessionTestFixtures.context))
        XCTAssertEqual(viewModel.context, SessionTestFixtures.context)
    }

    func testUnauthorizedContextClearsTokensAndReturnsToLogin() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "expired-token")
        )
        let repository = TestBusinessContextRepository(
            result: .failure(
                APIError.server(
                    statusCode: 401,
                    code: "unauthorized",
                    message: "Unauthorized",
                    requestId: "req_401"
                )
            )
        )
        let viewModel = BusinessSessionViewModel(
            organizationId: SessionTestFixtures.context.organization.id,
            tokenStore: tokenStore,
            contextRepository: repository
        )

        await viewModel.bootstrapIfNeeded()

        XCTAssertEqual(
            viewModel.state,
            .signedOut(message: "Tu sesión caducó. Vuelve a iniciar sesión.")
        )
        XCTAssertNil(viewModel.context)
        let storedTokens = await tokenStore.tokens()
        XCTAssertNil(storedTokens)
    }

    func testLogoutClearsTokensAndReturnsToLogin() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let repository = TestBusinessContextRepository(
            result: .success(SessionTestFixtures.context)
        )
        let viewModel = BusinessSessionViewModel(
            organizationId: SessionTestFixtures.context.organization.id,
            tokenStore: tokenStore,
            contextRepository: repository
        )

        await viewModel.bootstrapIfNeeded()
        await viewModel.logout()

        XCTAssertEqual(viewModel.state, .signedOut())
        XCTAssertNil(viewModel.context)
        let storedTokens = await tokenStore.tokens()
        XCTAssertNil(storedTokens)
    }

    func testRefreshContextKeepsSessionSignedIn() async {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(accessToken: "valid-token")
        )
        let repository = TestBusinessContextRepository(
            result: .success(SessionTestFixtures.context)
        )
        let viewModel = BusinessSessionViewModel(
            organizationId: SessionTestFixtures.context.organization.id,
            tokenStore: tokenStore,
            contextRepository: repository
        )

        await viewModel.refreshContext()

        XCTAssertEqual(viewModel.state, .signedIn(SessionTestFixtures.context))
        XCTAssertEqual(viewModel.context, SessionTestFixtures.context)
    }
}

private final class TestBusinessContextRepository: BusinessContextRepository, @unchecked Sendable {
    private let result: Result<BusinessContextResponse, Error>

    init(result: Result<BusinessContextResponse, Error>) {
        self.result = result
    }

    func getContext(organizationId: String) async throws -> BusinessContextResponse {
        try result.get()
    }
}

private enum SessionTestFixtures {
    static let revisions = BusinessRevisions(
        catalogRevision: "cat_rev_test",
        taxConfigurationRevision: "tax_rev_test"
    )

    static let context = BusinessContextResponse(
        user: BusinessUser(
            id: "usr_test",
            displayName: "Operador Test",
            email: "operador@nexo.test"
        ),
        organization: BusinessOrganization(
            id: "org_test",
            commercialName: "Altos del Murco",
            legalName: "Altos del Murco",
            taxId: "9999999999999",
            countryCode: "EC"
        ),
        branches: [
            BusinessBranch(
                id: "br_001",
                name: "Matriz",
                code: "001",
                status: "active"
            )
        ],
        activities: [
            BusinessActivity(
                id: "act_restaurant",
                code: "restaurant",
                name: "Restaurante",
                activityType: "restaurant",
                workflowMode: "quick_sale",
                status: "active"
            )
        ],
        activeModules: [
            .coreSales,
            .coreCash,
            .coreDocuments,
            .foundationIdempotency,
            .foundationCatalogRevision,
            .foundationTaxRevision
        ],
        effectivePermissions: [
            "business.sales.create",
            "cash.open",
            "cash.close",
            "documents.issue_internal_ticket"
        ],
        revisions: revisions,
        readiness: BusinessReadiness(
            status: "ready",
            score: 100,
            blockers: [],
            warnings: []
        )
    )
}
