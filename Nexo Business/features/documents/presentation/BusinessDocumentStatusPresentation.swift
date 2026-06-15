//
//  BusinessDocumentStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 11/6/26.
//

import Foundation

enum BusinessDocumentStatusPresentation {
    
    static func isAuthorized(_ status: String?) -> Bool {
        guard let status else { return false }

        switch normalized(status) {
        case "authorized", "autorizado", "delivered", "sent_email", "email_sent":
            return true
        default:
            return false
        }
    }
    
    static func displayName(_ status: String) -> String {
        switch normalized(status) {
        case "not_required", "no_required", "none", "without_document", "sin_documento":
            return "Sin comprobante electrónico"
        case "draft":
            return "Borrador"
        case "generated", "access_key_generated":
            return "Clave generada"
        case "registered":
            return "Registrado"
        case "validated":
            return "Validado"
        case "signed":
            return "Firmado"
        case "sent", "submitted", "submitted_to_sri", "submitted_to_reception", "enviado":
            return "Enviado al SRI"
        case "received", "received_by_sri", "recibida", "received_by_tax_authority":
            return "Recibido por SRI"
        case "authorized", "autorizado":
            return "Autorizado"
        case "rejected", "rechazado", "not_authorized", "notauthorized", "no_autorizada":
            return "No autorizada"
        case "returned", "returned_by_sri", "devuelta":
            return "Devuelto por SRI"
        case "delivered", "sent_email", "email_sent":
            return "Enviado al cliente"
        case "delivery_failed", "email_failed":
            return "Error al enviar al cliente"
        case "cancellation_requested", "annulment_requested":
            return "Anulación solicitada"
        case "pending_cancellation", "pending_annulment":
            return "Pendiente de anular"
        case "canceled", "cancelled", "annulled":
            return "Anulado"
        case "signature_failed":
            return "Firma fallida"
        case "xsd_invalid":
            return "XML inválido"
        case "reception_transport_failed":
            return "Error de conexión con SRI"
        case "failed", "error":
            return "Fallido"
        default:
            return status.isEmpty ? "Desconocido" : humanized(status)
        }
    }

    static func systemImage(_ status: String) -> String {
        switch normalized(status) {
        case "not_required", "no_required", "none", "without_document", "sin_documento":
            return "doc"
        case "authorized", "autorizado", "delivered", "email_sent", "sent_email":
            return "checkmark.seal"
        case "generated", "access_key_generated", "registered", "draft":
            return "doc.badge.plus"
        case "rejected", "rechazado", "not_authorized", "notauthorized", "no_autorizada", "returned", "returned_by_sri", "devuelta", "signature_failed", "xsd_invalid", "reception_transport_failed", "error", "failed", "delivery_failed", "email_failed":
            return "exclamationmark.triangle"
        case "sent", "submitted", "submitted_to_sri", "submitted_to_reception", "received", "received_by_sri", "recibida", "signed", "validated":
            return "arrow.triangle.2.circlepath"
        case "canceled", "cancelled", "annulled", "pending_cancellation", "cancellation_requested", "annulment_requested":
            return "xmark.seal"
        default:
            return "doc.text"
        }
    }

    static func isError(_ status: String) -> Bool {
        switch normalized(status) {
        case "rejected", "rechazado", "not_authorized", "notauthorized", "no_autorizada", "returned", "returned_by_sri", "devuelta", "signature_failed", "xsd_invalid", "reception_transport_failed", "error", "failed", "delivery_failed", "email_failed":
            return true
        default:
            return false
        }
    }

    static func isMissingElectronicDocument(_ status: String?) -> Bool {
        guard let status else { return true }
        switch normalized(status) {
        case "not_required", "no_required", "none", "without_document", "sin_documento", "":
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

    private static func humanized(_ value: String) -> String {
        let cleaned = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()

        guard !cleaned.isEmpty else { return "Desconocido" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}
