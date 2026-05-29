//
//  SaleStatusPresentation.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation
import SwiftUI

public enum SaleStatusPresentation {
    public static func title(for status: String) -> String {
        switch status.lowercased() {
        case "draft":
            return "Borrador"
        case "pending":
            return "Pendiente"
        case "confirmed":
            return "Confirmada"
        case "in_progress":
            return "En proceso"
        case "ready":
            return "Lista"
        case "delivered":
            return "Entregada"
        case "closed":
            return "Cerrada"
        case "canceled", "cancelled":
            return "Cancelada"
        default:
            return status
        }
    }

    public static func systemImage(for status: String) -> String {
        switch status.lowercased() {
        case "confirmed", "closed", "delivered":
            return "checkmark.circle.fill"
        case "canceled", "cancelled":
            return "xmark.circle.fill"
        case "pending", "draft":
            return "clock"
        case "in_progress", "ready":
            return "bolt.circle.fill"
        default:
            return "circle"
        }
    }

    public static func canConfirm(status: String) -> Bool {
        !["confirmed", "closed", "canceled", "cancelled"].contains(status.lowercased())
    }

    public static func canCancel(status: String) -> Bool {
        !["closed", "canceled", "cancelled"].contains(status.lowercased())
    }

    public static func canCollect(status: String) -> Bool {
        switch status.lowercased() {
        case "confirmed", "closed", "delivered", "ready", "in_progress", "pending":
            return true
        case "canceled", "cancelled":
            return false
        default:
            return status.lowercased() != "canceled"
        }
    }

}

public struct SaleStatusLabel: View {
    private let status: String

    public init(status: String) {
        self.status = status
    }

    public var body: some View {
        Label(
            SaleStatusPresentation.title(for: status),
            systemImage: SaleStatusPresentation.systemImage(for: status)
        )
        .font(.subheadline.weight(.semibold))
    }
}
