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
        HStack(alignment: .center, spacing: 12) {
            CustomerExecutiveIconBadge(
                systemImage: iconName,
                tint: customer.identificationType == .finalConsumer ? .orange : .accentColor,
                size: 40
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(customer.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(BusinessCustomerPresentation.subtitle(for: customer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if hasContactInfo {
                    HStack(spacing: 8) {
                        if let email = customer.email, !email.isEmpty {
                            Label(email, systemImage: "envelope")
                                .lineLimit(1)
                        }

                        if let phone = customer.phone, !phone.isEmpty {
                            Label(phone, systemImage: "phone")
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if showsAccessory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var iconName: String {
        customer.identificationType == .finalConsumer ? "person.crop.circle" : "person.text.rectangle"
    }

    private var hasContactInfo: Bool {
        (customer.email?.isEmpty == false) || (customer.phone?.isEmpty == false)
    }
}

struct CustomerExecutiveCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var isHero: Bool = false
    var usesGradient: Bool = false
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isHero: Bool = false,
        usesGradient: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isHero = isHero
        self.usesGradient = usesGradient
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isHero ? 16 : 14) {
            HStack(alignment: .top, spacing: 12) {
                CustomerExecutiveIconBadge(
                    systemImage: systemImage,
                    tint: .accentColor,
                    size: isHero ? 44 : 38
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(isHero ? .title3.weight(.bold) : .headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }

            content
        }
        .padding(isHero ? 18 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if usesGradient {
                RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.16),
                                Color(uiColor: .secondarySystemGroupedBackground)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: isHero ? 26 : 22, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(isHero ? 0.055 : 0.025), radius: isHero ? 12 : 7, x: 0, y: isHero ? 7 : 3)
    }
}

struct CustomerExecutiveIconBadge: View {
    let systemImage: String
    let tint: Color
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.34, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

struct CustomerExecutivePill: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.11), in: Capsule(style: .continuous))
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(tint.opacity(0.14), lineWidth: 1)
            }
    }
}

struct CustomerExecutiveInfoRow: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = .secondary
    var isProminent: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Text(value)
                .font(isProminent ? .body.weight(.bold) : .body.weight(.semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CustomerExecutiveMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct CustomerExecutiveNoticeCard: View {
    let title: String
    let message: String
    let systemImage: String
    var tint: Color = .secondary

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }
}

struct CustomerExecutiveActionRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var tint: Color = .accentColor
    var showsAccessory: Bool = true

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            CustomerExecutiveIconBadge(systemImage: systemImage, tint: tint, size: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if showsAccessory {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(tint.opacity(0.10), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
