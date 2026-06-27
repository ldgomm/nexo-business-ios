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
    let proformasRepository: BusinessProformasRepository
    let restaurantTablesRepository: BusinessRestaurantTablesRepository

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
        teamRepository: BusinessTeamRepository,
        proformasRepository: BusinessProformasRepository,
        restaurantTablesRepository: BusinessRestaurantTablesRepository
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
        self.proformasRepository = proformasRepository
        self.restaurantTablesRepository = restaurantTablesRepository
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
            teamRepository: BusinessTeamAPIRepository(apiClient: apiClient),
            proformasRepository: BusinessProformasAPIRepository(apiClient: apiClient),
            restaurantTablesRepository: BusinessRestaurantTablesAPIRepository(apiClient: apiClient)
        )
    }
}

// MARK: - Restaurant Tables Optional UI Contracts (22F.7)

protocol BusinessRestaurantTablesRepository: Sendable {
    func readiness(
        organizationId: String,
        branchId: String
    ) async throws -> RestaurantTableReadinessEnvelopeResponse

    func openSession(
        organizationId: String,
        branchId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse

    func closeSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey
    ) async throws -> RestaurantTableSessionEnvelopeResponse

    func cancelSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CancelRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse
}

enum BusinessRestaurantTableRoutes {
    static let readiness = "/api/v1/business/restaurant/tables/readiness"
    static let tableSessions = "/api/v1/business/restaurant/table-sessions"

    static func closeSession(_ sessionId: String) -> String {
        "\(tableSessions)/\(sessionId)/close"
    }

    static func cancelSession(_ sessionId: String) -> String {
        "\(tableSessions)/\(sessionId)/cancel"
    }
}

final class BusinessRestaurantTablesAPIRepository: BusinessRestaurantTablesRepository, @unchecked Sendable {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func readiness(
        organizationId: String,
        branchId: String
    ) async throws -> RestaurantTableReadinessEnvelopeResponse {
        try await apiClient.send(
            APIRequest<RestaurantTableReadinessEnvelopeResponse>(
                method: .get,
                path: BusinessRestaurantTableRoutes.readiness,
                queryItems: [URLQueryItem(name: "branchId", value: branchId)],
                headers: [
                    BusinessHeaders.organizationId: organizationId,
                    BusinessHeaders.branchId: branchId
                ]
            )
        )
    }

    func openSession(
        organizationId: String,
        branchId: String,
        idempotencyKey: IdempotencyKey,
        request body: OpenRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<RestaurantTableSessionEnvelopeResponse>.json(
                method: .post,
                path: BusinessRestaurantTableRoutes.tableSessions,
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func closeSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        try await apiClient.send(
            APIRequest<RestaurantTableSessionEnvelopeResponse>(
                method: .post,
                path: BusinessRestaurantTableRoutes.closeSession(sessionId),
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    func cancelSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey,
        request body: CancelRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        try await apiClient.send(
            try APIRequest<RestaurantTableSessionEnvelopeResponse>.json(
                method: .post,
                path: BusinessRestaurantTableRoutes.cancelSession(sessionId),
                body: body,
                headers: mutationHeaders(
                    organizationId: organizationId,
                    branchId: branchId,
                    idempotencyKey: idempotencyKey
                )
            )
        )
    }

    private func mutationHeaders(
        organizationId: String,
        branchId: String,
        idempotencyKey: IdempotencyKey
    ) -> [String: String] {
        [
            BusinessHeaders.organizationId: organizationId,
            BusinessHeaders.branchId: branchId,
            BusinessHeaders.idempotencyKey: idempotencyKey.rawValue
        ]
    }
}

struct RestaurantTableReadinessEnvelopeResponse: Decodable, Equatable, Sendable {
    let tables: [RestaurantTableReadiness]
    let summary: RestaurantTableReadinessSummary
}

struct RestaurantTableReadinessSummary: Decodable, Equatable, Sendable {
    let total: Int
    let available: Int
    let occupied: Int
    let disabled: Int
    let openSessions: Int
}

struct RestaurantTableReadiness: Decodable, Equatable, Identifiable, Sendable {
    var id: String { tableId }

    let tableId: String
    let organizationId: String
    let branchId: String
    let code: String
    let name: String
    let area: String?
    let capacity: Int?
    let status: String
    let isActive: Bool
    let activeSessionId: String?
    let linkedSaleId: String?
    let openedAt: String?
    let canOpen: Bool
    let canClose: Bool
    let canCancel: Bool
    let canLinkSale: Bool
    let reasonIfBlocked: String?
}

struct RestaurantTableSessionEnvelopeResponse: Decodable, Equatable, Sendable {
    let session: RestaurantTableSession
}

struct RestaurantTableSession: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let organizationId: String
    let branchId: String
    let tableId: String
    let saleId: String?
    let status: String
    let openedAt: String
    let closedAt: String?
    let openedByUserId: String
    let closedByUserId: String?
    let notes: String?
    let createdAt: String
    let updatedAt: String
}

struct OpenRestaurantTableSessionRequest: Encodable, Equatable, Sendable {
    let tableId: String
    let saleId: String?
    let notes: String?

    init(tableId: String, saleId: String? = nil, notes: String? = nil) {
        self.tableId = tableId
        self.saleId = saleId
        self.notes = notes
    }
}

struct CancelRestaurantTableSessionRequest: Encodable, Equatable, Sendable {
    let reason: String
}

final class PreviewBusinessRestaurantTablesRepository: BusinessRestaurantTablesRepository, @unchecked Sendable {
    private var envelope = RestaurantTableReadinessEnvelopeResponse(
        tables: [
            RestaurantTableReadiness(
                tableId: "table_preview_1",
                organizationId: "org_preview",
                branchId: "br_preview",
                code: "M1",
                name: "Mesa 1",
                area: "Salón",
                capacity: 4,
                status: "available",
                isActive: true,
                activeSessionId: nil,
                linkedSaleId: nil,
                openedAt: nil,
                canOpen: true,
                canClose: false,
                canCancel: false,
                canLinkSale: false,
                reasonIfBlocked: nil
            ),
            RestaurantTableReadiness(
                tableId: "table_preview_2",
                organizationId: "org_preview",
                branchId: "br_preview",
                code: "M2",
                name: "Mesa 2",
                area: "Terraza",
                capacity: 6,
                status: "occupied",
                isActive: true,
                activeSessionId: "sess_preview_2",
                linkedSaleId: nil,
                openedAt: "2026-06-26T19:00:00Z",
                canOpen: false,
                canClose: true,
                canCancel: true,
                canLinkSale: true,
                reasonIfBlocked: nil
            ),
            RestaurantTableReadiness(
                tableId: "table_preview_3",
                organizationId: "org_preview",
                branchId: "br_preview",
                code: "M3",
                name: "Mesa 3",
                area: "Salón",
                capacity: 2,
                status: "disabled",
                isActive: false,
                activeSessionId: nil,
                linkedSaleId: nil,
                openedAt: nil,
                canOpen: false,
                canClose: false,
                canCancel: false,
                canLinkSale: false,
                reasonIfBlocked: "Mesa deshabilitada."
            )
        ],
        summary: RestaurantTableReadinessSummary(total: 3, available: 1, occupied: 1, disabled: 1, openSessions: 1)
    )

    func readiness(
        organizationId: String,
        branchId: String
    ) async throws -> RestaurantTableReadinessEnvelopeResponse {
        envelope
    }

    func openSession(
        organizationId: String,
        branchId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        let sessionId = "sess_preview_\(request.tableId)"
        replaceTable(request.tableId) { table in
            RestaurantTableReadiness(
                tableId: table.tableId,
                organizationId: table.organizationId,
                branchId: table.branchId,
                code: table.code,
                name: table.name,
                area: table.area,
                capacity: table.capacity,
                status: "occupied",
                isActive: table.isActive,
                activeSessionId: sessionId,
                linkedSaleId: request.saleId,
                openedAt: "2026-06-26T19:00:00Z",
                canOpen: false,
                canClose: true,
                canCancel: true,
                canLinkSale: true,
                reasonIfBlocked: nil
            )
        }
        rebuildSummary()
        return RestaurantTableSessionEnvelopeResponse(
            session: previewSession(
                id: sessionId,
                organizationId: organizationId,
                branchId: branchId,
                tableId: request.tableId,
                status: "open",
                notes: request.notes
            )
        )
    }

    func closeSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        let tableId = clearSession(sessionId: sessionId)
        rebuildSummary()
        return RestaurantTableSessionEnvelopeResponse(
            session: previewSession(
                id: sessionId,
                organizationId: organizationId,
                branchId: branchId,
                tableId: tableId ?? "table_preview_1",
                status: "closed",
                notes: nil
            )
        )
    }

    func cancelSession(
        organizationId: String,
        branchId: String,
        sessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CancelRestaurantTableSessionRequest
    ) async throws -> RestaurantTableSessionEnvelopeResponse {
        let tableId = clearSession(sessionId: sessionId)
        rebuildSummary()
        return RestaurantTableSessionEnvelopeResponse(
            session: previewSession(
                id: sessionId,
                organizationId: organizationId,
                branchId: branchId,
                tableId: tableId ?? "table_preview_1",
                status: "cancelled",
                notes: request.reason
            )
        )
    }

    private func replaceTable(
        _ tableId: String,
        transform: (RestaurantTableReadiness) -> RestaurantTableReadiness
    ) {
        envelope = RestaurantTableReadinessEnvelopeResponse(
            tables: envelope.tables.map { $0.tableId == tableId ? transform($0) : $0 },
            summary: envelope.summary
        )
    }

    private func clearSession(sessionId: String) -> String? {
        var clearedTableId: String?
        envelope = RestaurantTableReadinessEnvelopeResponse(
            tables: envelope.tables.map { table in
                guard table.activeSessionId == sessionId else { return table }
                clearedTableId = table.tableId
                return RestaurantTableReadiness(
                    tableId: table.tableId,
                    organizationId: table.organizationId,
                    branchId: table.branchId,
                    code: table.code,
                    name: table.name,
                    area: table.area,
                    capacity: table.capacity,
                    status: "available",
                    isActive: table.isActive,
                    activeSessionId: nil,
                    linkedSaleId: nil,
                    openedAt: nil,
                    canOpen: true,
                    canClose: false,
                    canCancel: false,
                    canLinkSale: false,
                    reasonIfBlocked: nil
                )
            },
            summary: envelope.summary
        )
        return clearedTableId
    }

    private func rebuildSummary() {
        envelope = RestaurantTableReadinessEnvelopeResponse(
            tables: envelope.tables,
            summary: RestaurantTableReadinessSummary(
                total: envelope.tables.count,
                available: envelope.tables.filter { $0.normalizedStatus == "available" }.count,
                occupied: envelope.tables.filter { $0.normalizedStatus == "occupied" }.count,
                disabled: envelope.tables.filter { $0.normalizedStatus == "disabled" }.count,
                openSessions: envelope.tables.filter { $0.activeSessionId != nil }.count
            )
        )
    }

    private func previewSession(
        id: String,
        organizationId: String,
        branchId: String,
        tableId: String,
        status: String,
        notes: String?
    ) -> RestaurantTableSession {
        RestaurantTableSession(
            id: id,
            organizationId: organizationId,
            branchId: branchId,
            tableId: tableId,
            saleId: nil,
            status: status,
            openedAt: "2026-06-26T19:00:00Z",
            closedAt: status == "open" ? nil : "2026-06-26T19:15:00Z",
            openedByUserId: "usr_preview",
            closedByUserId: status == "open" ? nil : "usr_preview",
            notes: notes,
            createdAt: "2026-06-26T19:00:00Z",
            updatedAt: "2026-06-26T19:15:00Z"
        )
    }
}

private extension RestaurantTableReadiness {
    var normalizedStatus: String {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

