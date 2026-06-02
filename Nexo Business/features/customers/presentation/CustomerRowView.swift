//
//  CustomerRowView.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import SwiftUI

struct CustomerRowView: View {
    private let customer: BusinessCustomer
    private let showsAccessory: Bool

    init(
        customer: BusinessCustomer,
        showsAccessory: Bool = false
    ) {
        self.customer = customer
        self.showsAccessory = showsAccessory
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: customer.identificationType == .finalConsumer ? "person.crop.circle" : "person.text.rectangle")
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(customer.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(BusinessCustomerPresentation.subtitle(for: customer))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let email = customer.email, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let phone = customer.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if showsAccessory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 5)
            }
        }
        .padding(.vertical, 4)
    }
}
