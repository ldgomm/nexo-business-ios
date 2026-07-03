//
//  PreviewContainer.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

extension AppContainer {
    static var preview: AppContainer {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(
                accessToken: "preview-access-token",
                refreshToken: "preview-refresh-token",
                expiresAt: Date().addingTimeInterval(3600)
            )
        )

        let selectionStore = InMemoryBusinessSelectionStore(
            snapshot: BusinessSelectionSnapshot(
                organizationId: PreviewData.businessContext.organization.id,
                branchId: PreviewData.businessContext.branches.first?.id,
                activityId: PreviewData.businessContext.activities.first?.id
            )
        )

        return AppContainer(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            networkStatusProvider: StaticNetworkStatusProvider(status: .satisfied),
            operationGate: AsyncOperationGate(),
            authRepository: PreviewAuthRepository(),
            organizationAccessRepository: PreviewBusinessOrganizationAccessRepository(),
            contextRepository: PreviewBusinessContextRepository(),
            catalogRepository: PreviewCatalogRepository(),
            productsRepository: PreviewProductsRepository(),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository(),
            pendingOperationsRepository: PreviewPendingOperationsRepository(),
            dailyReportRepository: PreviewBusinessDailyReportRepository(),
            exportsRepository: PreviewBusinessExportsRepository(),
            salesHistoryRepository: PreviewSalesHistoryRepository(),
            customersRepository: PreviewCustomersRepository(),
            inventoryRepository: PreviewInventoryRepository(),
            teamRepository: PreviewBusinessTeamRepository(),
            proformasRepository: PreviewBusinessProformasRepository(),
            supportNotificationsRepository: PreviewBusinessSupportNotificationsRepository(),
        )
    }
}

final class PreviewBusinessSupportNotificationsRepository: BusinessSupportNotificationsRepository, @unchecked Sendable {
    func listNotifications(
        organizationId: String,
        branchId: String,
        limit: Int,
        unreadOnly: Bool?
    ) async throws -> BusinessSupportNotificationsResponse {
        BusinessSupportNotificationsResponse(
            items: [],
            unreadCount: 0,
            limit: limit,
            unreadOnly: unreadOnly
        )
    }
}

