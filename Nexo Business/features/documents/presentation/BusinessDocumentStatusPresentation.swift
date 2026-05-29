//
//  BusinessDocumentStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum BusinessDocumentStatusPresentation {
    public static func displayName(_ status: String) -> String {
        switch status {
        case "not_required":
            return "No requerido"
        case "draft":
            return "Borrador"
        case "generated":
            return "Generado"
        case "registered":
            return "Registrado"
        case "validated":
            return "Validado"
        case "signed":
            return "Firmado"
        case "sent":
            return "Enviado"
        case "received":
            return "Recibido"
        case "authorized":
            return "Autorizado"
        case "rejected":
            return "Rechazado"
        case "returned":
            return "Devuelto"
        case "cancellation_requested":
            return "Anulación solicitada"
        case "pending_cancellation":
            return "Pendiente de anular"
        case "canceled":
            return "Anulado"
        case "error":
            return "Error"
        default:
            return status
        }
    }

    public static func systemImage(_ status: String) -> String {
        switch status {
        case "authorized", "generated", "registered":
            return "checkmark.seal"
        case "rejected", "returned", "error":
            return "exclamationmark.triangle"
        case "sent", "received", "signed", "validated":
            return "arrow.triangle.2.circlepath"
        case "canceled", "pending_cancellation", "cancellation_requested":
            return "xmark.seal"
        default:
            return "doc.text"
        }
    }
}
