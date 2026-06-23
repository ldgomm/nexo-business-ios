//
//  BusinessAppContainer.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

final class BusinessAppContainer: @unchecked Sendable {
    let tokenStore: AuthTokenStoring
    let selectionStore: BusinessSelectionStoring
    let networkStatusProvider: NetworkStatusProviding
    let operationGate: AsyncOperationGate
    let authRepository: AuthRepository
    let organizationAccessRepository: BusinessOrganizationAccessRepository
    let contextRepository: BusinessContextRepository
    let catalogRepository: CatalogRepository
    let productsRepository: ProductsRepository
    let salesRepository: SalesRepository
    let cashRepository: CashRepository
    let paymentsRepository: PaymentsRepository
    let receivablesRepository: ReceivablesRepository
    let documentsRepository: BusinessDocumentsRepository
    let pendingOperationsRepository: PendingOperationsRepository
    let dailyReportRepository: BusinessDailyReportRepository
    let exportsRepository: BusinessExportsRepository
    let salesHistoryRepository: SalesHistoryRepository
    let customersRepository: CustomersRepository
    let inventoryRepository: InventoryRepository
    let teamRepository: BusinessTeamRepository

    init(
        tokenStore: AuthTokenStoring,
        selectionStore: BusinessSelectionStoring,
        networkStatusProvider: NetworkStatusProviding = SystemNetworkStatusProvider(),
        operationGate: AsyncOperationGate = AsyncOperationGate(),
        authRepository: AuthRepository,
        organizationAccessRepository: BusinessOrganizationAccessRepository,
        contextRepository: BusinessContextRepository,
        catalogRepository: CatalogRepository,
        productsRepository: ProductsRepository,
        salesRepository: SalesRepository,
        cashRepository: CashRepository,
        paymentsRepository: PaymentsRepository,
        receivablesRepository: ReceivablesRepository,
        documentsRepository: BusinessDocumentsRepository,
        pendingOperationsRepository: PendingOperationsRepository,
        dailyReportRepository: BusinessDailyReportRepository,
        exportsRepository: BusinessExportsRepository,
        salesHistoryRepository: SalesHistoryRepository,
        customersRepository: CustomersRepository,
        inventoryRepository: InventoryRepository,
        teamRepository: BusinessTeamRepository
    ) {
        self.tokenStore = tokenStore
        self.selectionStore = selectionStore
        self.networkStatusProvider = networkStatusProvider
        self.operationGate = operationGate
        self.authRepository = authRepository
        self.organizationAccessRepository = organizationAccessRepository
        self.contextRepository = contextRepository
        self.catalogRepository = catalogRepository
        self.productsRepository = productsRepository
        self.salesRepository = salesRepository
        self.cashRepository = cashRepository
        self.paymentsRepository = paymentsRepository
        self.receivablesRepository = receivablesRepository
        self.documentsRepository = documentsRepository
        self.pendingOperationsRepository = pendingOperationsRepository
        self.dailyReportRepository = dailyReportRepository
        self.exportsRepository = exportsRepository
        self.salesHistoryRepository = salesHistoryRepository
        self.customersRepository = customersRepository
        self.inventoryRepository = inventoryRepository
        self.teamRepository = teamRepository
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
            productsRepository: ProductsAPIRepository(apiClient: apiClient),
            salesRepository: SalesAPIRepository(apiClient: apiClient),
            cashRepository: CashAPIRepository(apiClient: apiClient),
            paymentsRepository: PaymentsAPIRepository(apiClient: apiClient),
            receivablesRepository: ReceivablesAPIRepository(apiClient: apiClient),
            documentsRepository: BusinessDocumentsAPIRepository(apiClient: apiClient),
            pendingOperationsRepository: PendingOperationsAPIRepository(apiClient: apiClient),
            dailyReportRepository: BusinessDailyReportAPIRepository(apiClient: apiClient),
            exportsRepository: BusinessExportsAPIRepository(apiClient: apiClient),
            salesHistoryRepository: SalesHistoryAPIRepository(apiClient: apiClient),
            customersRepository: CustomersAPIRepository(apiClient: apiClient),
            inventoryRepository: InventoryAPIRepository(apiClient: apiClient),
            teamRepository: BusinessTeamAPIRepository(apiClient: apiClient)
        )
    }
}
