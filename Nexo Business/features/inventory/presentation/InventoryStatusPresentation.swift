//
//  InventoryStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum InventoryStatusPresentation {
    public static func displayName(_ status: String?) -> String {
        switch status {
        case "active":
            return "Activo"
        case "paused":
            return "Pausado"
        case "out_of_stock":
            return "Sin stock"
        case "low_stock":
            return "Stock bajo"
        case "archived":
            return "Archivado"
        case let value?:
            return value
        case nil:
            return "Sin estado"
        }
    }

    public static func stockSystemImage(_ item: InventoryItem) -> String {
        switch item.stockStatus {
        case "out_of_stock":
            return "xmark.circle"
        case "low_stock":
            return "exclamationmark.triangle"
        default:
            return "checkmark.circle"
        }
    }

    public static func movementDisplayName(_ type: String) -> String {
        switch type {
        case "increase":
            return "Aumento"
        case "decrease":
            return "Disminución"
        case "set":
            return "Stock fijado"
        case "sale":
            return "Venta"
        case "cancel_sale":
            return "Cancelación de venta"
        case "adjustment":
            return "Ajuste"
        default:
            return type
        }
    }
}
