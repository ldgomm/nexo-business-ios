//
//  PaymentStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PaymentStatusPresentation {
    static func displayName(_ status: String?) -> String {
        switch normalized(status) {
        case "unpaid", "pending", "pending_payment":
            return "Pendiente de cobro"
        case "partially_paid", "partial", "partial_payment":
            return "Cobro parcial"
        case "paid", "collected", "registered", "confirmed":
            return "Cobrado"
        case "overpaid":
            return "Cobrado en exceso"
        case "refunded":
            return "Devuelto"
        case "reversed":
            return "Reversado"
        case "voided", "cancelled", "canceled", "annulled":
            return "Anulado"
        case let value?:
            return humanized(value)
        case nil:
            return "Sin estado de cobro"
        }
    }

    static func shortName(_ status: String?) -> String {
        switch normalized(status) {
        case "unpaid", "pending", "pending_payment":
            return "Pendiente"
        case "partially_paid", "partial", "partial_payment":
            return "Parcial"
        case "paid", "collected", "registered", "confirmed":
            return "Cobrado"
        case "overpaid":
            return "Exceso"
        case "refunded":
            return "Devuelto"
        case "reversed":
            return "Reversado"
        case "voided", "cancelled", "canceled", "annulled":
            return "Anulado"
        case let value?:
            return humanized(value)
        case nil:
            return "Sin estado"
        }
    }

    static func canCollect(status: String?) -> Bool {
        switch normalized(status) {
        case "paid", "collected", "overpaid", "refunded", "reversed", "voided", "cancelled", "canceled", "annulled":
            return false
        default:
            return true
        }
    }

    static func isPendingCollection(_ status: String?) -> Bool {
        switch normalized(status) {
        case "unpaid", "pending", "pending_payment", "partially_paid", "partial", "partial_payment":
            return true
        default:
            return false
        }
    }

    static func isCollected(_ status: String?) -> Bool {
        switch normalized(status) {
        case "paid", "collected", "registered", "confirmed", "overpaid":
            return true
        default:
            return false
        }
    }

    static func systemImage(_ status: String?) -> String {
        switch normalized(status) {
        case "paid", "collected", "registered", "confirmed":
            return "checkmark.circle"
        case "partially_paid", "partial", "partial_payment":
            return "clock.badge.checkmark"
        case "unpaid", "pending", "pending_payment":
            return "dollarsign.circle"
        case "overpaid":
            return "plus.circle"
        case "refunded", "reversed":
            return "arrow.uturn.backward.circle"
        case "voided", "cancelled", "canceled", "annulled":
            return "xmark.circle"
        default:
            return "dollarsign.circle"
        }
    }

    private static func normalized(_ status: String?) -> String? {
        guard let status else { return nil }
        let value = status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
        return value.isEmpty ? nil : value
    }

    private static func humanized(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()

        guard !cleaned.isEmpty else { return "Sin estado" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}
