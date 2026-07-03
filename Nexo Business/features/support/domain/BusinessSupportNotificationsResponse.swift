//
//  BusinessSupportNotificationsResponse.swift
//  Nexo Business
//
//  Created by José Ruiz on 2/7/26.
//

import Foundation

struct BusinessSupportNotificationsResponse: Decodable, Equatable, Sendable {
    let items: [BusinessSupportNotificationItem]
    let unreadCount: Int
    let limit: Int?
    let unreadOnly: Bool?

    init(
        items: [BusinessSupportNotificationItem],
        unreadCount: Int,
        limit: Int? = nil,
        unreadOnly: Bool? = nil
    ) {
        self.items = items
        self.unreadCount = max(0, unreadCount)
        self.limit = limit
        self.unreadOnly = unreadOnly
    }

    private enum CodingKeys: String, CodingKey {
        case items
        case unreadCount
        case limit
        case unreadOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([BusinessSupportNotificationItem].self, forKey: .items) ?? []
        unreadCount = max(0, try container.decodeIfPresent(Int.self, forKey: .unreadCount) ?? 0)
        limit = try container.decodeIfPresent(Int.self, forKey: .limit)
        unreadOnly = try container.decodeIfPresent(Bool.self, forKey: .unreadOnly)
    }
}

struct BusinessSupportNotificationItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let type: String?
    let title: String?
    let summary: String?
    let createdAt: String?
    let readAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case notificationId
        case type
        case eventType
        case title
        case summary
        case preview
        case message
        case createdAt
        case readAt
    }

    init(
        id: String,
        type: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        createdAt: String? = nil,
        readAt: String? = nil
    ) {
        self.id = id
        self.type = type
        self.title = BusinessSupportNotificationItem.sanitized(title)
        self.summary = BusinessSupportNotificationItem.sanitized(summary)
        self.createdAt = createdAt
        self.readAt = readAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .notificationId)
            ?? "support_notification_unknown"

        id = BusinessSupportNotificationItem.sanitized(decodedId) ?? "support_notification_unknown"
        type = try container.decodeIfPresent(String.self, forKey: .type)
            ?? container.decodeIfPresent(String.self, forKey: .eventType)
        title = BusinessSupportNotificationItem.sanitized(
            try container.decodeIfPresent(String.self, forKey: .title)
        )
        summary = BusinessSupportNotificationItem.sanitized(
            try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decodeIfPresent(String.self, forKey: .preview)
            ?? container.decodeIfPresent(String.self, forKey: .message)
        )
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        readAt = try container.decodeIfPresent(String.self, forKey: .readAt)
    }

    private static func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lowercased = trimmed.lowercased()
        let sensitiveMarkers = [
            "authorization",
            "bearer ",
            "token",
            "password",
            "session",
            "secret",
            "firma",
            ".p12",
            ".pfx"
        ]

        if sensitiveMarkers.contains(where: { lowercased.contains($0) }) {
            return "Contenido protegido."
        }

        return trimmed
    }
}

