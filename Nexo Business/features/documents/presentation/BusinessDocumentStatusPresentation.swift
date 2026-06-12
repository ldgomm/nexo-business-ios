//
//  BusinessDocumentStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

enum BusinessDocumentStatusPresentation {
    static func displayName(_ status: String) -> String {
        switch normalized(status) {
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
        case "sent", "submitted", "submitted_to_sri":
            return "Enviado"
        case "received", "received_by_sri", "recibida":
            return "Recibido por SRI"
        case "authorized", "autorizado":
            return "Autorizado"
        case "rejected", "rechazado":
            return "Rechazado"
        case "returned", "devuelta":
            return "Devuelto"
        case "delivered", "sent_email", "email_sent":
            return "Email enviado"
        case "delivery_failed", "email_failed":
            return "Email fallido"
        case "cancellation_requested":
            return "Anulación solicitada"
        case "pending_cancellation":
            return "Pendiente de anular"
        case "canceled", "cancelled", "annulled":
            return "Anulado"
        case "failed", "error":
            return "Error"
        default:
            return status.isEmpty ? "Desconocido" : status
        }
    }

    static func systemImage(_ status: String) -> String {
        switch normalized(status) {
        case "authorized", "autorizado", "generated", "registered", "delivered", "email_sent", "sent_email":
            return "checkmark.seal"
        case "rejected", "rechazado", "returned", "devuelta", "error", "failed", "delivery_failed", "email_failed":
            return "exclamationmark.triangle"
        case "sent", "submitted", "submitted_to_sri", "received", "received_by_sri", "recibida", "signed", "validated":
            return "arrow.triangle.2.circlepath"
        case "canceled", "cancelled", "annulled", "pending_cancellation", "cancellation_requested":
            return "xmark.seal"
        default:
            return "doc.text"
        }
    }

    static func isError(_ status: String) -> Bool {
        switch normalized(status) {
        case "rejected", "rechazado", "returned", "devuelta", "error", "failed", "delivery_failed", "email_failed":
            return true
        default:
            return false
        }
    }

    private static func normalized(_ status: String) -> String {
        status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
    }
}
