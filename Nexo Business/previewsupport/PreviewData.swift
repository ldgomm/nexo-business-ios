//
//  PreviewData.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PreviewData {
    static let revisions = BusinessRevisions(
        catalogRevision: "cat_rev_preview",
        taxConfigurationRevision: "tax_rev_preview"
    )

    static let businessContext = BusinessContextResponse(
        user: BusinessUser(
            id: "usr_preview",
            displayName: "Operador Preview",
            email: "operador@nexo.test"
        ),
        organization: BusinessOrganization(
            id: "org_altos",
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
                id: "act_retail_store",
                code: BusinessActivityTemplateCode.retailStore,
                name: "Retail store",
                activityType: BusinessActivityTemplateCode.retailStore,
                workflowMode: "quick_sale",
                status: "active"
            ),
            BusinessActivity(
                id: "act_tech_store",
                code: BusinessActivityTemplateCode.techStore,
                name: "Tech store",
                activityType: BusinessActivityTemplateCode.techStore,
                workflowMode: "quick_sale",
                status: "active"
            ),
            BusinessActivity(
                id: "act_hardware_store",
                code: BusinessActivityTemplateCode.hardwareStore,
                name: "Hardware store",
                activityType: BusinessActivityTemplateCode.hardwareStore,
                workflowMode: "quick_sale",
                status: "draft"
            ),
            BusinessActivity(
                id: "act_bookstore",
                code: BusinessActivityTemplateCode.bookstore,
                name: "Bookstore",
                activityType: BusinessActivityTemplateCode.bookstore,
                workflowMode: "quick_sale",
                status: "draft"
            ),
            BusinessActivity(
                id: "act_service_repair",
                code: BusinessActivityTemplateCode.serviceRepair,
                name: "Service repair",
                activityType: BusinessActivityTemplateCode.serviceRepair,
                workflowMode: "service_order",
                status: "draft"
            )
        ],
        activeModules: [
            .coreSales,
            .coreCash,
            .coreDocuments,
            .coreReceivables,
            .foundationIdempotency,
            .foundationCatalogRevision,
            .foundationTaxRevision
        ],
        effectivePermissions: [
            "business.sales.create",
            "business.sales.preview",
            "business.sales.confirm",
            "business.sales.cancel",
            "business.sales.view",
            "sales.create",
            "sales.confirm",
            "sales.cancel",
            "sales.view",
            "business.customers.view",
            "business.customers.create",
            "customers.view",
            "customers.create",
            "cash.open",
            "cash.close",
            "cash.view_current",
            "cash.register_inflow",
            "cash.register_outflow",
            "business.cash.open",
            "business.cash.close",
            "business.cash.view_current",
            "business.cash.register_inflow",
            "business.cash.register_outflow",
            "business.payments.collect",
            "business.payments.register",
            "payments.collect",
            "payments.register",
            "business.receivables.view",
            "business.receivables.create",
            "business.receivables.collect",
            "receivables.view",
            "receivables.create",
            "receivables.collect",
            "business.payments.mark_as_credit",
            "business.documents.view",
            "documents.view",
            "business.documents.issue_internal_ticket",
            "documents.issue_internal_ticket",
            "business.documents.register_physical_sale_note",
            "documents.register_physical_sale_note",
            "business.reports.today",
            "reports.today"
        ],
        revisions: revisions,
        readiness: BusinessReadiness(
            status: "ready",
            score: 100,
            blockers: [],
            warnings: []
        )
    )

    static let operationalSelection = BusinessOperationalSelection(
        organizationId: businessContext.organization.id,
        branchId: businessContext.branches[0].id,
        activityId: businessContext.activities[0].id
    )

    static let catalogItems = [
        BusinessCatalogItem(
            id: "item_cuy_entero",
            name: "Cuy entero",
            itemDescription: "Plato principal de restaurante.",
            sku: "CUY-ENTERO",
            barcode: nil,
            type: "product",
            status: "active",
            unit: BusinessCatalogUnit(code: "unit", name: "Unidad", allowsDecimal: false),
            price: MoneyAmount(amount: "24.00"),
            taxProfileCode: "altos_staging_iva_current_full",
            taxProfileName: "IVA tarifa vigente completa",
            availableStock: "10",
            allowsDecimalQuantity: false
        ),
        BusinessCatalogItem(
            id: "item_borrego",
            name: "Borrego asado",
            itemDescription: "Porción de borrego asado.",
            sku: "BORREGO",
            barcode: nil,
            type: "product",
            status: "active",
            unit: BusinessCatalogUnit(code: "unit", name: "Unidad", allowsDecimal: false),
            price: MoneyAmount(amount: "10.00"),
            taxProfileCode: "altos_staging_iva_tourism_8",
            taxProfileName: "IVA turismo 8%",
            availableStock: "20",
            allowsDecimalQuantity: false
        )
    ]

    static let totals = BusinessSaleTotals(
        subtotal: MoneyAmount(amount: "24.00"),
        discount: MoneyAmount(amount: "0.00"),
        tax: MoneyAmount(amount: "1.92"),
        total: MoneyAmount(amount: "25.92")
    )

    static let previewItems = [
        BusinessSaleItem(
            id: "line_001",
            catalogItemId: "item_cuy_entero",
            name: "Cuy entero",
            quantity: "1",
            unitPrice: MoneyAmount(amount: "24.00"),
            subtotal: MoneyAmount(amount: "24.00"),
            total: MoneyAmount(amount: "25.92"),
            taxProfileCode: "altos_staging_iva_tourism_8",
            taxProfileName: "IVA turismo 8%",
            taxTreatment: "IVA_REDUCED_TOURISM",
            taxRate: "8.00",
            sriTaxCode: "2",
            sriRateCode: "8",
            taxableBase: MoneyAmount(amount: "24.00"),
            taxAmount: MoneyAmount(amount: "1.92"),
            note: nil
        )
    ]

    static let previewResponse = SalesPreviewResponse(
        items: previewItems,
        totals: totals,
        warnings: []
    )

    static let quickSaleResponse = QuickSaleResponse(
        sale: BusinessSale(
            id: "sale_preview_001",
            number: "V-000000001",
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: BusinessSaleCustomer(
                id: PreviewCustomersData.customers[1].id,
                displayName: PreviewCustomersData.customers[1].displayName,
                identification: PreviewCustomersData.customers[1].identificationNumber
            ),
            status: "pending",
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: totals,
            items: previewItems,
            createdAt: Date()
        ),
        idempotencyReplayed: false
    )

    static let confirmedSaleResponse = ConfirmSaleResponse(
        sale: BusinessSale(
            id: quickSaleResponse.sale.id,
            number: quickSaleResponse.sale.number,
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: quickSaleResponse.sale.customer,
            status: "confirmed",
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: totals,
            items: previewItems,
            createdAt: quickSaleResponse.sale.createdAt,
            confirmedAt: Date()
        ),
        idempotencyReplayed: false
    )

    static let canceledSaleResponse = CancelSaleResponse(
        sale: BusinessSale(
            id: quickSaleResponse.sale.id,
            number: quickSaleResponse.sale.number,
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: quickSaleResponse.sale.customer,
            status: "canceled",
            paymentStatus: "unpaid",
            documentStatus: "not_required",
            totals: totals,
            items: previewItems,
            createdAt: quickSaleResponse.sale.createdAt,
            updatedAt: Date()
        ),
        idempotencyReplayed: false
    )

    static let paymentResponse = PaymentResponse(
        payment: PaymentRecord(
            id: "pay_preview",
            saleId: confirmedSaleResponse.sale.id,
            status: "registered",
            method: "cash",
            amount: confirmedSaleResponse.sale.totals.grandTotal,
            registeredAt: Date()
        ),
        sale: BusinessSale(
            id: confirmedSaleResponse.sale.id,
            number: confirmedSaleResponse.sale.number,
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: confirmedSaleResponse.sale.customer,
            status: "confirmed",
            paymentStatus: "paid",
            documentStatus: "not_required",
            totals: totals,
            items: previewItems,
            createdAt: quickSaleResponse.sale.createdAt,
            confirmedAt: confirmedSaleResponse.sale.confirmedAt
        ),
        idempotencyReplayed: false
    )

    static let receivableResponse = ReceivableResponse(
        receivable: ReceivableRecord(
            id: "recv_preview",
            saleId: confirmedSaleResponse.sale.id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            branchId: businessContext.branches[0].id,
            status: "pending",
            amount: confirmedSaleResponse.sale.totals.grandTotal,
            balance: confirmedSaleResponse.sale.totals.grandTotal,
            originalAmount: confirmedSaleResponse.sale.totals.grandTotal,
            paidAmount: MoneyAmount(amount: "0.00"),
            remainingAmount: confirmedSaleResponse.sale.totals.grandTotal,
            dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            createdAt: Date()
        ),
        idempotencyReplayed: false
    )

    static let internalTicketDocument = BusinessDocument(
        id: "doc_preview_ticket",
        saleId: confirmedSaleResponse.sale.id,
        type: "internal_ticket",
        status: "generated",
        number: "T-001",
        createdAt: Date()
    )

    static let physicalSaleNoteDocument = BusinessDocument(
        id: "doc_preview_note",
        saleId: confirmedSaleResponse.sale.id,
        type: "physical_sale_note",
        status: "registered",
        number: "001-001-000000123",
        createdAt: Date()
    )

    static let businessDocumentsResponse = BusinessDocumentsResponse(
        documents: [
            internalTicketDocument,
            physicalSaleNoteDocument
        ]
    )

    static let internalTicketDocumentResponse = BusinessDocumentResponse(
        document: internalTicketDocument,
        sale: BusinessSale(
            id: confirmedSaleResponse.sale.id,
            number: confirmedSaleResponse.sale.number,
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: confirmedSaleResponse.sale.customer,
            status: confirmedSaleResponse.sale.status,
            paymentStatus: confirmedSaleResponse.sale.paymentStatus,
            documentStatus: "generated",
            totals: totals,
            items: previewItems,
            createdAt: quickSaleResponse.sale.createdAt,
            confirmedAt: confirmedSaleResponse.sale.confirmedAt
        ),
        idempotencyReplayed: false
    )

    static let physicalSaleNoteDocumentResponse = BusinessDocumentResponse(
        document: physicalSaleNoteDocument,
        sale: BusinessSale(
            id: confirmedSaleResponse.sale.id,
            number: confirmedSaleResponse.sale.number,
            organizationId: businessContext.organization.id,
            branchId: businessContext.branches[0].id,
            activityId: businessContext.activities[0].id,
            customerId: PreviewCustomersData.customers[1].id,
            customerName: PreviewCustomersData.customers[1].displayName,
            customer: confirmedSaleResponse.sale.customer,
            status: confirmedSaleResponse.sale.status,
            paymentStatus: confirmedSaleResponse.sale.paymentStatus,
            documentStatus: "registered",
            totals: totals,
            items: previewItems,
            createdAt: quickSaleResponse.sale.createdAt,
            confirmedAt: confirmedSaleResponse.sale.confirmedAt
        ),
        idempotencyReplayed: false
    )
}
