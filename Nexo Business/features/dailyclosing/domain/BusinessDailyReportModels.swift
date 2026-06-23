//
//  BusinessDailyReportModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

struct BusinessDailyReport: Decodable, Equatable, Sendable {
    let reportVersion: String?
    let businessDate: String
    let branchId: String?
    let salesCount: Int?
    let cancelledSalesCount: Int?
    let salesTotal: MoneyAmount?
    let paymentsCount: Int?
    let paymentsTotal: MoneyAmount?
    let cashExpectedAmount: MoneyAmount?
    let receivablesPendingCount: Int?
    let receivablesPendingTotal: MoneyAmount?
    let receivablesOpenAmount: MoneyAmount?
    let pendingSalesCount: Int?
    let pendingDocumentsCount: Int?
    let openReceivablesCount: Int?
    let cashSessionId: String?
    let cashSessionStatus: String?
    let cashStatus: String?
    let generatedAt: Date?
    let salesSummary: BusinessDailySalesSummary?
    let paymentSummary: BusinessDailyPaymentSummary?
    let cashSummary: BusinessDailyCashSummary?
    let productSummary: BusinessDailyProductSummary?
    let receivablesSummary: BusinessDailyReceivablesSummary?
    let documentSummary: BusinessDailyDocumentSummary?
    let alerts: [BusinessDailyAlert]

    init(
        reportVersion: String? = nil,
        businessDate: String,
        branchId: String? = nil,
        salesCount: Int? = nil,
        cancelledSalesCount: Int? = nil,
        salesTotal: MoneyAmount? = nil,
        paymentsCount: Int? = nil,
        paymentsTotal: MoneyAmount? = nil,
        cashExpectedAmount: MoneyAmount? = nil,
        receivablesPendingCount: Int? = nil,
        receivablesPendingTotal: MoneyAmount? = nil,
        receivablesOpenAmount: MoneyAmount? = nil,
        pendingSalesCount: Int? = nil,
        pendingDocumentsCount: Int? = nil,
        openReceivablesCount: Int? = nil,
        cashSessionId: String? = nil,
        cashSessionStatus: String? = nil,
        cashStatus: String? = nil,
        generatedAt: Date? = nil,
        salesSummary: BusinessDailySalesSummary? = nil,
        paymentSummary: BusinessDailyPaymentSummary? = nil,
        cashSummary: BusinessDailyCashSummary? = nil,
        productSummary: BusinessDailyProductSummary? = nil,
        receivablesSummary: BusinessDailyReceivablesSummary? = nil,
        documentSummary: BusinessDailyDocumentSummary? = nil,
        alerts: [BusinessDailyAlert] = []
    ) {
        self.reportVersion = reportVersion
        self.businessDate = businessDate
        self.branchId = branchId
        self.salesCount = salesCount
        self.cancelledSalesCount = cancelledSalesCount
        self.salesTotal = salesTotal
        self.paymentsCount = paymentsCount
        self.paymentsTotal = paymentsTotal
        self.cashExpectedAmount = cashExpectedAmount
        self.receivablesPendingCount = receivablesPendingCount
        self.receivablesPendingTotal = receivablesPendingTotal
        self.receivablesOpenAmount = receivablesOpenAmount
        self.pendingSalesCount = pendingSalesCount
        self.pendingDocumentsCount = pendingDocumentsCount
        self.openReceivablesCount = openReceivablesCount
        self.cashSessionId = cashSessionId
        self.cashSessionStatus = cashSessionStatus
        self.cashStatus = cashStatus
        self.generatedAt = generatedAt
        self.salesSummary = salesSummary
        self.paymentSummary = paymentSummary
        self.cashSummary = cashSummary
        self.productSummary = productSummary
        self.receivablesSummary = receivablesSummary
        self.documentSummary = documentSummary
        self.alerts = alerts
    }

    private enum CodingKeys: String, CodingKey {
        case reportVersion
        case businessDate
        case date
        case branchId
        case salesCount
        case cancelledSalesCount
        case salesTotal
        case totalSales
        case paymentsCount
        case paymentsTotal
        case totalPayments
        case cashExpectedAmount
        case expectedCash
        case receivablesPendingCount
        case pendingReceivablesCount
        case receivablesPendingTotal
        case pendingReceivablesTotal
        case receivablesOpenAmount
        case pendingSalesCount
        case pendingDocumentsCount
        case openReceivablesCount
        case cashSessionId
        case cashSessionStatus
        case cashStatus
        case generatedAt
        case salesSummary
        case paymentSummary
        case cashSummary
        case productSummary
        case receivablesSummary
        case documentSummary
        case alerts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reportVersion = try container.decodeIfPresent(String.self, forKey: .reportVersion)
        salesSummary = try container.decodeIfPresent(BusinessDailySalesSummary.self, forKey: .salesSummary)
        paymentSummary = try container.decodeIfPresent(BusinessDailyPaymentSummary.self, forKey: .paymentSummary)
        cashSummary = try container.decodeIfPresent(BusinessDailyCashSummary.self, forKey: .cashSummary)
        productSummary = try container.decodeIfPresent(BusinessDailyProductSummary.self, forKey: .productSummary)
        receivablesSummary = try container.decodeIfPresent(BusinessDailyReceivablesSummary.self, forKey: .receivablesSummary)
        documentSummary = try container.decodeIfPresent(BusinessDailyDocumentSummary.self, forKey: .documentSummary)
        alerts = try container.decodeIfPresent([BusinessDailyAlert].self, forKey: .alerts) ?? []

        businessDate = try container.decodeIfPresent(String.self, forKey: .businessDate)
            ?? container.decodeIfPresent(String.self, forKey: .date)
            ?? ""
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        salesCount = try container.decodeIfPresent(Int.self, forKey: .salesCount) ?? salesSummary?.count
        cancelledSalesCount = try container.decodeIfPresent(Int.self, forKey: .cancelledSalesCount) ?? salesSummary?.cancelledCount
        salesTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .salesTotal)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .totalSales)
            ?? salesSummary?.total
            ?? salesSummary?.grandTotal
        paymentsCount = try container.decodeIfPresent(Int.self, forKey: .paymentsCount) ?? paymentSummary?.count
        paymentsTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .paymentsTotal)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .totalPayments)
            ?? paymentSummary?.total
        cashExpectedAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .cashExpectedAmount)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .expectedCash)
            ?? cashSummary?.expectedAmount
        receivablesPendingCount = try container.decodeIfPresent(Int.self, forKey: .receivablesPendingCount)
            ?? container.decodeIfPresent(Int.self, forKey: .pendingReceivablesCount)
            ?? receivablesSummary?.openCount
        receivablesPendingTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .receivablesPendingTotal)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .pendingReceivablesTotal)
            ?? receivablesSummary?.openAmount
        receivablesOpenAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .receivablesOpenAmount)
            ?? receivablesSummary?.openAmount
        pendingSalesCount = try container.decodeIfPresent(Int.self, forKey: .pendingSalesCount)
        pendingDocumentsCount = try container.decodeIfPresent(Int.self, forKey: .pendingDocumentsCount)
            ?? documentSummary?.pendingCount
        openReceivablesCount = try container.decodeIfPresent(Int.self, forKey: .openReceivablesCount)
            ?? receivablesSummary?.openCount
        cashSessionId = try container.decodeIfPresent(String.self, forKey: .cashSessionId)
            ?? cashSummary?.cashSessionId
        cashSessionStatus = try container.decodeIfPresent(String.self, forKey: .cashSessionStatus)
            ?? cashSummary?.status
        cashStatus = try container.decodeIfPresent(String.self, forKey: .cashStatus)
            ?? cashSessionStatus
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
    }
}

struct BusinessDailySalesSummary: Decodable, Equatable, Sendable {
    let count: Int?
    let cancelledCount: Int?
    let subtotal: MoneyAmount?
    let discountTotal: MoneyAmount?
    let taxTotal: MoneyAmount?
    let total: MoneyAmount?
    let grandTotal: MoneyAmount?
}

struct BusinessDailyPaymentSummary: Decodable, Equatable, Sendable {
    let count: Int?
    let total: MoneyAmount?
    let cashTotal: MoneyAmount?
    let transferTotal: MoneyAmount?
    let cardTotal: MoneyAmount?
    let otherTotal: MoneyAmount?
}

struct BusinessDailyCashSummary: Decodable, Equatable, Sendable {
    let cashSessionId: String?
    let status: String?
    let openingAmount: MoneyAmount?
    let expectedAmount: MoneyAmount?
    let countedAmount: MoneyAmount?
    let differenceAmount: MoneyAmount?
    let inflowTotal: MoneyAmount?
    let outflowTotal: MoneyAmount?
}

struct BusinessDailyProductSummary: Decodable, Equatable, Sendable {
    let topProducts: [BusinessDailyTopProduct]
    let lowStockCount: Int?
    let outOfStockCount: Int?
    let movementCount: Int?

    init(topProducts: [BusinessDailyTopProduct] = [], lowStockCount: Int? = nil, outOfStockCount: Int? = nil, movementCount: Int? = nil) {
        self.topProducts = topProducts
        self.lowStockCount = lowStockCount
        self.outOfStockCount = outOfStockCount
        self.movementCount = movementCount
    }
}

struct BusinessDailyTopProduct: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let quantity: String?
    let total: MoneyAmount?

    private enum CodingKeys: String, CodingKey {
        case id
        case productId
        case itemId
        case name
        case productName
        case quantity
        case soldQuantity
        case total
        case salesTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .productId)
            ?? container.decodeIfPresent(String.self, forKey: .itemId)
            ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .productName)
            ?? "Producto"
        if let quantity = try? container.decodeIfPresent(String.self, forKey: .quantity) {
            self.quantity = quantity
        } else if let quantity = try? container.decodeIfPresent(String.self, forKey: .soldQuantity) {
            self.quantity = quantity
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .quantity) {
            self.quantity = String(intValue)
        } else if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .quantity) {
            self.quantity = String(doubleValue)
        } else {
            self.quantity = nil
        }
        total = try container.decodeIfPresent(MoneyAmount.self, forKey: .total)
            ?? container.decodeIfPresent(MoneyAmount.self, forKey: .salesTotal)
    }
}

struct BusinessDailyReceivablesSummary: Decodable, Equatable, Sendable {
    let openCount: Int?
    let openAmount: MoneyAmount?
    let overdueCount: Int?
    let overdueAmount: MoneyAmount?
    let collectedTotal: MoneyAmount?
}

struct BusinessDailyDocumentSummary: Decodable, Equatable, Sendable {
    let issuedCount: Int?
    let authorizedCount: Int?
    let pendingCount: Int?
    let failedCount: Int?
}

struct BusinessDailyAlert: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let severity: String?
    let code: String?
    let title: String
    let message: String?
    let action: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case severity
        case level
        case code
        case title
        case message
        case detail
        case action
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(String.self, forKey: .code)
        severity = try container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .level)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? code
            ?? "Alerta"
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .detail)
        action = try container.decodeIfPresent(String.self, forKey: .action)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? [severity, code, title, message].compactMap { $0 }.joined(separator: "|")
    }
}

struct BusinessDailyReportResponse: Decodable, Equatable, Sendable {
    let report: BusinessDailyReport

    init(report: BusinessDailyReport) {
        self.report = report
    }

    private enum CodingKeys: String, CodingKey {
        case report
        case dailyReport
        case data
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let report = try? container.decode(BusinessDailyReport.self, forKey: .report) {
                self.report = report
                return
            }
            if let report = try? container.decode(BusinessDailyReport.self, forKey: .dailyReport) {
                self.report = report
                return
            }
            if let report = try? container.decode(BusinessDailyReport.self, forKey: .data) {
                self.report = report
                return
            }
        }

        self.report = try BusinessDailyReport(from: decoder)
    }
}
