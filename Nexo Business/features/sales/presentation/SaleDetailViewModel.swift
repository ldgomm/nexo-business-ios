//
//  SaleDetailViewModel.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
public final class SaleDetailViewModel {
    public private(set) var sale: BusinessSale?
    public private(set) var isLoading = false
    public private(set) var isConfirming = false
    public private(set) var isCanceling = false
    public var cancelReason = ""
    public var errorMessage: String?
    public var infoMessage: String?

    public let organizationId: String
    public let saleId: String
    public let revisions: BusinessRevisions
    public let effectivePermissions: Set<String>

    private let repository: SalesRepository

    public init(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        initialSale: BusinessSale? = nil,
        effectivePermissions: Set<String> = [],
        salesRepository: SalesRepository
    ) {
        self.organizationId = organizationId
        self.saleId = saleId
        self.revisions = revisions
        self.sale = initialSale
        self.effectivePermissions = effectivePermissions
        self.repository = salesRepository
    }

    public var canConfirm: Bool {
        guard let sale else { return false }
        return !isLoading &&
        !isConfirming &&
        !isCanceling &&
        hasPermission(["business.sales.confirm", "sales.confirm"]) &&
        SaleStatusPresentation.canConfirm(status: sale.status)
    }

    public var canCancel: Bool {
        guard let sale else { return false }
        return !isLoading &&
        !isConfirming &&
        !isCanceling &&
        hasPermission(["business.sales.cancel", "sales.cancel"]) &&
        SaleStatusPresentation.canCancel(status: sale.status)
    }

    public var canCollect: Bool {
        guard let sale else { return false }
        return !isLoading &&
        !isConfirming &&
        !isCanceling &&
        SaleStatusPresentation.canCollect(status: sale.status) &&
        PaymentStatusPresentation.canCollect(status: sale.paymentStatus) &&
        hasPermission([
            "business.payments.collect",
            "payments.collect",
            "business.payments.register",
            "payments.register",
            "business.receivables.create",
            "receivables.create",
            "business.payments.mark_as_credit",
            "payments.mark_as_credit"
        ])
    }


    public var canManageDocuments: Bool {
        guard sale != nil else { return false }
        return hasPermission([
            "business.documents.view",
            "documents.view",
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note",
            "business.documents.issue_electronic_invoice",
            "documents.issue_electronic_invoice"
        ])
    }

    public var shouldLoadOnAppear: Bool {
        sale == nil && !isLoading
    }

    public func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isLoading = false
        }

        do {
            let response = try await repository.getSale(
                organizationId: organizationId,
                saleId: saleId
            )
            sale = response.sale
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func refresh() async {
        await load()
    }

    public func confirm() async {
        guard let sale else {
            errorMessage = "No se encontró la venta. Actualiza e inténtalo nuevamente."
            return
        }

        guard canConfirm else {
            errorMessage = "No puedes confirmar esta venta con tu usuario o estado actual."
            return
        }

        isConfirming = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isConfirming = false
        }

        do {
            let response = try await repository.confirm(
                organizationId: organizationId,
                saleId: sale.id,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "sale-confirm"),
                request: ConfirmSaleRequest()
            )
            self.sale = response.sale
            infoMessage = response.idempotencyReplayed == true
                ? "Confirmación recuperada de un intento anterior."
                : "Venta confirmada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func cancel() async {
        guard let sale else {
            errorMessage = "No se encontró la venta. Actualiza e inténtalo nuevamente."
            return
        }

        guard canCancel else {
            errorMessage = "No puedes cancelar esta venta con tu usuario o estado actual."
            return
        }

        let trimmedReason = cancelReason
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let finalReason = trimmedReason.isEmpty
            ? "Cancelación solicitada desde Nexo Business"
            : trimmedReason

        isCanceling = true
        errorMessage = nil
        infoMessage = nil

        defer {
            isCanceling = false
        }

        do {
            let response = try await repository.cancel(
                organizationId: organizationId,
                saleId: sale.id,
                revisions: revisions,
                idempotencyKey: .generate(prefix: "sale-cancel"),
                request: CancelSaleRequest(
                    reason: finalReason
                )
            )

            self.sale = response.sale
            infoMessage = response.idempotencyReplayed == true
                ? "Cancelación recuperada de un intento anterior."
                : "Venta cancelada correctamente."
        } catch let error as APIError {
            handle(apiError: error)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func hasPermission(_ permissions: [String]) -> Bool {
        permissions.contains { effectivePermissions.contains($0) }
    }

    private func handle(apiError: APIError) {
        errorMessage = apiError.userMessage

        if apiError.statusCode == 409 || apiError.statusCode == 428 {
            infoMessage = "Actualiza el contexto del negocio antes de continuar."
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
