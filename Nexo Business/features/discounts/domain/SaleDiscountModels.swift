//
//  SaleDiscountModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

struct ApplySaleDiscountInput: Encodable, Equatable, Sendable {
    let scope: SaleDiscountScope
    let targetLineIds: Set<String>
    let type: SaleDiscountType
    let value: String
    let reason: String?
}

enum SaleDiscountScope: String, Codable, CaseIterable, Sendable {
    case item = "ITEM"
    case selectedItems = "SELECTED_ITEMS"
    case sale = "SALE"
}

enum SaleDiscountType: String, Codable, CaseIterable, Sendable {
    case amount = "AMOUNT"
    case percentage = "PERCENTAGE"
}

struct SaleDiscountPreview: Decodable, Equatable, Sendable {
    let saleId: String
    let subtotalBeforeDiscount: MoneyAmount
    let discountTotal: MoneyAmount
    let subtotalAfterDiscount: MoneyAmount
    let taxTotal: MoneyAmount
    let grandTotal: MoneyAmount
    let discounts: [SaleDiscountSummary]
    let taxSummary: [SaleTaxSummaryLine]
    let lineBreakdown: [SaleLineDiscountBreakdown]
}

struct SaleDiscountSummary: Identifiable, Decodable, Equatable, Sendable {
    let id: String
    let scope: String
    let targetLineIds: Set<String>
    let type: String
    let value: String
    let allocatedAmount: MoneyAmount
    let reason: String?
    let appliedBy: String
    let appliedAt: Date
}

struct SaleTaxSummaryLine: Decodable, Equatable, Sendable {
    let taxCode: String
    let rateCode: String
    let rate: String
    let base: MoneyAmount
    let taxAmount: MoneyAmount
}

struct SaleLineDiscountBreakdown: Identifiable, Decodable, Equatable, Sendable {
    let lineId: String
    let grossSubtotal: MoneyAmount
    let discountTotal: MoneyAmount
    let netSubtotalBeforeTax: MoneyAmount
    let taxTotal: MoneyAmount
    let lineTotal: MoneyAmount

    var id: String { lineId }
}
