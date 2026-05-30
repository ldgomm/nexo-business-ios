//
//  BusinessDailyReportModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public struct BusinessDailyReport: Decodable, Equatable, Sendable {
    public let businessDate: String
    public let branchId: String?
    public let salesCount: Int?
    public let cancelledSalesCount: Int?
    public let salesTotal: MoneyAmount?
    public let paymentsCount: Int?
    public let paymentsTotal: MoneyAmount?
    public let cashExpectedAmount: MoneyAmount?
    public let receivablesPendingCount: Int?
    public let receivablesPendingTotal: MoneyAmount?
    public let receivablesOpenAmount: MoneyAmount?
    public let pendingSalesCount: Int?
    public let pendingDocumentsCount: Int?
    public let openReceivablesCount: Int?
    public let cashSessionId: String?
    public let cashSessionStatus: String?
    public let cashStatus: String?
    public let generatedAt: Date?
    
    public init(
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
        generatedAt: Date? = nil
    ) {
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
    }
    
    private enum CodingKeys: String, CodingKey {
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
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        businessDate = try container.decodeIfPresent(String.self, forKey: .businessDate)
        ?? container.decodeIfPresent(String.self, forKey: .date)
        ?? ""
        branchId = try container.decodeIfPresent(String.self, forKey: .branchId)
        salesCount = try container.decodeIfPresent(Int.self, forKey: .salesCount)
        cancelledSalesCount = try container.decodeIfPresent(Int.self, forKey: .cancelledSalesCount)
        salesTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .salesTotal)
        ?? container.decodeIfPresent(MoneyAmount.self, forKey: .totalSales)
        paymentsCount = try container.decodeIfPresent(Int.self, forKey: .paymentsCount)
        paymentsTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .paymentsTotal)
        ?? container.decodeIfPresent(MoneyAmount.self, forKey: .totalPayments)
        cashExpectedAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .cashExpectedAmount)
        ?? container.decodeIfPresent(MoneyAmount.self, forKey: .expectedCash)
        receivablesPendingCount = try container.decodeIfPresent(Int.self, forKey: .receivablesPendingCount)
        ?? container.decodeIfPresent(Int.self, forKey: .pendingReceivablesCount)
        receivablesPendingTotal = try container.decodeIfPresent(MoneyAmount.self, forKey: .receivablesPendingTotal)
        ?? container.decodeIfPresent(MoneyAmount.self, forKey: .pendingReceivablesTotal)
        receivablesOpenAmount = try container.decodeIfPresent(MoneyAmount.self, forKey: .receivablesOpenAmount)
        pendingSalesCount = try container.decodeIfPresent(Int.self, forKey: .pendingSalesCount)
        pendingDocumentsCount = try container.decodeIfPresent(Int.self, forKey: .pendingDocumentsCount)
        openReceivablesCount = try container.decodeIfPresent(Int.self, forKey: .openReceivablesCount)
        cashSessionId = try container.decodeIfPresent(String.self, forKey: .cashSessionId)
        cashSessionStatus = try container.decodeIfPresent(String.self, forKey: .cashSessionStatus)
        cashStatus = try container.decodeIfPresent(String.self, forKey: .cashStatus) ?? cashSessionStatus
        generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
    }
}

public struct BusinessDailyReportResponse: Decodable, Equatable, Sendable {
    public let report: BusinessDailyReport
    
    public init(report: BusinessDailyReport) {
        self.report = report
    }
    
    private enum CodingKeys: String, CodingKey {
        case report
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           let report = try? container.decode(BusinessDailyReport.self, forKey: .report) {
            self.report = report
            return
        }
        
        self.report = try BusinessDailyReport(from: decoder)
    }
}
