//
//  NexoOperationUI.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/6/26.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum NexoMessageStyle: Sendable {
    case success
    case info
    case warning
    case error

    var systemImage: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .success:
            return .green
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

struct NexoMessageBanner: View {
    private let message: String
    private let style: NexoMessageStyle

    init(_ message: String, style: NexoMessageStyle) {
        self.message = message
        self.style = style
    }

    var body: some View {
        Label(message, systemImage: style.systemImage)
            .font(.footnote)
            .foregroundStyle(style.foregroundStyle)
            .multilineTextAlignment(.leading)
    }
}

struct NexoStatusBadge: View {
    private let text: String
    private let systemImage: String
    private let style: NexoMessageStyle

    init(
        _ text: String,
        systemImage: String = "circle.fill",
        style: NexoMessageStyle = .info
    ) {
        self.text = text
        self.systemImage = systemImage
        self.style = style
    }

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style.foregroundStyle)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(style.foregroundStyle.opacity(0.12), in: Capsule())
    }
}

struct NexoMoneyTotalView: View {
    private let title: String
    private let amount: MoneyAmount
    private let isProminent: Bool

    init(
        title: String,
        amount: MoneyAmount,
        isProminent: Bool = false
    ) {
        self.title = title
        self.amount = amount
        self.isProminent = isProminent
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(isProminent ? .primary : .secondary)
            Spacer()
            Text(amount.displayText)
                .font(isProminent ? .title3.weight(.bold) : .body.weight(.semibold))
                .monospacedDigit()
        }
    }
}

struct NexoSaleSuccessCard: View {
    private let sale: BusinessSale

    init(sale: BusinessSale) {
        self.sale = sale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Venta registrada")
                        .font(.headline)
                    Text(sale.displayNumber)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(sale.totals.grandTotal.displayText)
                    .font(.headline.weight(.bold))
                    .monospacedDigit()
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(sale.displayCustomerName, systemImage: "person.crop.circle")
                Label(PaymentStatusPresentation.displayName(sale.paymentStatus), systemImage: "dollarsign.circle")
                if !sale.displayItemsSummary.isEmpty {
                    Label(sale.displayItemsSummary, systemImage: "cart")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

extension MoneyAmount {
    var displayText: String {
        "\(currency) \(amount)"
    }
}

extension CashSession {
    var isOpen: Bool {
        status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "open"
    }

    var displayStatus: String {
        isOpen ? "Caja abierta" : "Caja cerrada"
    }
}

extension BusinessSale {
    var displayNumber: String {
        let cleanNumber = number?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cleanNumber, !cleanNumber.isEmpty {
            return cleanNumber
        }
        return id
    }

    var compactDisplayNumber: String {
        let cleanNumber = number?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cleanNumber, !cleanNumber.isEmpty {
            return cleanNumber
        }
        return String(id.suffix(10))
    }

    var displayCustomerName: String {
        if let name = customer?.displayName.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let customerName = customerName?.trimmingCharacters(in: .whitespacesAndNewlines), !customerName.isEmpty {
            return customerName
        }
        return "Consumidor final"
    }

    var needsCollection: Bool {
        SaleStatusPresentation.canCollect(status: status) &&
        PaymentStatusPresentation.canCollect(status: paymentStatus)
    }

    func replacingPaymentStatus(_ paymentStatus: String?) -> BusinessSale {
        BusinessSale(
            id: id,
            number: number,
            organizationId: organizationId,
            branchId: branchId,
            activityId: activityId,
            customerId: customerId,
            customerName: customerName,
            customer: customer,
            status: status,
            paymentStatus: paymentStatus,
            documentStatus: documentStatus,
            totals: totals,
            items: items,
            createdAt: createdAt,
            confirmedAt: confirmedAt,
            closedAt: closedAt,
            updatedAt: Date()
        )
    }

    var displayItemsSummary: String {
        guard !items.isEmpty else { return "" }

        let firstItems = items.prefix(2).map { item in
            "\(item.name) x\(item.quantity.cleanQuantityText)"
        }

        if items.count > 2 {
            return firstItems.joined(separator: " · ") + " · +\(items.count - 2) más"
        }

        return firstItems.joined(separator: " · ")
    }
}

extension String {
    var cleanQuantityText: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix(".000000") else { return trimmed }
        return String(trimmed.dropLast(7))
    }

    var nilIfBlankForUI: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}


extension BusinessSalePriceTaxMode {
    var displayName: String {
        switch self {
        case .taxExclusive:
            return "Precio + IVA"
        case .taxInclusive:
            return "Precio incluye IVA"
        }
    }

    var shortDisplayName: String {
        switch self {
        case .taxExclusive:
            return "+ IVA"
        case .taxInclusive:
            return "IVA incluido"
        }
    }
}

enum NexoKeyboard {
    static func dismiss() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

extension View {
    @ViewBuilder
    func nexoKeyboardDismissable() -> some View {
        if #available(iOS 16.0, *) {
            self
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Ocultar") {
                            NexoKeyboard.dismiss()
                        }
                    }
                }
        } else {
            self
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Ocultar") {
                            NexoKeyboard.dismiss()
                        }
                    }
                }
        }
    }
}
