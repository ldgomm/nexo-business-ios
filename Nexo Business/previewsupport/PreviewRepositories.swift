//
//  PreviewRepositories.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public final class PreviewAuthRepository: AuthRepository, @unchecked Sendable {
    public init() {}

    public func login(email: String, password: String) async throws -> LoginResponse {
        LoginResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            expiresAt: Date().addingTimeInterval(3600),
            user: AuthenticatedUser(
                id: "usr_preview",
                email: email,
                displayName: "Preview"
            )
        )
    }

    public func logout() async throws {}
}

public final class PreviewBusinessContextRepository: BusinessContextRepository, @unchecked Sendable {
    public init() {}

    public func getContext(organizationId: String) async throws -> BusinessContextResponse {
        PreviewData.businessContext
    }
}

public final class PreviewCatalogRepository: CatalogRepository, @unchecked Sendable {
    public init() {}

    public func search(
        organizationId: String,
        branchId: String,
        activityId: String,
        catalogRevision: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSearchResponse {
        let normalized = query.lowercased()
        let items = PreviewData.catalogItems.filter { item in
            let matchesName = item.name.lowercased().contains(normalized)
            let matchesSku = item.sku?.lowercased().contains(normalized) ?? false
            let matchesId = item.id.lowercased().contains(normalized)
            return matchesName || matchesSku || matchesId
        }

        return CatalogSearchResponse(
            items: items.isEmpty ? PreviewData.catalogItems : Array(items.prefix(limit)),
            catalogRevision: catalogRevision
        )
    }
}

public final class PreviewSalesRepository: SalesRepository, @unchecked Sendable {
    public init() {}

    public func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        PreviewData.previewResponse
    }

    public func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    public func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        BusinessSaleDetailResponse(sale: PreviewData.quickSaleResponse.sale)
    }

    public func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        PreviewData.confirmedSaleResponse
    }

    public func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        PreviewData.canceledSaleResponse
    }
}

public final class PreviewCashRepository: CashRepository, @unchecked Sendable {
    public init() {}

    public func current(
        organizationId: String,
        branchId: String
    ) async throws -> CashCurrentSessionResponse {
        CashCurrentSessionResponse(
            session: CashSession(
                id: "cash_preview",
                branchId: branchId,
                status: "open",
                openedAt: Date().addingTimeInterval(-1800),
                closedAt: nil,
                openingAmount: MoneyAmount(amount: "20.00"),
                countedAmount: nil,
                expectedAmount: MoneyAmount(amount: "31.50"),
                differenceAmount: nil
            )
        )
    }

    public func open(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: OpenCashSessionRequest
    ) async throws -> CashSessionResponse {
        CashSessionResponse(
            session: CashSession(
                id: "cash_preview",
                branchId: request.branchId,
                status: "open",
                openedAt: Date(),
                closedAt: nil,
                openingAmount: MoneyAmount(amount: request.openingAmount),
                countedAmount: nil
            ),
            idempotencyReplayed: false
        )
    }

    public func registerMovement(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterCashMovementRequest
    ) async throws -> CashMovementResponse {
        CashMovementResponse(
            movement: CashMovement(
                id: "mov_preview",
                cashSessionId: cashSessionId,
                type: request.type,
                amount: MoneyAmount(amount: request.amount),
                note: request.note,
                createdAt: Date()
            ),
            idempotencyReplayed: false
        )
    }

    public func close(
        organizationId: String,
        cashSessionId: String,
        idempotencyKey: IdempotencyKey,
        request: CloseCashSessionRequest
    ) async throws -> CashSessionResponse {
        CashSessionResponse(
            session: CashSession(
                id: cashSessionId,
                branchId: PreviewData.businessContext.branches[0].id,
                status: "closed",
                openedAt: Date().addingTimeInterval(-3600),
                closedAt: Date(),
                openingAmount: MoneyAmount(amount: "20.00"),
                countedAmount: MoneyAmount(amount: request.countedAmount)
            ),
            idempotencyReplayed: false
        )
    }
}

public final class PreviewPaymentsRepository: PaymentsRepository, @unchecked Sendable {
    public init() {}

    public func register(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPaymentRequest
    ) async throws -> PaymentResponse {
        PaymentResponse(
            payment: PaymentRecord(
                id: "pay_preview",
                saleId: request.saleId,
                status: "registered",
                method: request.method,
                amount: MoneyAmount(amount: request.amount),
                registeredAt: Date()
            ),
            idempotencyReplayed: false
        )
    }
}

public final class PreviewBusinessDocumentsRepository: BusinessDocumentsRepository, @unchecked Sendable {
    public init() {}

    public func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        PreviewData.businessDocumentsResponse
    }

    public func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse {
        PreviewData.internalTicketDocumentResponse
    }

    public func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse {
        PreviewData.physicalSaleNoteDocumentResponse
    }
}

public final class PreviewReceivablesRepository: ReceivablesRepository, @unchecked Sendable {
    public init() {}

    public func create(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CreateReceivableRequest
    ) async throws -> ReceivableResponse {
        let amount = previewAmount(request.amount)

        return ReceivableResponse(
            receivable: ReceivableRecord(
                id: "recv_preview",
                saleId: request.saleId,
                customerId: request.customerId,
                status: "pending",
                amount: MoneyAmount(amount: amount),
                balance: MoneyAmount(amount: amount),
                dueDate: request.dueDate,
                createdAt: Date()
            ),
            idempotencyReplayed: false
        )
    }

    public func collect(
        organizationId: String,
        idempotencyKey: IdempotencyKey,
        request: CollectReceivableRequest
    ) async throws -> ReceivableCollectionResponse {
        let amount = previewAmount(request.amount)
        let payment = PaymentRecord(
            id: "pay_recv_preview",
            saleId: PreviewData.confirmedSaleResponse.sale.id,
            status: "registered",
            method: request.method,
            amount: MoneyAmount(amount: amount),
            reference: request.reference,
            note: request.note,
            registeredAt: Date()
        )

        return ReceivableCollectionResponse(
            receivable: ReceivableRecord(
                id: request.receivableId,
                saleId: PreviewData.confirmedSaleResponse.sale.id,
                customerId: "cus_preview",
                status: "collected",
                amount: MoneyAmount(amount: amount),
                balance: MoneyAmount(amount: "0.00"),
                createdAt: Date().addingTimeInterval(-3600)
            ),
            payment: payment,
            idempotencyReplayed: false
        )
    }

    private func previewAmount(_ value: Any?) -> String {
        let fallback = PreviewData.confirmedSaleResponse.sale.totals.grandTotal.amount

        guard let value else {
            return fallback
        }

        if let amount = value as? MoneyAmount {
            return amount.amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? fallback
                : amount.amount
        }

        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? fallback : trimmed
        }

        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            guard let child = mirror.children.first else {
                return fallback
            }
            return previewAmount(child.value)
        }

        let raw = String(describing: value)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !raw.isEmpty else {
            return fallback
        }

        if raw == "nil" || raw == "Optional(nil)" {
            return fallback
        }

        if raw.hasPrefix("Optional(\"") && raw.hasSuffix("\")") {
            let inner = raw.dropFirst("Optional(\"".count).dropLast(2)
            return inner.isEmpty ? fallback : String(inner)
        }

        if raw.hasPrefix("Optional(") && raw.hasSuffix(")") {
            let inner = raw.dropFirst("Optional(".count).dropLast()
            return inner.isEmpty ? fallback : String(inner)
        }

        return raw
    }
}

public final class PreviewPendingOperationsRepository: PendingOperationsRepository, @unchecked Sendable {
    public init() {}

    public func pendingSales(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingSalesResponse {
        PendingSalesResponse(
            sales: Array(PreviewData.pendingSalesResponse.sales.prefix(limit)),
            total: PreviewData.pendingSalesResponse.total
        )
    }

    public func pendingReceivables(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingReceivablesResponse {
        PendingReceivablesResponse(
            receivables: Array(PreviewData.pendingReceivablesResponse.receivables.prefix(limit)),
            total: PreviewData.pendingReceivablesResponse.total
        )
    }

    public func pendingDocuments(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingDocumentsResponse {
        PendingDocumentsResponse(
            documents: Array(PreviewData.pendingDocumentsResponse.documents.prefix(limit)),
            total: PreviewData.pendingDocumentsResponse.total
        )
    }
}

public final class PreviewBusinessDailyReportRepository: BusinessDailyReportRepository, @unchecked Sendable {
    public init() {}

    public func dailyReport(
        organizationId: String,
        branchId: String,
        businessDate: String
    ) async throws -> BusinessDailyReportResponse {
        BusinessDailyReportResponse(
            report: BusinessDailyReport(
                businessDate: businessDate,
                branchId: branchId,
                salesCount: PreviewData.dailyReport.salesCount,
                salesTotal: PreviewData.dailyReport.salesTotal,
                paymentsCount: PreviewData.dailyReport.paymentsCount,
                paymentsTotal: PreviewData.dailyReport.paymentsTotal,
                cashExpectedAmount: PreviewData.dailyReport.cashExpectedAmount,
                receivablesPendingCount: PreviewData.dailyReport.receivablesPendingCount,
                receivablesPendingTotal: PreviewData.dailyReport.receivablesPendingTotal,
                pendingSalesCount: PreviewData.dailyReport.pendingSalesCount,
                pendingDocumentsCount: PreviewData.dailyReport.pendingDocumentsCount,
                cashStatus: PreviewData.dailyReport.cashStatus,
                generatedAt: Date()
            )
        )
    }
}
