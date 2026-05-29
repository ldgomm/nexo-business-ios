//
//  BusinessDocumentTypePresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessDocumentTypePresentation {
    public static func displayName(_ type: String) -> String {
        switch type {
        case "internal_ticket":
            return "Ticket interno"
        case "physical_sale_note":
            return "Nota de venta física"
        case "electronic_invoice":
            return "Factura electrónica"
        case "credit_note":
            return "Nota de crédito"
        case "debit_note":
            return "Nota de débito"
        case "withholding":
            return "Retención"
        case "remission_guide":
            return "Guía de remisión"
        default:
            return type
        }
    }

    public static func systemImage(_ type: String) -> String {
        switch type {
        case "internal_ticket":
            return "printer"
        case "physical_sale_note":
            return "doc.badge.plus"
        case "electronic_invoice":
            return "doc.text.magnifyingglass"
        default:
            return "doc.text"
        }
    }
}
