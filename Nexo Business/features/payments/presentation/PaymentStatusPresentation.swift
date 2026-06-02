//
//  PaymentStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum PaymentStatusPresentation {
    static func displayName(_ status: String?) -> String {
        switch status {
        case "unpaid":
            return "Pendiente"
        case "partially_paid":
            return "Pago parcial"
        case "paid":
            return "Pagado"
        case "overpaid":
            return "Sobrepagado"
        case "refunded":
            return "Devuelto"
        case "voided":
            return "Anulado"
        case let value?:
            return value
        case nil:
            return "Sin estado"
        }
    }

    static func canCollect(status: String?) -> Bool {
        switch status {
        case "paid", "overpaid", "refunded", "voided":
            return false
        default:
            return true
        }
    }

    static func systemImage(_ status: String?) -> String {
        switch status {
        case "paid":
            return "checkmark.circle"
        case "partially_paid":
            return "clock.badge.checkmark"
        case "unpaid":
            return "dollarsign.circle"
        case "overpaid":
            return "plus.circle"
        case "refunded":
            return "arrow.uturn.backward.circle"
        case "voided":
            return "xmark.circle"
        default:
            return "dollarsign.circle"
        }
    }
}
