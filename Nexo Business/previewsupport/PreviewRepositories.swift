//
//  PreviewRepositories.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

final class PreviewAuthRepository: AuthRepository, @unchecked Sendable {
    init() {}

    func login(email: String, password: String) async throws -> LoginResponse {
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

    func recoverSessions(email: String, password: String) async throws -> LoginResponse {
        try await login(email: email, password: password)
    }

    func listSessions() async throws -> [AuthUserSession] {
        [
            AuthUserSession(
                id: "ses_preview_current",
                userId: "usr_preview",
                status: "ACTIVE",
                createdAt: Date().addingTimeInterval(-3600),
                expiresAt: Date().addingTimeInterval(3600 * 24),
                lastSeenAt: Date(),
                userAgent: "Preview iOS",
                ipAddress: "127.0.0.1",
                deviceId: "ios-business-preview",
                appType: "nexo-business-ios",
                appVersion: "21E.11",
                appBuild: "preview",
                platform: "ios",
                current: true
            ),
            AuthUserSession(
                id: "ses_preview_other",
                userId: "usr_preview",
                status: "ACTIVE",
                createdAt: Date().addingTimeInterval(-7200),
                expiresAt: Date().addingTimeInterval(3600 * 24),
                lastSeenAt: Date().addingTimeInterval(-1200),
                userAgent: "Otro dispositivo",
                ipAddress: "127.0.0.1",
                deviceId: "ios-business-other",
                appType: "nexo-business-ios",
                appVersion: "21E.11",
                appBuild: "preview",
                platform: "ios",
                current: false
            )
        ]
    }

    func revokeSession(sessionId: String, reason: String) async throws -> RevokeAuthSessionResponse {
        RevokeAuthSessionResponse(revokedSessions: 1, revokedRefreshTokens: 1)
    }

    func revokeAllSessions(reason: String) async throws -> RevokeAuthSessionResponse {
        RevokeAuthSessionResponse(revokedSessions: 2, revokedRefreshTokens: 2)
    }

    func logout() async throws {}
}

final class PreviewBusinessContextRepository: BusinessContextRepository, @unchecked Sendable {
    private let context: BusinessContextResponse

    init(context: BusinessContextResponse = PreviewData.businessContext) {
        self.context = context
    }

    func getContext(organizationId: String) async throws -> BusinessContextResponse {
        context
    }
}

final class PreviewCatalogRepository: CatalogRepository, @unchecked Sendable {
    init() {}

    func search(
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
            items: Array(items.prefix(limit)),
            catalogRevision: catalogRevision
        )
    }

    func searchSuggestions(
        organizationId: String,
        query: String,
        limit: Int
    ) async throws -> CatalogSuggestionSearchResponse {
        CatalogSuggestionSearchResponse(
            templates: [
                PlatformCatalogTemplateSuggestion(
                    id: "tpl_preview_cuy_entero",
                    globalCatalogId: "restaurant_cuy_entero",
                    canonicalName: "Cuy entero",
                    normalizedName: "cuy entero",
                    type: "PRODUCT",
                    status: "ACTIVE",
                    productFamilyId: nil,
                    variantAttributes: [:],
                    identifiers: [
                        CatalogIdentifier(
                            type: "LOCAL_CODE",
                            value: "ALT-CUY-ENTERO",
                            normalizedValue: "alt-cuy-entero",
                            scope: "PLATFORM",
                            status: "ACTIVE",
                            source: "PLATFORM",
                            isPrimary: true
                        )
                    ],
                    attributes: [
                        "suggestedPrice": "24.00",
                        "defaultTaxProfileCode": "iva_current_full",
                    ]
                )
            ]
        )
    }

    func adoptSuggestion(
        organizationId: String,
        branchId: String?,
        activityId: String,
        template: PlatformCatalogTemplateSuggestion,
        localPrice: MoneyAmount,
        taxProfileCode: String,
        reason: String
    ) async throws -> BusinessCatalogItem {
        BusinessCatalogItem(
            id: "adopted_\(template.globalCatalogId)",
            name: template.displayName,
            itemDescription: nil,
            sku: template.primaryCode,
            type: template.type.lowercased(),
            status: "active",
            price: localPrice,
            taxProfileCode: taxProfileCode,
            taxProfileId: taxProfileCode
        )
    }
}

final class PreviewSalesRepository: SalesRepository, @unchecked Sendable {
    
    init() {}

    func preview(
        organizationId: String,
        revisions: BusinessRevisions,
        request: SalesPreviewRequest
    ) async throws -> SalesPreviewResponse {
        PreviewData.previewResponse
    }

    func quickSale(
        organizationId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: QuickSaleRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    func updateCustomer(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: UpdateSaleCustomerRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    func getSale(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessSaleDetailResponse {
        BusinessSaleDetailResponse(sale: PreviewData.quickSaleResponse.sale)
    }

    func confirm(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: ConfirmSaleRequest
    ) async throws -> ConfirmSaleResponse {
        PreviewData.confirmedSaleResponse
    }

    func cancel(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: CancelSaleRequest
    ) async throws -> CancelSaleResponse {
        PreviewData.canceledSaleResponse
    }
    
    func bulkAddItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkAddSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    func bulkUpdateItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkUpdateSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }

    func bulkRemoveItems(
        organizationId: String,
        saleId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: BulkRemoveSaleItemsRequest
    ) async throws -> QuickSaleResponse {
        PreviewData.quickSaleResponse
    }
}

final class PreviewCashRepository: CashRepository, @unchecked Sendable {
    init() {}

    func current(
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

    func open(
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

    func registerMovement(
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

    func close(
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

final class PreviewPaymentsRepository: PaymentsRepository, @unchecked Sendable {
    init() {}

    func register(
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

final class PreviewBusinessDocumentsRepository: BusinessDocumentsRepository, @unchecked Sendable {
    init() {}

    func list(
        organizationId: String,
        saleId: String
    ) async throws -> BusinessDocumentsResponse {
        PreviewData.businessDocumentsResponse
    }

    func generateInternalTicket(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: GenerateInternalTicketRequest
    ) async throws -> BusinessDocumentResponse {
        PreviewData.internalTicketDocumentResponse
    }

    func registerPhysicalSaleNote(
        organizationId: String,
        saleId: String,
        idempotencyKey: IdempotencyKey,
        request: RegisterPhysicalSaleNoteRequest
    ) async throws -> BusinessDocumentResponse {
        PreviewData.physicalSaleNoteDocumentResponse
    }

    func issueElectronicInvoice(
        organizationId: String,
        saleId: String,
        branchId: String,
        activityId: String,
        revisions: BusinessRevisions,
        idempotencyKey: IdempotencyKey,
        request: IssueBusinessElectronicDocumentRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        BusinessElectronicDocumentIssueResponse(
            document: BusinessDocument(
                id: "edoc_preview_invoice",
                saleId: saleId,
                type: "electronic_invoice",
                status: "AUTHORIZED",
                number: "001-001-000000123",
                authorizationNumber: "1234567890",
                accessKey: "1234567890123456789012345678901234567890123456789",
                customerEmail: "cliente@nexo.test",
                createdAt: Date(),
                authorizedAt: Date()
            ),
            authorized: true,
            stoppedBeforeSri: false,
            receptionStatus: "RECIBIDA",
            authorizationStatus: "AUTORIZADO",
            replayed: false
        )
    }

    func retryElectronicInvoiceReception(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceReceptionRequest
    ) async throws -> BusinessElectronicDocumentIssueResponse {
        BusinessElectronicDocumentIssueResponse(
            document: BusinessDocument(
                id: documentId,
                saleId: PreviewData.confirmedSaleResponse.sale.id,
                type: "electronic_invoice",
                status: "RECEIVED_BY_SRI",
                number: "001-001-000000123",
                accessKey: "1234567890123456789012345678901234567890123456789",
                customerEmail: "cliente@nexo.test",
                createdAt: Date()
            ),
            authorized: false,
            stoppedBeforeSri: false,
            receptionStatus: "RECIBIDA",
            authorizationStatus: nil,
            replayed: false
        )
    }

    func retryElectronicInvoiceAuthorization(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RetryBusinessElectronicInvoiceAuthorizationRequest
    ) async throws -> BusinessElectronicDocumentActionResponse {
        BusinessElectronicDocumentActionResponse(documentId: documentId, status: "queued", message: "Reintento de autorización solicitado.", requestedAt: Date())
    }

    func regenerateElectronicDocumentRide(
        organizationId: String,
        documentId: String,
        branchId: String?,
        activityId: String?,
        idempotencyKey: IdempotencyKey,
        request: RegenerateBusinessElectronicDocumentRideRequest
    ) async throws -> BusinessElectronicDocumentActionResponse {
        BusinessElectronicDocumentActionResponse(documentId: documentId, status: "queued", message: "Regeneración de RIDE solicitada.", requestedAt: Date())
    }

    func listElectronicDocuments(
        organizationId: String,
        filters: BusinessElectronicDocumentFilters
    ) async throws -> BusinessElectronicDocumentsResponse {
        BusinessElectronicDocumentsResponse(
            documents: [
                BusinessDocument(
                    id: "edoc_preview_invoice",
                    saleId: PreviewData.confirmedSaleResponse.sale.id,
                    type: "electronic_invoice",
                    status: "AUTHORIZED",
                    number: "001-001-000000123",
                    authorizationNumber: "1234567890123456789012345678901234567890123456789",
                    accessKey: "1234567890123456789012345678901234567890123456789",
                    customerEmail: "cliente@nexo.test",
                    createdAt: Date().addingTimeInterval(-3600),
                    authorizedAt: Date().addingTimeInterval(-3500),
                    documentId: "edoc_preview_invoice",
                    organizationId: organizationId,
                    branchId: PreviewData.businessContext.branches.first?.id,
                    environment: "test",
                    sriStatus: "AUTORIZADO",
                    issuedAt: Date().addingTimeInterval(-3600),
                    updatedAt: Date().addingTimeInterval(-3400),
                    rideGeneratedAt: Date().addingTimeInterval(-3400),
                    deliveredAt: Date().addingTimeInterval(-3300),
                    hasRide: true,
                    hasXml: true,
                    hasErrors: false,
                    lastSriReceptionStatus: "RECIBIDA",
                    lastSriAuthorizationStatus: "AUTORIZADO",
                    customerName: "Cliente Demo",
                    customerIdentification: "9999999999999",
                    total: "12.50"
                )
            ]
        )
    }

    func electronicDocumentDetail(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessElectronicDocumentDetailEnvelopeResponse {
        let summary = BusinessDocument(
            id: documentId,
            saleId: PreviewData.confirmedSaleResponse.sale.id,
            type: "electronic_invoice",
            status: "AUTHORIZED",
            number: "001-001-000000123",
            authorizationNumber: "1234567890123456789012345678901234567890123456789",
            accessKey: "1234567890123456789012345678901234567890123456789",
            customerEmail: "cliente@nexo.test",
            createdAt: Date().addingTimeInterval(-3600),
            authorizedAt: Date().addingTimeInterval(-3500),
            documentId: documentId,
            organizationId: organizationId,
            environment: "test",
            sriStatus: "AUTORIZADO",
            issuedAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3400),
            rideGeneratedAt: Date().addingTimeInterval(-3400),
            deliveredAt: Date().addingTimeInterval(-3300),
            hasRide: true,
            hasXml: true,
            hasErrors: false,
            lastSriReceptionStatus: "RECIBIDA",
            lastSriAuthorizationStatus: "AUTORIZADO",
            customerName: "Cliente Demo",
            customerIdentification: "9999999999999",
            total: "12.50"
        )

        let json = """
        {
          "document": {
            "id": "\(documentId)",
            "documentId": "\(documentId)",
            "summary": {
              "id": "\(documentId)",
              "saleId": "\(summary.saleId)",
              "documentType": "electronic_invoice",
              "displayNumber": "001-001-000000123",
              "accessKey": "1234567890123456789012345678901234567890123456789",
              "authorizationNumber": "1234567890123456789012345678901234567890123456789",
              "status": "AUTHORIZED",
              "sriStatus": "AUTORIZADO",
              "environment": "test",
              "issueDate": "2026-06-11T14:00:00Z",
              "authorizedAt": "2026-06-11T14:00:30Z",
              "updatedAt": "2026-06-11T14:01:00Z",
              "hasRide": true,
              "hasXml": true,
              "emailSentAt": "2026-06-11T14:02:00Z",
              "customerEmail": "cliente@nexo.test",
              "customerName": "Cliente Demo",
              "total": "12.50"
            },
            "organizationId": "\(organizationId)",
            "saleId": "\(summary.saleId)",
            "documentType": "electronic_invoice",
            "displayNumber": "001-001-000000123",
            "accessKey": "1234567890123456789012345678901234567890123456789",
            "authorizationNumber": "1234567890123456789012345678901234567890123456789",
            "customerName": "Cliente Demo",
            "customerIdentification": "9999999999999",
            "customerEmail": "cliente@nexo.test",
            "total": "12.50",
            "currency": "USD",
            "status": "AUTHORIZED",
            "sriStatus": "AUTORIZADO",
            "environment": "test",
            "issueDate": "2026-06-11T14:00:00Z",
            "authorizedAt": "2026-06-11T14:00:30Z",
            "updatedAt": "2026-06-11T14:01:00Z",
            "sri": {
              "environment": "test",
              "receptionStatus": "RECIBIDA",
              "authorizationStatus": "AUTORIZADO",
              "authorizationNumber": "1234567890123456789012345678901234567890123456789",
              "accessKey": "1234567890123456789012345678901234567890123456789",
              "authorizedAt": "2026-06-11T14:00:30Z",
              "lastCheckedAt": "2026-06-11T14:01:00Z"
            },
            "artifacts": {
              "ride": { "kind": "ride", "fileName": "001-001-000000123.pdf", "contentType": "application/pdf", "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
              "authorizedXml": { "kind": "authorizedXml", "fileName": "001-001-000000123-authorized.xml", "contentType": "application/xml", "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
              "xml": { "kind": "authorizedXml", "fileName": "001-001-000000123-authorized.xml", "contentType": "application/xml", "sha256": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" }
            },
            "email": {
              "recipient": "cliente@nexo.test",
              "status": "sent",
              "sentAt": "2026-06-11T14:02:00Z",
              "lastError": null,
              "attempts": 1
            },
            "timeline": [
              { "id": "evt_1", "type": "AUTHORIZED", "title": "Autorizado", "message": "Comprobante autorizado", "actor": "system", "createdAt": "2026-06-11T14:00:30Z", "severity": "info" }
            ],
            "errors": [],
            "warnings": [],
            "availableActions": ["view_detail", "view_timeline", "download_ride", "download_xml", "resend_email", "retry_reception", "retry_authorization", "regenerate_ride"],
            "retrySummary": {
              "canRetryReception": true,
              "canRetryAuthorization": true,
              "canResendEmail": true,
              "canRegenerateRide": true
            }
          }
        }
        """.data(using: .utf8)!
        return try JSONDecoder.nexoDefault.decode(BusinessElectronicDocumentDetailEnvelopeResponse.self, from: json)
    }

    func electronicDocumentRide(
        organizationId: String,
        documentId: String
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        let artifact = BusinessDocumentArtifact(
            kind: "ride",
            fileName: "001-001-000000123.pdf",
            contentType: "application/pdf",
            sizeBytes: 2048,
            sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        )
        return BusinessDocumentArtifactEnvelopeResponse(artifact: artifact, ride: artifact, xml: nil)
    }

    func electronicDocumentXml(
        organizationId: String,
        documentId: String,
        authorizedOnly: Bool
    ) async throws -> BusinessDocumentArtifactEnvelopeResponse {
        let artifact = BusinessDocumentArtifact(
            kind: authorizedOnly ? "authorizedXml" : "signedXml",
            fileName: authorizedOnly ? "001-001-000000123-authorized.xml" : "001-001-000000123-signed.xml",
            contentType: "application/xml",
            sizeBytes: 4096,
            sha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
        )
        return BusinessDocumentArtifactEnvelopeResponse(artifact: artifact, ride: nil, xml: artifact)
    }

    func electronicDocumentTimeline(
        organizationId: String,
        documentId: String,
        limit: Int
    ) async throws -> BusinessElectronicDocumentTimelineResponse {
        BusinessElectronicDocumentTimelineResponse(
            documentId: documentId,
            events: [
                BusinessElectronicDocumentTimelineEvent(
                    id: "evt_preview_1",
                    type: "AUTHORIZED",
                    title: "Autorizado",
                    message: "Comprobante autorizado por SRI.",
                    actor: "system",
                    createdAt: Date().addingTimeInterval(-3000),
                    severity: "info"
                )
            ]
        )
    }

    func resendElectronicDocumentEmail(
        organizationId: String,
        documentId: String,
        idempotencyKey: IdempotencyKey,
        request: BusinessDocumentEmailResendRequest
    ) async throws -> BusinessDocumentEmailResendResponse {
        BusinessDocumentEmailResendResponse(
            documentId: documentId,
            accepted: true,
            recipient: request.recipientOverride ?? "cliente@nexo.test",
            message: "Email reenviado.",
            requestedAt: Date()
        )
    }

}

final class PreviewReceivablesRepository: ReceivablesRepository, @unchecked Sendable {
    init() {}

    func list(
        organizationId: String,
        customerId: String?,
        status: String?,
        limit: Int
    ) async throws -> ReceivablesListResponse {
        let base = PreviewData.receivableResponse.receivable
        let receivables = [
            base,
            ReceivableRecord(
                id: "recv_preview_paid",
                saleId: PreviewData.confirmedSaleResponse.sale.id,
                customerId: "cus_preview",
                customerName: "Cliente preview",
                status: "paid",
                amount: MoneyAmount(amount: "12.00"),
                balance: MoneyAmount(amount: "0.00"),
                createdAt: Date().addingTimeInterval(-7200)
            )
        ]

        let filtered = customerId?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? receivables.filter { $0.customerId == customerId }
            : receivables

        return ReceivablesListResponse(
            receivables: Array(filtered.prefix(limit)),
            total: filtered.count,
            hasMore: filtered.count > limit
        )
    }

    func create(
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

    func collect(
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

final class PreviewPendingOperationsRepository: PendingOperationsRepository, @unchecked Sendable {
    init() {}

    func pendingSales(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingSalesResponse {
        PendingSalesResponse(
            sales: Array(PreviewData.pendingSalesResponse.sales.prefix(limit)),
            total: PreviewData.pendingSalesResponse.total
        )
    }

    func pendingReceivables(
        organizationId: String,
        branchId: String,
        limit: Int
    ) async throws -> PendingReceivablesResponse {
        PendingReceivablesResponse(
            receivables: Array(PreviewData.pendingReceivablesResponse.receivables.prefix(limit)),
            total: PreviewData.pendingReceivablesResponse.total
        )
    }

    func pendingDocuments(
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

final class PreviewBusinessDailyReportRepository: BusinessDailyReportRepository, @unchecked Sendable {
    init() {}

    func dailyReport(
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
