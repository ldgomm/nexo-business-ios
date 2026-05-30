//
//  ReceivableStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum ReceivableStatusPresentation {
    public static func displayName(_ status: String?) -> String {
        switch status {
        case "pending":
            return "Pendiente"
        case "open":
            return "Abierta"
        case "partially_collected":
            return "Cobro parcial"
        case "partial":
            return "Cobro parcial"
        case "collected":
            return "Cobrada"
        case "paid":
            return "Pagada"
        case "overdue":
            return "Vencida"
        case "canceled":
            return "Cancelada"
        case "cancelled":
            return "Cancelada"
        case "voided":
            return "Anulada"
        case "written_off":
            return "Castigada"
        case let value?:
            return value
        case nil:
            return "Sin estado"
        }
    }

    public static func canCollect(_ status: String?) -> Bool {
        switch status {
        case "collected", "paid", "canceled", "cancelled", "voided", "written_off":
            return false
        default:
            return true
        }
    }

    public static func systemImage(_ status: String?) -> String {
        switch status {
        case "collected", "paid":
            return "checkmark.circle"
        case "partially_collected", "partial":
            return "clock.badge.checkmark"
        case "overdue":
            return "exclamationmark.triangle"
        case "canceled", "cancelled", "voided", "written_off":
            return "xmark.circle"
        case "pending", "open":
            return "creditcard"
        default:
            return "creditcard"
        }
    }
}
