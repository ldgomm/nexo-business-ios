//
//  BusinessFinanceAmountFormatter.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/7/26.
//

import Foundation

struct BusinessFinanceAmountFormatter: Sendable {
    func string(
        from amount: BusinessFinanceAmount,
        localeIdentifier: String
    ) -> String? {
        let currencyCode = amount.currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let localeValue = localeIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard currencyCode.count == 3,
              !localeValue.isEmpty,
              let decimal = Decimal(
                string: amount.decimalValue,
                locale: Locale(identifier: "en_US_POSIX")
              ) else {
            return nil
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: localeValue)
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.generatesDecimalNumbers = true

        return formatter.string(from: decimal as NSDecimalNumber)
            ?? "\(currencyCode) \(amount.decimalValue)"
    }
}

