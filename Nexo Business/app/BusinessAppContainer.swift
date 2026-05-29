//
//  BusinessAppContainer.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class BusinessAppContainer: @unchecked Sendable {
    public let tokenStore: AuthTokenStoring
    public let selectionStore: BusinessSelectionStoring
    public let networkStatusProvider: NetworkStatusProviding
    public let operationGate: AsyncOperationGate
    public let authRepository: AuthRepository
    public let organizationAccessRepository: BusinessOrganizationAccessRepository
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
    public let customersRepository: CustomersRepository
    public let inventoryRepository: InventoryRepository

    public init(
        tokenStore: AuthTokenStoring,
        selectionStore: BusinessSelectionStoring,
        networkStatusProvider: NetworkStatusProviding = SystemNetworkStatusProvider(),
        operationGate: AsyncOperationGate = AsyncOperationGate(),
        authRepository: AuthRepository,
        organizationAccessRepository: BusinessOrganizationAccessRepository,
        contextRepository: BusinessContextRepository,
        catalogRepository: CatalogRepository,
        salesRepository: SalesRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        pendingOperationsRepository: PendingOperationsRepository,
        dailyReportRepository: BusinessDailyReportRepository,
        salesHistoryRepository: SalesHistoryRepository,
        customersRepository: CustomersRepository,
        inventoryRepository: InventoryRepository
    ) {
        self.tokenStore = tokenStore
        self.selectionStore = selectionStore
        self.networkStatusProvider = networkStatusProvider
        self.operationGate = operationGate
        self.authRepository = authRepository
        self.organizationAccessRepository = organizationAccessRepository
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
        self.customersRepository = customersRepository
        self.inventoryRepository = inventoryRepository
    }

    static func live(config: BusinessRuntimeConfig) -> BusinessAppContainer {
        let tokenStore = KeychainAuthTokenStore()
        let selectionStore = UserDefaultsBusinessSelectionStore(
            preferredOrganizationId: config.organizationId
        )
        let deviceMetadataProvider = StaticDeviceMetadataProvider.stagingDefault(
            deviceId: config.deviceId
        )

        let rawApiClient = URLSessionAPIClient(
            environment: config.environment,
            tokenStore: tokenStore,
            deviceMetadataProvider: deviceMetadataProvider
        )

        let apiClient: APIClient = RetryingAPIClient(
            wrapping: rawApiClient,
            policy: .businessDefault,
            logger: AppLogger.shared
        )

        return BusinessAppContainer(
            tokenStore: tokenStore,
            selectionStore: selectionStore,
            networkStatusProvider: SystemNetworkStatusProvider(),
            operationGate: AsyncOperationGate(),
            authRepository: APIAuthRepository(
                apiClient: apiClient,
                tokenStore: tokenStore
            ),
            organizationAccessRepository: BusinessOrganizationAccessAPIRepository(apiClient: apiClient),
            contextRepository: BusinessContextAPIRepository(apiClient: apiClient),
            catalogRepository: CatalogAPIRepository(apiClient: apiClient),
            salesRepository: SalesAPIRepository(apiClient: apiClient),
            cashRepository: CashAPIRepository(apiClient: apiClient),
            paymentsRepository: PaymentsAPIRepository(apiClient: apiClient),
            receivablesRepository: ReceivablesAPIRepository(apiClient: apiClient),
            documentsRepository: BusinessDocumentsAPIRepository(apiClient: apiClient),
            pendingOperationsRepository: PendingOperationsAPIRepository(apiClient: apiClient),
            dailyReportRepository: BusinessDailyReportAPIRepository(apiClient: apiClient),
            salesHistoryRepository: SalesHistoryAPIRepository(apiClient: apiClient),
            customersRepository: CustomersAPIRepository(apiClient: apiClient),
            inventoryRepository: InventoryAPIRepository(apiClient: apiClient)
        )
    }
}
