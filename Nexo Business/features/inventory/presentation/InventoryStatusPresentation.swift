//
//  InventoryStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

enum InventoryStatusPresentation {
    static func displayName(_ item: InventoryItem) -> String {
        guard item.trackStock else { return "Sin control stock" }
        guard item.hasStockProfile else { return "Sin perfil de stock" }
        if decimal(item.available.quantity).map({ $0 <= .zero }) == true {
            return "Sin stock"
        }
        return displayName(item.stockStatus ?? item.status)
    }

    static func displayName(_ status: String?) -> String {
        switch normalized(status) {
        case "active", "available":
            return "Disponible"
        case "paused":
            return "Pausado"
        case "out_of_stock", "out-of-stock", "sold_out", "empty":
            return "Sin stock"
        case "low_stock", "low-stock":
            return "Stock bajo"
        case "untracked", "not_tracked", "no_stock_profile":
            return "Sin control stock"
        case "archived":
            return "Archivado"
        case let value?:
            return value
        case nil:
            return "Sin estado"
        }
    }

    static func stockSystemImage(_ item: InventoryItem) -> String {
        if !item.trackStock {
            return "info.circle"
        }

        switch normalized(item.stockStatus ?? item.status) {
        case "out_of_stock", "out-of-stock", "sold_out", "empty":
            return "xmark.circle"
        case "low_stock", "low-stock":
            return "exclamationmark.triangle"
        default:
            return "checkmark.circle"
        }
    }

    private static func normalized(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func decimal(_ value: String) -> Decimal? {
        Decimal(
            string: value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    static func movementDisplayName(_ type: String) -> String {
        switch normalized(type) ?? type {
        case "increase":
            return "Aumento"
        case "decrease":
            return "Disminución"
        case "set":
            return "Stock fijado"
        case "sale":
            return "Venta"
        case "return":
            return "Reverso"
        case "cancel_sale", "sale_cancellation":
            return "Cancelación de venta"
        case "adjustment", "manual_adjustment":
            return "Ajuste manual"
        case "transfer":
            return "Transferencia"
        case "damage", "damaged":
            return "Merma"
        case "reservation":
            return "Reserva"
        case "reservation_release", "release_reservation":
            return "Liberación de reserva"
        case "physical_count", "count_adjustment":
            return "Conteo físico"
        case "purchase", "purchase_receipt":
            return "Recepción de compra"
        default:
            return humanizedCode(type)
        }
    }

    static func sourceDisplayName(_ source: String?) -> String? {
        guard let source else { return nil }
        switch normalized(source) {
        case "sale": return "Venta"
        case "purchase", "purchase_receipt": return "Compra"
        case "manual_adjustment", "adjustment": return "Ajuste manual"
        case "transfer": return "Transferencia"
        case "physical_count", "count": return "Conteo físico"
        case "return": return "Devolución"
        case "reservation": return "Reserva"
        case "system": return "Sistema"
        default: return humanizedCode(source)
        }
    }

    static func humanizedCode(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
