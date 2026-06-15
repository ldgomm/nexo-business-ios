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
        case "not_required", "no_required", "none", "without_document", "sin_documento":
            return "Sin comprobante electrónico"
        case "draft":
            return "Borrador"
        case "access_key_generated":
            return "Clave generada"
        case "generated":
            return "Generado"
        case "registered":
            return "Registrado"
        case "validated":
            return "Validado"
        case "signed":
            return "Firmado"
        case "submitted_to_reception", "sent", "submitted", "submitted_to_sri", "enviado":
            return "Enviado al SRI"
        case "received", "received_by_sri", "recibida", "received_by_tax_authority":
            return "Recibido por SRI"
        case "authorized", "autorizado":
            return "Autorizado"
        case "not_authorized":
            return "No autorizada"
        case "rejected", "rechazado":
            return "Rechazado"
        case "returned", "returned_by_sri", "devuelta":
            return "Devuelto por SRI"
        case "delivered", "sent_email", "email_sent", "delivery_pending":
            return normalized(status) == "delivery_pending" ? "Pendiente de email" : "Enviado al cliente"
        case "delivery_failed", "email_failed":
            return "Error al enviar al cliente"
        case "signature_failed":
            return "Firma fallida"
        case "xsd_invalid":
            return "XML inválido"
        case "reception_transport_failed":
            return "Sin conexión con recepción SRI"
        case "authorization_transport_failed":
            return "Sin conexión con autorización SRI"
        case "cancellation_requested", "annulment_requested":
            return "Anulación solicitada"
        case "pending_cancellation", "pending_annulment":
            return "Pendiente de anular"
        case "canceled", "cancelled", "annulled":
            return "Anulado"
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
        case "authorized", "autorizado", "delivered", "email_sent", "sent_email", "delivery_pending":
            return "checkmark.seal"
        case "access_key_generated", "generated", "registered", "draft":
            return "doc.badge.plus"
        case "not_authorized", "rejected", "rechazado", "returned", "returned_by_sri", "devuelta", "error", "failed", "delivery_failed", "email_failed", "signature_failed", "xsd_invalid":
            return "exclamationmark.triangle"
        case "reception_transport_failed", "authorization_transport_failed":
            return "wifi.exclamationmark"
        case "submitted_to_reception", "sent", "submitted", "submitted_to_sri", "received", "received_by_sri", "recibida", "signed", "validated":
            return "arrow.triangle.2.circlepath"
        case "canceled", "cancelled", "annulled", "pending_cancellation", "cancellation_requested", "annulment_requested":
            return "xmark.seal"
        default:
            return "doc.text"
        }
    }

    static func isError(_ status: String) -> Bool {
        switch normalized(status) {
        case "not_authorized", "rejected", "rechazado", "returned", "returned_by_sri", "devuelta", "error", "failed", "delivery_failed", "email_failed", "signature_failed", "xsd_invalid", "reception_transport_failed", "authorization_transport_failed":
            return true
        default:
            return false
        }
    }

    static func isAuthorized(_ status: String?) -> Bool {
        guard let status else { return false }
        switch normalized(status) {
        case "authorized", "autorizado", "delivered", "delivery_pending", "email_sent", "sent_email":
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
