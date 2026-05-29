//
//  SalesHistoryModels.swift
//  Nexo Business
//
//  Created by José Ruiz on 29/5/26.
//

import Foundation

public enum SalesHistoryStatusFilter: String, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case pending
    case confirmed
    case inProgress = "in_progress"
    case ready
    case delivered
    case closed
    case canceled

    public var id: String { rawValue }

    public var queryValue: String? {
        switch self {
        case .all:
            return nil
        default:
            return rawValue
        }
    }

    public var displayName: String {
        switch self {
        case .all:
            return "Todas"
        case .pending:
            return "Pendientes"
        case .confirmed:
            return "Confirmadas"
        case .inProgress:
            return "En proceso"
        case .ready:
            return "Listas"
        case .delivered:
            return "Entregadas"
        case .closed:
            return "Cerradas"
        case .canceled:
            return "Canceladas"
        }
    }
}

public struct SalesHistorySearchRequest: Equatable, Sendable {
    public let branchId: String
    public let query: String?
    public let status: SalesHistoryStatusFilter
    public let date: Date?
    public let limit: Int

    public init(
        branchId: String,
        query: String? = nil,
        status: SalesHistoryStatusFilter = .all,
        date: Date? = nil,
        limit: Int = 50
    ) {
        self.branchId = branchId
        self.query = query
        self.status = status
        self.date = date
        self.limit = limit
    }
}

public struct BusinessSalesHistoryResponse: Decodable, Equatable, Sendable {
    public let sales: [BusinessSale]
    public let total: Int?
    public let hasMore: Bool?

    public init(
        sales: [BusinessSale],
        total: Int? = nil,
        hasMore: Bool? = nil
    ) {
        self.sales = sales
        self.total = total
        self.hasMore = hasMore
    }

    private enum CodingKeys: String, CodingKey {
        case sales
        case items
        case results
        case data
        case total
        case hasMore
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sales = try container.decodeIfPresent([BusinessSale].self, forKey: .sales)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .items)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .results)
            ?? container.decodeIfPresent([BusinessSale].self, forKey: .data)
            ?? []
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}
