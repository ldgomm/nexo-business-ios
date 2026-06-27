//
//  SaleStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import SwiftUI

enum SaleStatusPresentation {
    static func title(for status: String) -> String {
        switch normalized(status) {
        case "draft":
            return "Borrador"
        case "pending":
            return "Registrada"
        case "confirmed":
            return "Confirmada"
        case "in_progress":
            return "En proceso"
        case "ready":
            return "Lista"
        case "delivered":
            return "Entregada"
        case "closed", "closed_day", "day_closed":
            return "Cerrada"
        case "canceled", "cancelled", "voided", "annulled", "cancelled_internal", "canceled_internal":
            return "Cancelada"
        default:
            return humanized(status)
        }
    }

    static func systemImage(for status: String) -> String {
        switch normalized(status) {
        case "confirmed", "delivered", "ready":
            return "checkmark.circle.fill"
        case "closed", "closed_day", "day_closed":
            return "lock.circle.fill"
        case "canceled", "cancelled", "voided", "annulled", "cancelled_internal", "canceled_internal":
            return "xmark.circle.fill"
        case "pending", "draft":
            return "clock"
        case "in_progress":
            return "bolt.circle.fill"
        default:
            return "circle"
        }
    }

    static func canConfirm(status: String) -> Bool {
        switch normalized(status) {
        case "draft", "borrador":
            return true
        default:
            return false
        }
    }

    static func canCancel(status: String) -> Bool {
        !isTerminal(status: status)
    }

    static func canCollect(status: String) -> Bool {
        switch normalized(status) {
        case "confirmed", "delivered", "ready", "in_progress", "pending":
            return true
        case "draft", "borrador":
            return false
        default:
            return false
        }
    }

    static func isTerminal(status: String) -> Bool {
        [
            "closed",
            "closed_day",
            "day_closed",
            "canceled",
            "cancelled",
            "voided",
            "annulled",
            "cancelled_internal",
            "canceled_internal"
        ].contains(normalized(status))
    }

    static func requiresConfirmationBeforeCollection(status: String) -> Bool {
        switch normalized(status) {
        case "draft", "borrador":
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

        guard !cleaned.isEmpty else { return "Sin estado" }
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
}

struct SaleStatusLabel: View {
    private let status: String

    init(status: String) {
        self.status = status
    }

    var body: some View {
        Label(
            SaleStatusPresentation.title(for: status),
            systemImage: SaleStatusPresentation.systemImage(for: status)
        )
        .font(.subheadline.weight(.semibold))
    }
}
