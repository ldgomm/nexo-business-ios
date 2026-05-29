//
//  BusinessAppContainer.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class BusinessAppContainer: @unchecked Sendable {
    public let tokenStore: AuthTokenStoring
    public let authRepository: AuthRepository
    public let contextRepository: BusinessContextRepository
    public let catalogRepository: CatalogRepository
    public let salesRepository: SalesRepository
    public let cashRepository: CashRepository
    public let paymentsRepository: PaymentsRepository
    public let receivablesRepository: ReceivablesRepository
    public let documentsRepository: BusinessDocumentsRepository
    public let pendingOperationsRepository: PendingOperationsRepository
    public let dailyReportRepository: BusinessDailyReportRepository
    public let salesHistoryRepository: SalesHistoryRepository

    public init(
        tokenStore: AuthTokenStoring,
        authRepository: AuthRepository,
        contextRepository: BusinessContextRepository,
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        pendingOperationsRepository: PendingOperationsRepository,
        dailyReportRepository: BusinessDailyReportRepository,
        salesHistoryRepository: SalesHistoryRepository
    ) {
        self.tokenStore = tokenStore
        self.authRepository = authRepository
        self.contextRepository = contextRepository
        self.catalogRepository = catalogRepository
        self.salesRepository = salesRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.pendingOperationsRepository = pendingOperationsRepository
        self.dailyReportRepository = dailyReportRepository
        self.salesHistoryRepository = salesHistoryRepository
    }

    static func live(config: BusinessRuntimeConfig) -> BusinessAppContainer {
        let tokenStore = KeychainAuthTokenStore()
        let deviceMetadataProvider = StaticDeviceMetadataProvider.stagingDefault(
            deviceId: config.deviceId
        )

        let apiClient = URLSessionAPIClient(
            environment: config.environment,
            tokenStore: tokenStore,
            deviceMetadataProvider: deviceMetadataProvider
        )

        return BusinessAppContainer(
            tokenStore: tokenStore,
            authRepository: APIAuthRepository(
                apiClient: apiClient,
                tokenStore: tokenStore
            ),
            contextRepository: BusinessContextAPIRepository(apiClient: apiClient),
            catalogRepository: CatalogAPIRepository(apiClient: apiClient),
            salesRepository: SalesAPIRepository(apiClient: apiClient),
            cashRepository: CashAPIRepository(apiClient: apiClient),
            paymentsRepository: PaymentsAPIRepository(apiClient: apiClient),
            receivablesRepository: ReceivablesAPIRepository(apiClient: apiClient),
            documentsRepository: BusinessDocumentsAPIRepository(apiClient: apiClient),
            pendingOperationsRepository: PendingOperationsAPIRepository(apiClient: apiClient),
            dailyReportRepository: BusinessDailyReportAPIRepository(apiClient: apiClient),
            salesHistoryRepository: SalesHistoryAPIRepository(apiClient: apiClient)
        )
    }
}
