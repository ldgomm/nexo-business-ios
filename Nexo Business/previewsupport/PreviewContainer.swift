//
//  PreviewContainer.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public extension BusinessAppContainer {
    static var preview: BusinessAppContainer {
        let tokenStore = InMemoryAuthTokenStore(
            tokens: AuthTokens(
                accessToken: "preview-access-token",
                refreshToken: "preview-refresh-token",
                expiresAt: Date().addingTimeInterval(3600)
            )
        )

        return BusinessAppContainer(
            tokenStore: tokenStore,
            authRepository: PreviewAuthRepository(),
            contextRepository: PreviewBusinessContextRepository(),
            catalogRepository: PreviewCatalogRepository(),
            salesRepository: PreviewSalesRepository(),
            cashRepository: PreviewCashRepository(),
            paymentsRepository: PreviewPaymentsRepository(),
            receivablesRepository: PreviewReceivablesRepository(),
            documentsRepository: PreviewBusinessDocumentsRepository(),
            pendingOperationsRepository: PreviewPendingOperationsRepository(),
            dailyReportRepository: PreviewBusinessDailyReportRepository()
        )
    }
}
